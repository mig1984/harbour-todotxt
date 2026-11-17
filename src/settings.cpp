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
    // Migrate the old "todoFile" setting (a path to todo.txt) to the folder
    // that contains todo.txt and done.txt.
    if (!m_settings.contains("todoFolder") && m_settings.contains("todoFile")) {
        const QString legacy = m_settings.value("todoFile").toString();
        if (!legacy.isEmpty())
            m_settings.setValue("todoFolder", QFileInfo(legacy).dir().path());
    }
}

QString Settings::defaultTodoFolder()
{
    QString docs = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (docs.isEmpty())
        docs = QDir::homePath() + "/Documents";
    return docs + "/todotxt";
}

QString Settings::todoFile() const
{
    return QDir(todoFolder()).filePath("todo.txt");
}

bool Settings::todoFolderConfigured() const
{
    return m_settings.contains("todoFolder");
}

QString Settings::doneFile() const
{
    return QDir(todoFolder()).filePath("done.txt");
}
