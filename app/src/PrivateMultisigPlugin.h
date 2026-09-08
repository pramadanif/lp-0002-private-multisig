// Started from spel-client-gen --target logos-module, then maintained by hand: the generated
// scaffold assumed the host renders the widget the plugin builds, and Logos Basecamp 0.2.3 does not.
// `scripts/build-basecamp.sh --regen` overwrites this file; re-apply the hardening if you run it.
//
// ── Why the plugin carries the whole API ────────────────────────────────────────────────────────
//
// A `ui_qml` module is loaded twice over. The dylib is loaded into a `ui-host` child process, which
// calls initLogos and then publishes this object over QtRemoteObjects under the module's name. The
// QML named by the manifest's `view` is loaded by the *main* Basecamp process, in an engine this
// plugin never touches — so the context property the scaffold set in createWidget was invisible to
// it, and every binding in Main.qml raised "backend is not defined" while the window still rendered.
// The panels looked finished and did nothing.
//
// Basecamp's own package_manager_ui shows the contract: its QML reaches C++ as
// `logos.module("package_manager_ui")`, and the properties and slots it reads live on the *plugin*
// class, not on an inner object. So this class mirrors PrivateMultisigBackend's surface and
// forwards to it. The methods are public slots rather than Q_INVOKABLE because QtRemoteObjects
// replicates properties, signals and public slots.
#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QWidget>
#include <QtPlugin>

class LogosAPI;
class PrivateMultisigBackend;

class IComponent {
public:
	virtual ~IComponent() = default;
	virtual QWidget* createWidget(LogosAPI* api = nullptr) = 0;
	virtual void     destroyWidget(QWidget* widget) = 0;
};
#define IComponent_iid "com.logos.component.IComponent"
Q_DECLARE_INTERFACE(IComponent, IComponent_iid)

class PrivateMultisigPlugin : public QObject, public IComponent {
	Q_OBJECT
	Q_PLUGIN_METADATA(IID IComponent_iid FILE "../manifest.json")
	Q_INTERFACES(IComponent)

	// ── Fetched state ─────────────────────────────────────────────────────
	Q_PROPERTY(QVariantMap config READ config NOTIFY configChanged)
	Q_PROPERTY(QVariantMap proposal READ proposal NOTIFY proposalChanged)

	// ── Async status ──────────────────────────────────────────────────────
	Q_PROPERTY(bool        busy       READ busy       NOTIFY busyChanged)
	Q_PROPERTY(QString     lastError  READ lastError  NOTIFY lastErrorChanged)
	Q_PROPERTY(QString     lastTxHash READ lastTxHash NOTIFY lastTxHashChanged)
	Q_PROPERTY(QVariantMap lastResult READ lastResult NOTIFY lastResultChanged)

	// ── Configuration ────────────────────────────────────────────────────
	Q_PROPERTY(QString walletPath   READ walletPath   WRITE setWalletPath   NOTIFY walletPathChanged)
	Q_PROPERTY(QString sequencerUrl READ sequencerUrl WRITE setSequencerUrl NOTIFY sequencerUrlChanged)
	Q_PROPERTY(QString programIdHex READ programIdHex WRITE setProgramIdHex NOTIFY programIdHexChanged)

	// ── Wallet state ─────────────────────────────────────────────────────
	Q_PROPERTY(QString      connectionStatus     READ connectionStatus     NOTIFY connectionStatusChanged)
	Q_PROPERTY(QVariantList walletAccounts       READ walletAccounts       NOTIFY walletAccountsChanged)
	Q_PROPERTY(QVariantMap  walletAccountInfo    READ walletAccountInfo    NOTIFY walletAccountInfoChanged)
	Q_PROPERTY(QVariantMap  walletDecodedAccount READ walletDecodedAccount NOTIFY walletDecodedAccountChanged)

public:
	explicit PrivateMultisigPlugin(QObject* parent = nullptr);
	~PrivateMultisigPlugin() override;

	Q_INVOKABLE void initLogos(LogosAPI* api);

	QWidget* createWidget(LogosAPI* api = nullptr) override;
	void     destroyWidget(QWidget* widget) override;

	QVariantMap  config() const;
	QVariantMap  proposal() const;
	bool         busy() const;
	QString      lastError() const;
	QString      lastTxHash() const;
	QVariantMap  lastResult() const;
	QString      walletPath() const;
	QString      sequencerUrl() const;
	QString      programIdHex() const;
	QString      connectionStatus() const;
	QVariantList walletAccounts() const;
	QVariantMap  walletAccountInfo() const;
	QVariantMap  walletDecodedAccount() const;

public slots:
	void setWalletPath(const QString& v);
	void setSequencerUrl(const QString& v);
	void setProgramIdHex(const QString& v);

	void createMultisig(const QString& creatorId, const QString& configHash, const QString& memberRoot, quint32 m, quint32 n, const QString& multisigId, const QVariantList& membershipProgramId);
	void createProposal(const QString& proposerId, const QString& configHash, const QString& proposalSeed, const QString& proposalId, const QString& recipient, const QString& amount);
	void approve(const QString& configHash, const QString& proposalSeed, const QString& memberRoot, const QString& claimedNullifier, const QVariantList& witness);
	void execute(const QString& configHash, const QString& proposalSeed);

	void fetchConfig(const QString& configHash);
	void fetchProposal(const QString& proposalSeed);

	void        checkConnection();
	void        listAccounts();
	void        createAccount(const QString& label);
	void        inspectAccount(const QString& accountId);
	void        decodeAccount(const QString& accountId);
	QStringList fieldHistory(const QString& key) const;
	void        saveHistory(const QString& key, const QString& value);

signals:
	void configChanged();
	void proposalChanged();
	void busyChanged();
	void lastErrorChanged();
	void lastTxHashChanged();
	void lastResultChanged();
	void operationSuccess(const QString& operation, const QString& txHash);
	void operationError(const QString& operation, const QString& error);
	void walletPathChanged();
	void sequencerUrlChanged();
	void programIdHexChanged();
	void connectionStatusChanged();
	void walletAccountsChanged();
	void walletAccountInfoChanged();
	void walletDecodedAccountChanged();

private:
	// Creates the backend on first use and connects every one of its signals to this object's
	// matching signal, so a replica in the main process sees the same changes the widget would.
	PrivateMultisigBackend* backend() const;

	LogosAPI*                       m_api     = nullptr;
	mutable PrivateMultisigBackend* m_backend = nullptr;
};
