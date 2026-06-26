#include <QApplication>
#include <QDir>
#include <QFileInfo>
#include <QMessageBox>
#include <QProcess>
#include <QString>
#include <QTextStream>
#include <stdlib.h>
#include "gamestoreform.h"

QString detectDistro()
{
  QFileInfo fi("/etc/SuSE-release");
  if (fi.exists()) return "openSUSE";
  return "";
}

bool detect3D()
{
  QProcess glxinfo;
  glxinfo.start("glxinfo");
  if (!glxinfo.waitForStarted(1000)) return false;
  if (!glxinfo.waitForFinished(1000)) return false;
  QByteArray o = glxinfo.readAll();
  return ( o.indexOf(QByteArray("direct rendering: Yes")) > -1 );
}

int main( int argc, char *argv[] )
{
  QApplication app( argc, argv );

  GameStoreInfo::distro = detectDistro();
  if (GameStoreInfo::distro.isEmpty()) {
    QMessageBox::critical(0, "Error", "Game Store was unable to detect your distribution.");
    return 1;
  }

  char *tmp = getenv("XDG_CACHE_HOME");
  GameStoreInfo::cachedir = tmp ? tmp : QDir::homePath() + "/.cache";
  GameStoreInfo::cachedir += + "/gamestore/";
  QDir dir;
  dir.mkpath(GameStoreInfo::cachedir + "icon");
  dir.mkpath(GameStoreInfo::cachedir + "thumb");

  GameStoreForm *window = new GameStoreForm();
  window->show();

  if (!detect3D()) {
    QMessageBox::warning(0, "Warning", "Your system reports that it is not capable of hardware accelerated 3D graphics. You might expect difficulties running some of the games.
Usually the cause of this error is that there are no drivers for your graphics card installed.");
  }

  return app.exec();
}
