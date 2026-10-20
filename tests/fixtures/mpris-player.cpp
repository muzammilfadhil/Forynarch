#include <QCoreApplication>
#include <QDBusAbstractAdaptor>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QVariantMap>

class Player final : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(QString PlaybackStatus READ status)
    Q_PROPERTY(QVariantMap Metadata READ metadata)
    Q_PROPERTY(bool CanControl READ yes)
    Q_PROPERTY(bool CanPlay READ yes)
    Q_PROPERTY(bool CanPause READ yes)
    Q_PROPERTY(bool CanGoNext READ yes)
    Q_PROPERTY(bool CanGoPrevious READ yes)
    Q_PROPERTY(bool CanSeek READ no)
    Q_PROPERTY(qlonglong Position READ position)
    Q_PROPERTY(double Rate READ one)
    Q_PROPERTY(double MinimumRate READ one)
    Q_PROPERTY(double MaximumRate READ one)
    Q_PROPERTY(double Volume READ one)
    Q_PROPERTY(bool Shuffle READ no)
    Q_PROPERTY(QString LoopStatus READ loop)
public:
    explicit Player(QObject *parent):QDBusAbstractAdaptor(parent){}
    QString playback="Playing";
    QString status()const{return playback;}
    bool yes()const{return true;} bool no()const{return false;}
    double one()const{return 1;} qlonglong position()const{return 0;}
    QString loop()const{return "None";}
    QVariantMap metadata()const{return {{"xesam:title","Blue Hour QA"},{"xesam:artist",QStringList{"Forynarch"}},{"xesam:asText","First lyric line\nSecond lyric line"},{"mpris:artUrl","file:///tmp/forynarch-media-art.svg"},{"mpris:trackid",QVariant::fromValue(QDBusObjectPath("/org/mpris/MediaPlayer2/Track/1"))},{"mpris:length",QVariant::fromValue<qlonglong>(12000000)}};}
    void update(const QString &value){playback=value;auto signal=QDBusMessage::createSignal("/org/mpris/MediaPlayer2","org.freedesktop.DBus.Properties","PropertiesChanged");signal<<QString("org.mpris.MediaPlayer2.Player")<<QVariantMap{{"PlaybackStatus",playback}}<<QStringList{};QDBusConnection::sessionBus().send(signal);}
public slots:
    void Pause(){update("Paused");} void Play(){update("Playing");}
    void PlayPause(){update(playback=="Playing"?"Paused":"Playing");}
    void Stop(){update("Stopped");} void Next(){} void Previous(){}
};
class Identity final : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    Q_PROPERTY(QString Identity READ identity)
    Q_PROPERTY(QString DesktopEntry READ desktop)
    Q_PROPERTY(bool CanQuit READ no)
    Q_PROPERTY(bool CanRaise READ no)
    Q_PROPERTY(bool HasTrackList READ no)
    Q_PROPERTY(QStringList SupportedUriSchemes READ schemes)
    Q_PROPERTY(QStringList SupportedMimeTypes READ types)
public:
    explicit Identity(QObject *parent):QDBusAbstractAdaptor(parent){}
    QString identity()const{return "Forynarch QA Player";} QString desktop()const{return "forynarch-qa-player";}
    bool no()const{return false;} QStringList schemes()const{return {"file"};} QStringList types()const{return {"audio/wav"};}
public slots: void Raise(){} void Quit(){}
};
int main(int argc,char **argv){QCoreApplication app(argc,argv);QObject object;new Player(&object);new Identity(&object);auto bus=QDBusConnection::sessionBus();if(!bus.registerService("org.mpris.MediaPlayer2.forynarch_qa")||!bus.registerObject("/org/mpris/MediaPlayer2",&object,QDBusConnection::ExportAdaptors))return 1;return app.exec();}
#include "mpris-player.moc"
