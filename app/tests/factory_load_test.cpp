// Does the replica factory load into a process that already has Qt, without dragging a second copy
// of it in?
//
// The first version of this plugin crashed Logos Basecamp on open. Not in our code: the backtrace
// ended in PCRE2's JIT, under Basecamp's own QML url interceptor. The cause was an `LC_RPATH`
// pointing at the Qt this machine builds against. Basecamp's main process already has Qt loaded
// from its bundle, so that rpath resolved `@rpath/QtCore.framework/...` to a *second* copy on disk,
// and two QtCore images in one process corrupt each other in places that name neither of them.
//
// Basecamp's own factory carries `@loader_path` rpaths and nothing absolute. Ours now carries none
// at all, which is stricter: with no rpath of its own, dyld can only satisfy those dependencies with
// images the host has already loaded.
//
// This test is what should have run before that dylib was ever put in front of a person.
#include <QCoreApplication>
#include <QDebug>
#include <QObject>
#include <QPluginLoader>
#include <QRegularExpression>
#include <QRemoteObjectNode>
#include <mach-o/dyld.h>
#include <cstring>

class LogosViewReplicaFactory {
public:
    virtual QObject*           acquire(QRemoteObjectNode* node) = 0;
    virtual const QMetaObject* replicaMetaObject() const        = 0;
};
#define LogosViewReplicaFactory_iid "logos.view.replica_factory/1.0"
Q_DECLARE_INTERFACE(LogosViewReplicaFactory, LogosViewReplicaFactory_iid)

static int failures = 0;
static void check(bool ok, const QString& what) {
    qInfo().noquote() << (ok ? "  ok    " : "  FAIL  ") << what;
    if (!ok) ++failures;
}

// One QtCore in the process, or the plugin brought its own.
static int countLoaded(const char* needle) {
    int n = 0;
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const char* name = _dyld_get_image_name(i);
        if (name && std::strstr(name, needle)) ++n;
    }
    return n;
}

int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);
    if (argc < 2) {
        qCritical("usage: factory_load_test <private_multisig_replica_factory.dylib>");
        return 2;
    }

    const int qtCoreBefore = countLoaded("QtCore.framework");

    QPluginLoader loader(QString::fromLocal8Bit(argv[1]));
    QObject* instance = loader.instance();
    check(instance != nullptr,
          QStringLiteral("the factory loads (%1)").arg(loader.errorString()));
    if (!instance) return 1;

    check(loader.metaData().value("IID").toString() == QLatin1String(LogosViewReplicaFactory_iid),
          QStringLiteral("it declares the IID Basecamp looks for"));

    auto* factory = qobject_cast<LogosViewReplicaFactory*>(instance);
    check(factory != nullptr, QStringLiteral("it casts to LogosViewReplicaFactory"));
    if (!factory) return 1;

    const int qtCoreAfter = countLoaded("QtCore.framework");
    check(qtCoreAfter == qtCoreBefore,
          QStringLiteral("loading it added no second copy of QtCore (%1 before, %2 after)")
              .arg(qtCoreBefore).arg(qtCoreAfter));

    // No source is running here, so the replica will never initialise — but acquiring one is what
    // Basecamp does the moment the module is opened, and it must return an object rather than null
    // or a crash. `LogosQmlBridge::module: factory->acquire() returned null` is the host's own
    // message for the failure this catches.
    QRemoteObjectNode node;
    node.setRegistryUrl(QUrl(QStringLiteral("local:pmsig_factory_test_registry")));
    QObject* replica = factory->acquire(&node);
    check(replica != nullptr, QStringLiteral("acquire() returns a replica object"));

    check(factory->replicaMetaObject() != nullptr,
          QStringLiteral("replicaMetaObject() answers without crashing"));

    // The crash Basecamp took was not in any of the above: it was PCRE2 compiling a regex on the
    // QML thread, trapping inside pthread_jit_write_protect_np. That happens when the process has
    // lost the JIT privilege its hardened runtime grants — which loading a badly signed library can
    // do. So force the same JIT path here, after the plugin is in, under a binary signed the same
    // way Basecamp is.
    QRegularExpression re(QStringLiteral("^\\s*plugin\\s+(\\S+)"),
                          QRegularExpression::MultilineOption);
    re.optimize();
    const bool matched = re.match(QStringLiteral("  plugin private_multisig")).hasMatch();
    check(matched, QStringLiteral("a JIT-compiled regex still runs with the plugin loaded"));

    delete replica;
    qInfo().noquote() << (failures == 0 ? "factory is loadable" : "FACTORY BROKEN");
    return failures == 0 ? 0 : 1;
}
