#include <QCoreApplication>
#include <QtDBus>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSocketNotifier>
#include <QTimer>
#include <QRegularExpression>
#include <csignal>
#include <fcntl.h>
#include <unistd.h>
#include <utility>

static int signalPipe[2];
static void interrupted(int) { const char byte = 1; const auto ignored = ::write(signalPipe[1], &byte, 1); (void) ignored; }

class PairAgent final : public QObject, public QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.bluez.Agent1")
    QDBusConnection bus = QDBusConnection::systemBus();
    QString devicePath;
    QDBusMessage pending;
    QString prompt;
    QByteArray input;
    bool waiting = false;
    bool finishing = false;
    QTimer timeout;

    void publish(const QJsonObject &object) {
        const auto line = QJsonDocument(object).toJson(QJsonDocument::Compact) + '\n';
        const auto ignored = ::write(STDOUT_FILENO, line.constData(), size_t(line.size()));
        (void) ignored;
    }
    bool bluezSender() {
        if (!calledFromDBus()) return false;
        const auto owner = bus.interface()->serviceOwner("org.bluez");
        return owner.isValid() && message().service() == owner.value();
    }
    bool allowed(const QDBusObjectPath &device) {
        if (!calledFromDBus()) return false;
        if (!bluezSender() || device.path() != devicePath) {
            sendErrorReply("org.bluez.Error.Rejected", "Pairing request rejected");
            return false;
        }
        return true;
    }
    void rejectPending() {
        if (waiting) bus.send(pending.createErrorReply("org.bluez.Error.Canceled", "Pairing canceled"));
        waiting = false; prompt.clear(); pending = QDBusMessage();
    }
    void request(const QDBusObjectPath &device, const QString &kind, const QString &code = {}) {
        if (!allowed(device)) return;
        if (waiting || finishing) {sendErrorReply("org.bluez.Error.Rejected", "Another request is pending"); return;}
        setDelayedReply(true); pending = message(); waiting = true; prompt = kind;
        publish({{"type", kind}, {"code", code}});
    }
    void finish(const QString &kind) {
        if (finishing) return;
        finishing = true; timeout.stop(); rejectPending();
        publish({{"type", kind}});
        QTimer::singleShot(100, QCoreApplication::instance(), &QCoreApplication::quit);
    }
    void cancel() {
        if (finishing) return;
        QDBusMessage call = QDBusMessage::createMethodCall("org.bluez", devicePath, "org.bluez.Device1", "CancelPairing");
        bus.call(call, QDBus::NoBlock);
        finish("canceled");
    }
    void response(const QJsonObject &object) {
        if (object.value("cancel").toBool()) {cancel(); return;}
        if (!waiting) return;
        QVariantList args;
        if (prompt == "pin") {
            const auto pin = object.value("pin").toString();
            if (pin.isEmpty() || pin.size() > 16) {cancel(); return;}
            args << pin;
        } else if (prompt == "passkey") {
            const auto value = object.value("passkey").toString();
            if (!QRegularExpression("^[0-9]{1,6}$").match(value).hasMatch()) {cancel(); return;}
            args << QVariant::fromValue(value.toUInt());
        } else if (!object.value("approve").toBool()) {cancel(); return;}
        bus.send(pending.createReply(args));
        waiting = false; pending = QDBusMessage(); prompt.clear();
        publish({{"type", "waiting"}});
    }
    void readInput() {
        char chunk[1024]; ssize_t count;
        while ((count = ::read(STDIN_FILENO, chunk, sizeof(chunk))) > 0) input.append(chunk, qsizetype(count));
        if (count == 0 || input.size() > 8192) {cancel(); return;}
        qsizetype newline;
        while ((newline = input.indexOf('\n')) >= 0) {
            const auto line = input.left(newline); input.remove(0, newline + 1);
            QJsonParseError error;
            const auto document = QJsonDocument::fromJson(line, &error);
            if (error.error != QJsonParseError::NoError || !document.isObject()) {cancel(); return;}
            response(document.object());
        }
    }
public:
    explicit PairAgent(QString path) : devicePath(std::move(path)) {
        timeout.setSingleShot(true); timeout.setInterval(90000);
        connect(&timeout, &QTimer::timeout, this, [this] {cancel();});
        fcntl(STDIN_FILENO, F_SETFL, fcntl(STDIN_FILENO, F_GETFL) | O_NONBLOCK);
        auto *stdinReady = new QSocketNotifier(STDIN_FILENO, QSocketNotifier::Read, this);
        connect(stdinReady, &QSocketNotifier::activated, this, [this] {readInput();});
        auto *signalReady = new QSocketNotifier(signalPipe[0], QSocketNotifier::Read, this);
        connect(signalReady, &QSocketNotifier::activated, this, [this, signalReady] {signalReady->setEnabled(false); cancel();});
    }
    void start() {
        if (!bus.isConnected() || !bus.registerObject("/org/forynarch/agent", this, QDBusConnection::ExportAllSlots)) {finish("unavailable"); return;}
        QDBusInterface manager("org.bluez", "/org/bluez", "org.bluez.AgentManager1", bus);
        const auto registered = manager.call("RegisterAgent", QVariant::fromValue(QDBusObjectPath("/org/forynarch/agent")), QStringLiteral("KeyboardDisplay"));
        if (registered.type() == QDBusMessage::ErrorMessage) {finish("unavailable"); return;}
        timeout.start(); publish({{"type", "waiting"}});
        QDBusInterface device("org.bluez", devicePath, "org.bluez.Device1", bus);
        auto *pair = new QDBusPendingCallWatcher(device.asyncCall("Pair"), this);
        connect(pair, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *call) {
            QDBusPendingReply<> result = *call; call->deleteLater();
            if (finishing) return;
            if (result.isError()) {finish("failed"); return;}
            publish({{"type", "connecting"}});
            QDBusInterface device("org.bluez", devicePath, "org.bluez.Device1", bus);
            auto *connection = new QDBusPendingCallWatcher(device.asyncCall("Connect"), this);
            connect(connection, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *call) {
                QDBusPendingReply<> result = *call; call->deleteLater();
                finish(result.isError() ? "paired" : "connected");
            });
        });
    }
public slots:
    QString RequestPinCode(const QDBusObjectPath &device) {request(device, "pin"); return {};}
    uint RequestPasskey(const QDBusObjectPath &device) {request(device, "passkey"); return 0;}
    void RequestConfirmation(const QDBusObjectPath &device, uint passkey) {request(device, "confirm", QString::number(passkey).rightJustified(6, '0'));}
    void RequestAuthorization(const QDBusObjectPath &device) {request(device, "authorize");}
    void AuthorizeService(const QDBusObjectPath &device, const QString &) {request(device, "authorize");}
    void DisplayPinCode(const QDBusObjectPath &device, const QString &pin) {if (allowed(device)) publish({{"type", "display"}, {"code", pin}});}
    void DisplayPasskey(const QDBusObjectPath &device, uint passkey, ushort) {if (allowed(device)) publish({{"type", "display"}, {"code", QString::number(passkey).rightJustified(6, '0')}});}
    void Cancel() {if (bluezSender()) {rejectPending(); finish("canceled");} else sendErrorReply("org.bluez.Error.Rejected", "Request rejected");}
    void Release() {if (bluezSender()) {rejectPending(); finish("canceled");} else sendErrorReply("org.bluez.Error.Rejected", "Request rejected");}
};

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    if (argc != 2 || !QRegularExpression("^/org/bluez/hci[0-9]+/dev_([0-9A-Fa-f]{2}_){5}[0-9A-Fa-f]{2}$").match(QString::fromLocal8Bit(argv[1])).hasMatch()) return 2;
    if (pipe2(signalPipe, O_NONBLOCK | O_CLOEXEC) != 0) return 1;
    std::signal(SIGTERM, interrupted); std::signal(SIGINT, interrupted); std::signal(SIGPIPE, SIG_IGN);
    PairAgent agent(QString::fromLocal8Bit(argv[1]));
    QTimer::singleShot(0, &agent, [&agent] {agent.start();});
    return app.exec();
}
#include "main.moc"
