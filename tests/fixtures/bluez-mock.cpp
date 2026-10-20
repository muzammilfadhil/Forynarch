#include <QtCore>
#include <QtDBus>
#include <cstdio>

static QString client, agentPath;
static const QString devicePath = "/org/bluez/hci0/dev_00_11_22_33_44_55";

class Manager : public QObject, public QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.bluez.AgentManager1")
public slots:
    void RegisterAgent(const QDBusObjectPath &path, const QString &capability) {
        if (capability != "KeyboardDisplay") {sendErrorReply("org.bluez.Error.Rejected", "Unexpected capability");return;}
        client=message().service();agentPath=path.path();
    }
};

class Device : public QObject, public QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.bluez.Device1")
    QDBusConnection bus=QDBusConnection::sessionBus();
public slots:
    void Pair() {
        setDelayedReply(true);
        const auto original=message();
        auto call=QDBusMessage::createMethodCall(client,agentPath,"org.bluez.Agent1","RequestConfirmation");
        call << QVariant::fromValue(QDBusObjectPath(devicePath)) << QVariant::fromValue(uint(123456));
        auto *watcher=new QDBusPendingCallWatcher(bus.asyncCall(call),this);
        connect(watcher,&QDBusPendingCallWatcher::finished,this,[this,original](QDBusPendingCallWatcher *result) {
            QDBusPendingReply<> reply=*result;
            bus.send(reply.isError()?original.createErrorReply("org.bluez.Error.Rejected","Confirmation rejected"):original.createReply());
            result->deleteLater();
        });
    }
    void Connect() {}
    void CancelPairing() {}
};

int main(int argc,char **argv) {
    QCoreApplication app(argc,argv);
    auto bus=QDBusConnection::sessionBus();
    Manager manager;Device device;
    if(!bus.registerService("org.bluez") || !bus.registerObject("/org/bluez",&manager,QDBusConnection::ExportAllSlots) || !bus.registerObject(devicePath,&device,QDBusConnection::ExportAllSlots))return 1;
    std::puts("READY");std::fflush(stdout);
    return app.exec();
}
#include "bluez-mock.moc"
