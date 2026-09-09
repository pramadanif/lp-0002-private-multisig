// See PrivateMultisigPlugin.h for why this class inherits a repc-generated source.
#include "PrivateMultisigPlugin.h"
#include "PrivateMultisigBackend.h"

#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickWidget>
#include <QUrl>
#include <cstdlib>

PrivateMultisigPlugin::PrivateMultisigPlugin(QObject* parent)
    : PrivateMultisigSimpleSource(parent) {}
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
	// Each of the backend's notifications pushes the new value into the generated source, which is
	// what emits the replicated `…Changed(value)` signal. The backend's own signals carry no
	// argument, so the value is read back here rather than forwarded.
	connect(m_backend, &B::configChanged,               self, [self] { self->PrivateMultisigSimpleSource::setConfig(self->m_backend->config()); });
	connect(m_backend, &B::proposalChanged,             self, [self] { self->PrivateMultisigSimpleSource::setProposal(self->m_backend->proposal()); });
	connect(m_backend, &B::fetchErrorsChanged,          self, [self] { self->PrivateMultisigSimpleSource::setFetchErrors(self->m_backend->fetchErrors()); });
	connect(m_backend, &B::busyChanged,                 self, [self] { self->PrivateMultisigSimpleSource::setBusy(self->m_backend->busy()); });
	connect(m_backend, &B::lastErrorChanged,            self, [self] { self->PrivateMultisigSimpleSource::setLastError(self->m_backend->lastError()); });
	connect(m_backend, &B::lastTxHashChanged,           self, [self] { self->PrivateMultisigSimpleSource::setLastTxHash(self->m_backend->lastTxHash()); });
	connect(m_backend, &B::lastResultChanged,           self, [self] { self->PrivateMultisigSimpleSource::setLastResult(self->m_backend->lastResult()); });
	connect(m_backend, &B::walletPathChanged,           self, [self] { self->PrivateMultisigSimpleSource::setWalletPath(self->m_backend->walletPath()); });
	connect(m_backend, &B::sequencerUrlChanged,         self, [self] { self->PrivateMultisigSimpleSource::setSequencerUrl(self->m_backend->sequencerUrl()); });
	connect(m_backend, &B::programIdHexChanged,         self, [self] { self->PrivateMultisigSimpleSource::setProgramIdHex(self->m_backend->programIdHex()); });
	connect(m_backend, &B::walletCliDirChanged,         self, [self] { self->PrivateMultisigSimpleSource::setWalletCliDir(self->m_backend->walletCliDir()); });
	connect(m_backend, &B::connectionStatusChanged,     self, [self] { self->PrivateMultisigSimpleSource::setConnectionStatus(self->m_backend->connectionStatus()); });
	connect(m_backend, &B::walletAccountsChanged,       self, [self] { self->PrivateMultisigSimpleSource::setWalletAccounts(self->m_backend->walletAccounts()); });
	connect(m_backend, &B::walletAccountInfoChanged,    self, [self] { self->PrivateMultisigSimpleSource::setWalletAccountInfo(self->m_backend->walletAccountInfo()); });
	connect(m_backend, &B::walletDecodedAccountChanged, self, [self] { self->PrivateMultisigSimpleSource::setWalletDecodedAccount(self->m_backend->walletDecodedAccount()); });
	connect(m_backend, &B::operationSuccess,            self, &PrivateMultisigPlugin::operationSuccess);
	connect(m_backend, &B::operationError,              self, &PrivateMultisigPlugin::operationError);

	// The settings the backend restored are already meaningful; publish them before anyone asks.
	// Through `self`, because this accessor is const and the generated setters are not.
	self->PrivateMultisigSimpleSource::setWalletPath(m_backend->walletPath());
	self->PrivateMultisigSimpleSource::setSequencerUrl(m_backend->sequencerUrl());
	self->PrivateMultisigSimpleSource::setProgramIdHex(m_backend->programIdHex());
	self->PrivateMultisigSimpleSource::setWalletCliDir(m_backend->walletCliDir());
	return m_backend;
}

QWidget* PrivateMultisigPlugin::createWidget(LogosAPI* api) {
	if (api) m_api = api;
	(void)backend();
	auto* view = new QQuickWidget();
	// Only the in-process path reaches this. `ctxBackend`, not `backend`: Main.qml declares its own
	// `backend` property that prefers this and falls back to logos.module(), and a context property
	// of the same name would be shadowed by it. The object is this plugin either way — in Basecamp
	// the QML sees a replica of it instead.
	view->engine()->rootContext()->setContextProperty("ctxBackend", this);
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

// ── Slots ───────────────────────────────────────────────────────────────────────────────────────
//
// These four are also the generated property setters. Routing them through the backend is what
// makes a write from the UI persist; the backend's change signal then publishes the new value.

void PrivateMultisigPlugin::setWalletPath(QString v) { backend()->setWalletPath(v); }
void PrivateMultisigPlugin::setSequencerUrl(QString v) { backend()->setSequencerUrl(v); }
void PrivateMultisigPlugin::setProgramIdHex(QString v) { backend()->setProgramIdHex(v); }
void PrivateMultisigPlugin::setWalletCliDir(QString v) { backend()->setWalletCliDir(v); }

void PrivateMultisigPlugin::createMultisig(QString creatorId, QString configHash, QString memberRoot, quint32 m, quint32 n, QString multisigId, QVariantList membershipProgramId) {
	backend()->createMultisig(creatorId, configHash, memberRoot, m, n, multisigId, membershipProgramId);
}
void PrivateMultisigPlugin::createProposal(QString proposerId, QString configHash, QString proposalSeed, QString proposalId, QString recipient, QString amount) {
	backend()->createProposal(proposerId, configHash, proposalSeed, proposalId, recipient, amount);
}
void PrivateMultisigPlugin::approve(QString configHash, QString proposalSeed, QString memberRoot, QString claimedNullifier, QVariantList witness) {
	backend()->approve(configHash, proposalSeed, memberRoot, claimedNullifier, witness);
}
void PrivateMultisigPlugin::execute(QString configHash, QString proposalSeed) {
	backend()->execute(configHash, proposalSeed);
}

void PrivateMultisigPlugin::fetchConfig(QString configHash) { backend()->fetchConfig(configHash); }
void PrivateMultisigPlugin::fetchProposal(QString proposalSeed) { backend()->fetchProposal(proposalSeed); }

void PrivateMultisigPlugin::checkConnection() { backend()->checkConnection(); }
void PrivateMultisigPlugin::listAccounts() { backend()->listAccounts(); }
void PrivateMultisigPlugin::createAccount(QString label) { backend()->createAccount(label); }
void PrivateMultisigPlugin::inspectAccount(QString accountId) { backend()->inspectAccount(accountId); }
void PrivateMultisigPlugin::decodeAccount(QString accountId) { backend()->decodeAccount(accountId); }
void PrivateMultisigPlugin::saveHistory(QString key, QString value) { backend()->saveHistory(key, value); }
