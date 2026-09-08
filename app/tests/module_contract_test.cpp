// Does this module actually work inside Logos Basecamp?
//
// It once did not, while looking as though it did. Basecamp loads a `ui_qml` module's QML in its
// *main* process and the module's C++ in a `ui-host` child, so the context property the plugin set
// on its own engine was invisible to the QML that was really on screen: every binding raised
// "backend is not defined", the window rendered in full, and no button did anything. Nothing in the
// build caught it, because everything built and the standalone preview app worked.
//
// This is the check that would have caught it. It asserts the two halves of Basecamp's contract:
//
//   1. The plugin object itself carries the API. Basecamp publishes the plugin over
//      QtRemoteObjects, which replicates properties, signals and *public slots* — so a method the
//      QML calls has to be a slot on this class, not only on some inner object.
//   2. Main.qml resolves its backend the way Basecamp's own modules do — `logos.module(name)` —
//      and not through a context property that exists in only one of the two hosts.
//
// The second is checked by loading the real Main.qml into an engine that has `logos` and no
// `ctxBackend`, exactly as the main Basecamp process does, and failing on any QML warning.
//
// With PMSIG_CONTRACT_LIVE=1 it goes further and fetches a real account through the plugin's slots,
// which is the whole path a press of ↻ takes.

#include <QCoreApplication>
#include <QDebug>
#include <QElapsedTimer>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QMetaMethod>
#include <QMetaObject>
#include <QMetaProperty>
#include <QPluginLoader>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QStringList>
#include <QUrl>
#include <QVariantMap>

namespace {

QStringList g_qmlProblems;

void messageHandler(QtMsgType type, const QMessageLogContext&, const QString& msg) {
    // A missing binding target is a warning, not an error: QML keeps rendering. That is exactly how
    // the original bug hid, so warnings are failures here.
    if (type == QtWarningMsg || type == QtCriticalMsg || type == QtFatalMsg) {
        if (msg.contains("is not defined") || msg.contains("no signal of the target matches")
            || msg.contains("Cannot read property") || msg.contains("Unable to assign")
            || msg.contains("Cannot assign")) {
            g_qmlProblems << msg;
        }
    }
    fprintf(stderr, "%s\n", qPrintable(msg));
}

int g_failures = 0;

void check(bool ok, const QString& what) {
    if (ok) {
        qInfo().noquote() << "  ok    " << what;
    } else {
        qInfo().noquote() << "  FAIL  " << what;
        ++g_failures;
    }
}

bool hasProperty(const QMetaObject* mo, const char* name) {
    const int i = mo->indexOfProperty(name);
    if (i < 0) return false;
    // Without a NOTIFY signal a replica never learns the value changed, so the panel would fill in
    // once and then go stale — the same class of silent failure.
    return mo->property(i).hasNotifySignal();
}

bool hasSlot(const QMetaObject* mo, const char* signature) {
    const int i = mo->indexOfMethod(QMetaObject::normalizedSignature(signature).constData());
    if (i < 0) return false;
    return mo->method(i).methodType() == QMetaMethod::Slot;
}

// A stand-in for Basecamp's `logos` registry: the one member the module's QML uses.
class LogosStub : public QObject {
    Q_OBJECT
public:
    explicit LogosStub(QObject* module, QObject* parent = nullptr)
        : QObject(parent), m_module(module) {
        // Basecamp keeps owning the module object; without this the engine would take it, delete it
        // at teardown, and every binding would report reading a property "of null" — which looks
        // exactly like the bug this test exists to catch.
        QQmlEngine::setObjectOwnership(m_module, QQmlEngine::CppOwnership);
    }
    Q_INVOKABLE QObject* module(const QString& name) {
        m_asked << name;
        QObject* out = name == QLatin1String("private_multisig") ? m_module : nullptr;
        return out;
    }
    QStringList asked() const { return m_asked; }

private:
    QObject*    m_module;
    QStringList m_asked;
};

} // namespace

int main(int argc, char** argv) {
    if (argc < 3) {
        qCritical("usage: module_contract_test <plugin.dylib> <Main.qml>");
        return 2;
    }
    QGuiApplication app(argc, argv);
    qInstallMessageHandler(messageHandler);

    // ── 1. The plugin loads and exposes the API Basecamp will publish ───────────────────────────
    QPluginLoader loader(QString::fromLocal8Bit(argv[1]));
    QObject*      plugin = loader.instance();
    if (!plugin) {
        qCritical().noquote() << "the plugin did not load:" << loader.errorString();
        return 1;
    }
    // initLogos is deliberately not called: it takes a LogosAPI* this test has no way to build,
    // and the plugin creates its backend on first use anyway. The backend never uses the host API —
    // it talks to the chain over the FFI — so nothing below depends on it.

    const QMetaObject* mo = plugin->metaObject();
    qInfo().noquote() << "plugin class:" << mo->className();

    for (const char* p : {"config", "proposal", "fetchErrors", "busy", "lastError", "lastTxHash", "lastResult",
                          "walletPath", "sequencerUrl", "programIdHex", "walletCliDir", "connectionStatus",
                          "walletAccounts", "walletAccountInfo", "walletDecodedAccount"}) {
        check(hasProperty(mo, p), QStringLiteral("property %1 is published and notifies").arg(p));
    }

    for (const char* s : {"fetchConfig(QString)", "fetchProposal(QString)",
                          "createMultisig(QString,QString,QString,quint32,quint32,QString,QVariantList)",
                          "createProposal(QString,QString,QString,QString,QString,QString)",
                          "approve(QString,QString,QString,QString,QVariantList)",
                          "execute(QString,QString)", "checkConnection()", "listAccounts()",
                          "createAccount(QString)", "inspectAccount(QString)",
                          "decodeAccount(QString)", "saveHistory(QString,QString)",
                          "setWalletPath(QString)", "setSequencerUrl(QString)",
                          "setProgramIdHex(QString)", "setWalletCliDir(QString)"}) {
        check(hasSlot(mo, s), QStringLiteral("%1 is a public slot").arg(QString::fromLatin1(s)));
    }

    check(mo->indexOfSignal("operationSuccess(QString,QString)") >= 0,
          QStringLiteral("operationSuccess is a signal"));
    check(mo->indexOfSignal("operationError(QString,QString)") >= 0,
          QStringLiteral("operationError is a signal"));

    // ── 2. The QML resolves that object the way Basecamp offers it ──────────────────────────────
    //
    // No ctxBackend here: this engine is the main Basecamp process, which never sets one.
    // The stub outlives the engine: destroyed first, the `logos` context property would dangle and
    // every binding would re-evaluate to null on the way out — noise that reads like a failure.
    LogosStub  logos(plugin);
    QQmlEngine engine;
    engine.rootContext()->setContextProperty("logos", &logos);

    QQmlComponent component(&engine, QUrl::fromLocalFile(QString::fromLocal8Bit(argv[2])));
    QObject*      rootObj = component.create();
    if (!rootObj) {
        qCritical().noquote() << "Main.qml did not load:" << component.errorString();
        return 1;
    }
    check(logos.asked().contains("private_multisig"),
          QStringLiteral("Main.qml asked logos for the module"));
    check(rootObj->property("backendReady").toBool(),
          QStringLiteral("Main.qml resolved a backend from logos.module()"));
    check(g_qmlProblems.isEmpty(),
          QStringLiteral("Main.qml raised no unresolved-binding warnings (%1 seen)")
              .arg(g_qmlProblems.size()));
    for (const QString& p : g_qmlProblems) qInfo().noquote() << "        " << p;

    // ── 3. Optionally, the whole path a press of the fetch button takes ─────────────────────────
    if (qEnvironmentVariableIsSet("PMSIG_CONTRACT_LIVE")) {
        const QString hash = qEnvironmentVariable("PMSIG_CONFIG_HASH");
        QMetaObject::invokeMethod(plugin, "setSequencerUrl",
                                  Q_ARG(QString, qEnvironmentVariable("PMSIG_SEQUENCER_URL")));
        QMetaObject::invokeMethod(plugin, "setProgramIdHex",
                                  Q_ARG(QString, qEnvironmentVariable("PMSIG_PROGRAM_ID")));
        QMetaObject::invokeMethod(plugin, "setWalletPath",
                                  Q_ARG(QString, qEnvironmentVariable("PMSIG_WALLET_PATH")));
        QMetaObject::invokeMethod(plugin, "setWalletCliDir",
                                  Q_ARG(QString, qEnvironmentVariable("PMSIG_WALLET_CLI_DIR")));
        QMetaObject::invokeMethod(plugin, "fetchConfig", Q_ARG(QString, hash));

        QElapsedTimer clock;
        clock.start();
        QVariantMap config;
        while (clock.elapsed() < 120000) {
            QCoreApplication::processEvents(QEventLoop::AllEvents, 100);
            config = plugin->property("config").toMap();
            if (!config.isEmpty()) break;
        }
        check(!config.isEmpty(), QStringLiteral("fetchConfig filled the config property"));
        if (!config.isEmpty()) {
            qInfo().noquote() << "        decoded:"
                              << QString::fromUtf8(QJsonDocument::fromVariant(config).toJson(
                                     QJsonDocument::Compact));
            check(config.value("m").toInt() == 2 && config.value("n").toInt() == 3,
                  QStringLiteral("the fetched multisig is the deployed 2-of-3"));
        } else {
            qInfo().noquote() << "        lastError:" << plugin->property("lastError").toString();
        }

        // A fetch that finds nothing must say why. This is the case that used to report success and
        // leave the "No data" placeholder up, which reads as an empty account rather than a
        // misconfigured one.
        QMetaObject::invokeMethod(plugin, "fetchConfig",
                                  Q_ARG(QString, QString(64, QLatin1Char('0'))));
        clock.restart();
        QString absent;
        while (clock.elapsed() < 60000) {
            QCoreApplication::processEvents(QEventLoop::AllEvents, 100);
            absent = plugin->property("fetchErrors").toMap().value("config").toString();
            if (!absent.isEmpty()) break;
        }
        check(absent.contains(qEnvironmentVariable("PMSIG_SEQUENCER_URL"))
                  && absent.contains(qEnvironmentVariable("PMSIG_PROGRAM_ID")),
              QStringLiteral("a fetch that finds nothing names the sequencer and program id it used"));
        if (!absent.isEmpty()) qInfo().noquote() << "        " << absent;

        // The wallet pages do not talk to the chain over the FFI's client — they run LEZ's `wallet`
        // binary, which is resolved through PATH and so is the one part of the module that a host
        // with a different environment breaks silently.
        QMetaObject::invokeMethod(plugin, "listAccounts");
        clock.restart();
        QVariantList accounts;
        while (clock.elapsed() < 60000) {
            QCoreApplication::processEvents(QEventLoop::AllEvents, 100);
            accounts = plugin->property("walletAccounts").toList();
            if (!accounts.isEmpty()) break;
        }
        check(!accounts.isEmpty(),
              QStringLiteral("listAccounts read the wallet through the configured CLI directory"));
        if (accounts.isEmpty())
            qInfo().noquote() << "        lastError:" << plugin->property("lastError").toString();
        else
            qInfo().noquote() << "        accounts:" << accounts.size();
    }

    // Tear the tree down while its context is still alive, so the run ends quietly.
    delete rootObj;

    // ── 4. The write paths are connected too ────────────────────────────────────────────────────
    //
    // The read panels prove the plugin reaches the chain. The instruction panels take a different
    // route — dispatchFfi, a worker thread, then operationSuccess or operationError — and a slot
    // that quietly did nothing would look identical to one still working. Called with an argument
    // the FFI must reject, a connected path answers; a disconnected one stays silent.
    {
        // "not-hex" cannot be a 32-byte seed, so this fails inside the FFI and never reaches a
        // sequencer — nothing is submitted and no funds move.
        QMetaObject::invokeMethod(plugin, "execute", Q_ARG(QString, QStringLiteral("not-hex")),
                                  Q_ARG(QString, QStringLiteral("not-hex")));
        QElapsedTimer clock;
        clock.start();
        QString err;
        while (clock.elapsed() < 30000) {
            QCoreApplication::processEvents(QEventLoop::AllEvents, 100);
            err = plugin->property("lastError").toString();
            if (!err.isEmpty()) break;
        }
        check(!err.isEmpty(),
              QStringLiteral("an instruction slot reports failure rather than silently doing nothing"));
        if (!err.isEmpty()) qInfo().noquote() << "        " << err.left(120);
    }

    qInfo().noquote() << (g_failures == 0 ? "contract holds" : "CONTRACT BROKEN");
    return g_failures == 0 ? 0 : 1;
}

#include "module_contract_test.moc"
