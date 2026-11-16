#ifndef SETTINGS_H
#define SETTINGS_H

#include <QObject>
#include <QSettings>
#include <QString>

#define SETTING(type, name, Name, key, def) \
    Q_PROPERTY(type name READ name WRITE set##Name NOTIFY name##Changed) \
    public: \
    type name() const { return m_settings.value(key, def).value<type>(); } \
    void set##Name(const type &v) { if (name() == v) return; m_settings.setValue(key, v); emit name##Changed(); } \
    Q_SIGNAL void name##Changed();

class Settings : public QObject
{
    Q_OBJECT
    SETTING(QString, todoFile, TodoFile, "todoFile", defaultTodoFile())
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

public:
    explicit Settings(QObject *parent = 0);
    static QString defaultTodoFile();
    Q_INVOKABLE QString doneFile() const;

private:
    QSettings m_settings;
};

#endif // SETTINGS_H
