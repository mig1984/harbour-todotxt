#ifndef SETTINGS_H
#define SETTINGS_H

#include <QObject>
#include <QSettings>
#include <QString>
#include <QStringList>
#include <QDate>

#define SETTING(type, name, Name, key, def) \
    Q_PROPERTY(type name READ name WRITE set##Name NOTIFY name##Changed) \
    public: \
    type name() const { return m_settings.value(key, def).value<type>(); } \
    void set##Name(const type &v) { if (name() == v) return; m_settings.setValue(key, v); emit name##Changed(); } \
    Q_SIGNAL void name##Changed();

class Settings : public QObject
{
    Q_OBJECT
    SETTING(QString, todoFolder, TodoFolder, "todoFolder", defaultTodoFolder())
    SETTING(bool, prependDate, PrependDate, "prependDate", true)
    SETTING(bool, appendAtEnd, AppendAtEnd, "appendAtEnd", true)
    SETTING(bool, keepPriority, KeepPriority, "keepPriority", true)
    SETTING(bool, autoArchive, AutoArchive, "autoArchive", false)
    SETTING(int, idleBeforeSave, IdleBeforeSave, "idleBeforeSave", 3)
    SETTING(bool, windowsEol, WindowsEol, "windowsEol", false)
    SETTING(bool, uppercaseHeaders, UppercaseHeaders, "uppercaseHeaders", true)
    SETTING(bool, colorDates, ColorDates, "colorDates", true)
    SETTING(bool, showDateBar, ShowDateBar, "showDateBar", true)
    SETTING(bool, todoTxtTerms, TodoTxtTerms, "todoTxtTerms", false)
    SETTING(bool, caseSensitiveSort, CaseSensitiveSort, "caseSensitiveSort", false)
    SETTING(bool, backClearsFilter, BackClearsFilter, "backClearsFilter", false)
    SETTING(bool, capitalizeTasks, CapitalizeTasks, "capitalizeTasks", true)
    SETTING(QString, queryJson, QueryJson, "queryJson", QString())
    SETTING(QString, savedFiltersJson, SavedFiltersJson, "savedFiltersJson", QString())
    SETTING(int, calendarYear, CalendarYear, "calendarYear", 0)
    SETTING(int, calendarMonth, CalendarMonth, "calendarMonth", -1)
    // Set while the folder holds the first-run example list (see createExampleList).
    SETTING(bool, exampleList, ExampleList, "exampleList", false)
    SETTING(QString, exampleFolder, ExampleFolder, "exampleFolder", QString())

public:
    explicit Settings(QObject *parent = 0);
    static QString defaultTodoFolder();

    // First-run example list: written into the default folder when no folder
    // has been configured yet, so a fresh install opens with a usable sample
    // list (dates relative to today). The line generators are pure so they can
    // be unit-tested.
    void createExampleList();
    static QStringList exampleTodoLines(const QDate &today);
    static QStringList exampleDoneLines(const QDate &today);
    // Hide the "this is an example list" hint (called when it is tapped).
    Q_INVOKABLE void dismissExampleHint();

    // The folder is what the user picks; todo.txt and done.txt live inside it.
    Q_PROPERTY(QString todoFile READ todoFile NOTIFY todoFolderChanged)
    Q_PROPERTY(bool todoFolderConfigured READ todoFolderConfigured NOTIFY todoFolderChanged)
    QString todoFile() const;
    bool todoFolderConfigured() const;
    Q_INVOKABLE QString doneFile() const;

private:
    QSettings m_settings;
};

#endif // SETTINGS_H
