#include "settings.h"

#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>

static QString settingsPath()
{
    // Sailfish convention: ~/.config/<org>/<app>/<app>.conf
    QString dir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
        + "/cz.mig/harbour-todotxt";
    QDir().mkpath(dir);
    return dir + "/harbour-todotxt.conf";
}

Settings::Settings(QObject *parent)
    : QObject(parent)
    , m_settings(settingsPath(), QSettings::IniFormat)
{
}

QString Settings::defaultTodoFile()
{
    QString docs = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (docs.isEmpty())
        docs = QDir::homePath() + "/Documents";
    return docs + "/todotxt/todo.txt";
}

QString Settings::doneFile() const
{
    QFileInfo fi(todoFile());
    return fi.dir().filePath("done.txt");
}
