#include "settings.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QTextStream>

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

QStringList Settings::exampleTodoLines(const QDate &today)
{
    auto d = [&today](int days) { return today.addDays(days).toString("yyyy-MM-dd"); };
    QStringList lines;
    lines << "(A) Pay the electricity bill @home +finance due:" + d(-3);
    lines << "(B) Call the plumber @home +renovation due:" + d(0);
    lines << "Book dentist appointment @health due:" + d(1);
    lines << "Review pull request +work due:" + d(2);
    lines << "Buy a birthday gift +family t:" + d(2) + " due:" + d(10);
    lines << "Prepare the meeting slides +work due:" + d(7);
    lines << "Water the plants @home rec:1w due:" + d(7);
    lines << "Read the todo.txt documentation";
    lines << "x " + d(-2) + " Buy groceries @errands";
    return lines;
}

QStringList Settings::exampleDoneLines(const QDate &today)
{
    QStringList lines;
    lines << "x " + today.addDays(-5).toString("yyyy-MM-dd") + " Clean up the old example list +archive";
    return lines;
}

static bool writeLines(const QString &path, const QStringList &lines)
{
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    QTextStream out(&f);
#if QT_VERSION < 0x060000
    out.setCodec("UTF-8");
#endif
    foreach (const QString &l, lines)
        out << l << "\n";
    out.flush();
    f.close();
    return true;
}

void Settings::createExampleList()
{
    if (todoFolderConfigured())
        return;
    const QString folder = defaultTodoFolder();
    QDir().mkpath(folder);
    const QDate today = QDate::currentDate();
    const QString todo = QDir(folder).filePath("todo.txt");
    const QString done = QDir(folder).filePath("done.txt");
    // Never overwrite existing data; only fill in what is missing.
    if (!QFile::exists(todo))
        writeLines(todo, exampleTodoLines(today));
    if (!QFile::exists(done))
        writeLines(done, exampleDoneLines(today));
    // Configure the folder (the plain setter would not, since todoFolder()
    // already falls back to this same default value).
    if (QFile::exists(todo)) {
        m_settings.setValue("todoFolder", folder);
        setExampleFolder(folder);
        setExampleList(true);
        emit todoFolderChanged();
    }
}

void Settings::dismissExampleHint()
{
    setExampleList(false);
}
