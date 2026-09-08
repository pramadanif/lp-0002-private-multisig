// See PrivateMultisigPlugin.h for why this class mirrors the backend's API.
#include "PrivateMultisigPlugin.h"
#include "PrivateMultisigBackend.h"

#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickWidget>
#include <QUrl>
#include <cstdlib>

PrivateMultisigPlugin::PrivateMultisigPlugin(QObject* parent) : QObject(parent) {}
PrivateMultisigPlugin::~PrivateMultisigPlugin() = default;

void PrivateMultisigPlugin::initLogos(LogosAPI* api) {
	m_api = api;
	// Build the backend now rather than on first use: the host publishes this object for remoting
	// immediately after this call, and a replica that connects before the backend exists would read
	// defaults for every property and never be told they changed.
	(void)backend();
}

PrivateMultisigBackend* PrivateMultisigPlugin::backend() const {
	if (m_backend)
		return m_backend;
	auto* self = const_cast<PrivateMultisigPlugin*>(this);
	m_backend  = new PrivateMultisigBackend(m_api, self);

	using B = PrivateMultisigBackend;
	using P = PrivateMultisigPlugin;
	connect(m_backend, &B::configChanged,               self, &P::configChanged);
	connect(m_backend, &B::proposalChanged,             self, &P::proposalChanged);
	connect(m_backend, &B::fetchErrorsChanged,          self, &P::fetchErrorsChanged);
	connect(m_backend, &B::busyChanged,                 self, &P::busyChanged);
	connect(m_backend, &B::lastErrorChanged,            self, &P::lastErrorChanged);
	connect(m_backend, &B::lastTxHashChanged,           self, &P::lastTxHashChanged);
	connect(m_backend, &B::lastResultChanged,           self, &P::lastResultChanged);
	connect(m_backend, &B::walletPathChanged,           self, &P::walletPathChanged);
	connect(m_backend, &B::sequencerUrlChanged,         self, &P::sequencerUrlChanged);
	connect(m_backend, &B::programIdHexChanged,         self, &P::programIdHexChanged);
	connect(m_backend, &B::walletCliDirChanged,         self, &P::walletCliDirChanged);
	connect(m_backend, &B::connectionStatusChanged,     self, &P::connectionStatusChanged);
	connect(m_backend, &B::walletAccountsChanged,       self, &P::walletAccountsChanged);
	connect(m_backend, &B::walletAccountInfoChanged,    self, &P::walletAccountInfoChanged);
	connect(m_backend, &B::walletDecodedAccountChanged, self, &P::walletDecodedAccountChanged);
	connect(m_backend, &B::operationSuccess,            self, &P::operationSuccess);
	connect(m_backend, &B::operationError,              self, &P::operationError);
	return m_backend;
}

QWidget* PrivateMultisigPlugin::createWidget(LogosAPI* api) {
	if (api) m_api = api;
	auto* view = new QQuickWidget();
	// Only the in-process path reaches this. `ctxBackend`, not `backend`: Main.qml declares its own
	// `backend` property that prefers this and falls back to logos.module(), and a context property
	// of the same name would be shadowed by it.
	view->engine()->rootContext()->setContextProperty("ctxBackend", backend());
	view->setResizeMode(QQuickWidget::SizeRootObjectToView);
	const char* qmlPath = std::getenv("QML_PATH");
	if (qmlPath) {
		view->setSource(QUrl::fromLocalFile(QString::fromUtf8(qmlPath) + "/Main.qml"));
	} else {
		// Qt does not auto-register embedded resources in dynamically loaded plugins.
		Q_INIT_RESOURCE(private_multisig_qml); // name must match qt_add_resources() in CMakeLists.txt
		view->setSource(QUrl("qrc:/qml/Main.qml"));
	}
	return view;
}

void PrivateMultisigPlugin::destroyWidget(QWidget* widget) {
	// The backend outlives the widget: under remoting there is no widget at all, and a replica in
	// the main process keeps reading these properties after any widget is gone.
	delete widget;
}

// ── Property reads ──────────────────────────────────────────────────────────────────────────────

QVariantMap  PrivateMultisigPlugin::config() const { return backend()->config(); }
QVariantMap  PrivateMultisigPlugin::proposal() const { return backend()->proposal(); }
QVariantMap  PrivateMultisigPlugin::fetchErrors() const { return backend()->fetchErrors(); }
bool         PrivateMultisigPlugin::busy() const { return backend()->busy(); }
QString      PrivateMultisigPlugin::lastError() const { return backend()->lastError(); }
QString      PrivateMultisigPlugin::lastTxHash() const { return backend()->lastTxHash(); }
QVariantMap  PrivateMultisigPlugin::lastResult() const { return backend()->lastResult(); }
QString      PrivateMultisigPlugin::walletPath() const { return backend()->walletPath(); }
QString      PrivateMultisigPlugin::sequencerUrl() const { return backend()->sequencerUrl(); }
QString      PrivateMultisigPlugin::programIdHex() const { return backend()->programIdHex(); }
QString      PrivateMultisigPlugin::walletCliDir() const { return backend()->walletCliDir(); }
QString      PrivateMultisigPlugin::connectionStatus() const { return backend()->connectionStatus(); }
QVariantList PrivateMultisigPlugin::walletAccounts() const { return backend()->walletAccounts(); }
QVariantMap  PrivateMultisigPlugin::walletAccountInfo() const { return backend()->walletAccountInfo(); }
QVariantMap  PrivateMultisigPlugin::walletDecodedAccount() const { return backend()->walletDecodedAccount(); }

// ── Slots ───────────────────────────────────────────────────────────────────────────────────────

void PrivateMultisigPlugin::setWalletPath(const QString& v) { backend()->setWalletPath(v); }
void PrivateMultisigPlugin::setSequencerUrl(const QString& v) { backend()->setSequencerUrl(v); }
void PrivateMultisigPlugin::setProgramIdHex(const QString& v) { backend()->setProgramIdHex(v); }
void PrivateMultisigPlugin::setWalletCliDir(const QString& v) { backend()->setWalletCliDir(v); }

void PrivateMultisigPlugin::createMultisig(const QString& creatorId, const QString& configHash, const QString& memberRoot, quint32 m, quint32 n, const QString& multisigId, const QVariantList& membershipProgramId) {
	backend()->createMultisig(creatorId, configHash, memberRoot, m, n, multisigId, membershipProgramId);
}
void PrivateMultisigPlugin::createProposal(const QString& proposerId, const QString& configHash, const QString& proposalSeed, const QString& proposalId, const QString& recipient, const QString& amount) {
	backend()->createProposal(proposerId, configHash, proposalSeed, proposalId, recipient, amount);
}
void PrivateMultisigPlugin::approve(const QString& configHash, const QString& proposalSeed, const QString& memberRoot, const QString& claimedNullifier, const QVariantList& witness) {
	backend()->approve(configHash, proposalSeed, memberRoot, claimedNullifier, witness);
}
void PrivateMultisigPlugin::execute(const QString& configHash, const QString& proposalSeed) {
	backend()->execute(configHash, proposalSeed);
}

void PrivateMultisigPlugin::fetchConfig(const QString& configHash) { backend()->fetchConfig(configHash); }
void PrivateMultisigPlugin::fetchProposal(const QString& proposalSeed) { backend()->fetchProposal(proposalSeed); }

void        PrivateMultisigPlugin::checkConnection() { backend()->checkConnection(); }
void        PrivateMultisigPlugin::listAccounts() { backend()->listAccounts(); }
void        PrivateMultisigPlugin::createAccount(const QString& label) { backend()->createAccount(label); }
void        PrivateMultisigPlugin::inspectAccount(const QString& accountId) { backend()->inspectAccount(accountId); }
void        PrivateMultisigPlugin::decodeAccount(const QString& accountId) { backend()->decodeAccount(accountId); }
QStringList PrivateMultisigPlugin::fieldHistory(const QString& key) const { return backend()->fieldHistory(key); }
void        PrivateMultisigPlugin::saveHistory(const QString& key, const QString& value) { backend()->saveHistory(key, value); }
