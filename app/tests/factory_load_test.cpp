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
#include <QElapsedTimer>
#include <QRegularExpression>
#include <QRemoteObjectHost>

#include "../src/LogosViewReplicaFactory.h"
#include <QRemoteObjectNode>
#include <mach-o/dyld.h>
#include <cstring>

// One declaration, shared with the factory: this file had its own copy, and when the factory
// gained the virtual destructor this one did not, so the test crashed exactly the way Basecamp had.

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
    // The round-trip below calls setSequencerUrl, which the backend *persists*. Without this the
    // test would overwrite the operator's real setting with its own probe value — it did once.
    qputenv("PMSIG_SETTINGS_APP", QByteArrayLiteral("private_multisig_factory_test"));
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

    // ── The pairing itself ──────────────────────────────────────────────────────────────────────
    //
    // Everything above proves the plugin loads. This proves the half that actually fails silently:
    // QtRemoteObjects pairs a source and a replica by a signature computed over the .rep, and a
    // mismatch does not error at build time — the replica simply never initialises, and in Basecamp
    // that looks exactly like a module whose panels do nothing. Publishing the real plugin here and
    // acquiring through the real factory is the only way to see it.
    if (argc >= 3) {
        QPluginLoader pluginLoader(QString::fromLocal8Bit(argv[2]));
        QObject* source = pluginLoader.instance();
        check(source != nullptr,
              QStringLiteral("the module plugin loads (%1)").arg(pluginLoader.errorString()));
        if (source) {
            // `ui-host` publishes it under the module's name, not the class's.
            QRemoteObjectHost host(QUrl(QStringLiteral("local:pmsig_pair_test")));
            check(host.enableRemoting(source, QStringLiteral("private_multisig")),
                  QStringLiteral("the plugin can be published as \"private_multisig\""));

            QRemoteObjectNode client;
            client.connectToNode(QUrl(QStringLiteral("local:pmsig_pair_test")));
            QObject* paired = factory->acquire(&client);
            check(paired != nullptr, QStringLiteral("the factory acquires a replica of it"));

            auto* rep = qobject_cast<QRemoteObjectReplica*>(paired);
            check(rep != nullptr, QStringLiteral("what it returns is a QtRemoteObjects replica"));
            if (rep) {
                QElapsedTimer clock;
                clock.start();
                while (!rep->isInitialized() && clock.elapsed() < 10000)
                    QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
                check(rep->isInitialized(),
                      QStringLiteral("source and replica pair (signatures match)"));
            }
            if (paired && paired->metaObject()->indexOfProperty("sequencerUrl") >= 0) {
                check(true, QStringLiteral("the replica exposes the module's properties"));
                // A slot call has to travel to the source and the new value come back, which is the
                // whole round trip a button press makes.
                QMetaObject::invokeMethod(paired, "setSequencerUrl",
                                          Q_ARG(QString, QStringLiteral("https://pair.test")));
                QElapsedTimer clock;
                clock.start();
                QString seen;
                while (clock.elapsed() < 10000) {
                    QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
                    seen = paired->property("sequencerUrl").toString();
                    if (seen == QLatin1String("https://pair.test")) break;
                }
                check(seen == QLatin1String("https://pair.test"),
                      QStringLiteral("a slot called on the replica reaches the plugin and the new "
                                     "value comes back (saw \"%1\")").arg(seen));
            } else {
                check(false, QStringLiteral("the replica exposes the module's properties"));
            }
            delete paired;
        }
    }

    qInfo().noquote() << (failures == 0 ? "factory is loadable" : "FACTORY BROKEN");
    return failures == 0 ? 0 : 1;
}
