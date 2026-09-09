// Basecamp's replica-factory interface, reconstructed from the application binary.
//
// Logos Basecamp ships no headers. Its QML bridge loads a plugin declaring this IID beside each
// `ui_qml` module and calls it to build the replica the QML talks to; without one,
// `logos.module()` returns null and every panel is inert.
//
// The layout below was read out of Basecamp's own package_manager_ui_replica_factory.dylib rather
// than guessed. Its secondary sub-vtable is:
//
//     [offset-to-top][typeinfo][~dtor D1][~dtor D0][acquire][replicaMetaObject]
//
// so the destructor is virtual and comes first. **This matters more than it looks.** A wrong layout
// is not a compile error: the host calls what it believes is `acquire` at a fixed slot and lands on
// whatever is there. Declaring these two methods without the destructor cost two crashes — one in
// Basecamp itself:
//
//     0  ???             vtable for __cxxabiv1::__class_type_info + 16
//     1  main_ui.dylib   LogosQmlBridge::module(QString const&) + 320
//
// and one in our own factory load test, which had a second copy of this declaration and so drifted
// from the first. Hence one header, included by both.
#pragma once

#include <QtPlugin>

class QMetaObject;
class QObject;
class QRemoteObjectNode;

class LogosViewReplicaFactory {
public:
	virtual ~LogosViewReplicaFactory() = default;
	virtual QObject*           acquire(QRemoteObjectNode* node) = 0;
	virtual const QMetaObject* replicaMetaObject() const        = 0;
};

#define LogosViewReplicaFactory_iid "logos.view.replica_factory/1.0"
Q_DECLARE_INTERFACE(LogosViewReplicaFactory, LogosViewReplicaFactory_iid)
