#ifndef TODOSTORE_H
#define TODOSTORE_H

#include <QObject>
#include <QList>
#include <QTimer>
#include <QFileSystemWatcher>
#include <QDateTime>
#include <QVariantList>
#include "task.h"

class Settings;

// In-memory todo.txt with load/save, file watching and task operations.
class TodoStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool changesPending READ changesPending NOTIFY changesPendingChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString todoFile READ todoFile NOTIFY todoFileChanged)
    Q_PROPERTY(int count READ count NOTIFY tasksChanged)

public:
    explicit TodoStore(Settings *settings, QObject *parent = 0);

    bool changesPending() const { return m_changesPending; }
    bool loaded() const { return m_loaded; }
    QString error() const { return m_error; }
    QString todoFile() const;
    int count() const { return m_tasks.size(); }

    const QList<Task> &tasks() const { return m_tasks; }
    Task *findTask(int id);
    int indexOfId(int id) const;

    // Called by the model/UI after modifying tasks through findTask().
    void notifyChanged();

    Q_INVOKABLE void reload();
    Q_INVOKABLE void saveNow();

    // Task operations (ids are task ids). All schedule a save.
    Q_INVOKABLE QVariantList addTasks(const QString &text);      // one task per line, returns new ids
    Q_INVOKABLE void updateTasks(const QVariantList &ids, const QString &text); // line i -> task i
    Q_INVOKABLE QString taskText(int id) const;
    Q_INVOKABLE void complete(const QVariantList &ids);
    Q_INVOKABLE void uncomplete(const QVariantList &ids);
    Q_INVOKABLE void toggleComplete(int id);
    // Mark/unmark a single occurrence of a recurring series as done.
    Q_INVOKABLE void toggleDone(int id, const QString &date);
    Q_INVOKABLE void remove(const QVariantList &ids);
    Q_INVOKABLE void setPriority(const QVariantList &ids, const QString &code);
    Q_INVOKABLE void deferDue(const QVariantList &ids, const QString &deferString);
    Q_INVOKABLE void deferThreshold(const QVariantList &ids, const QString &deferString);
    Q_INVOKABLE void addLists(const QVariantList &ids, const QStringList &names);
    Q_INVOKABLE void removeLists(const QVariantList &ids, const QStringList &names);
    Q_INVOKABLE void addTags(const QVariantList &ids, const QStringList &names);
    Q_INVOKABLE void removeTags(const QVariantList &ids, const QStringList &names);
    Q_INVOKABLE int archive(const QVariantList &ids);   // completed among ids -> done.txt; returns count

    Q_INVOKABLE QStringList allLists() const;
    Q_INVOKABLE QStringList allTags() const;
    Q_INVOKABLE QStringList allPriorities() const;

    // Keys of sorts needed by saved filters (union); used to clean #N.
    void setManualOrderNeeded(bool needed);

signals:
    void tasksChanged();
    void changesPendingChanged();
    void loadedChanged();
    void errorChanged();
    void todoFileChanged();
    void archived(int count);

private slots:
    void onFileChanged(const QString &path);
    void onDirectoryChanged(const QString &path);
    void onTodoFileSettingChanged();

private:
    QList<Task *> resolve(const QVariantList &ids);
    void markDirty();
    bool writeFile(const QString &path, const QStringList &lines);
    void updateWatcher();
    void rememberFileState();
    bool fileStateChanged() const;
    void cleanupManualOrder();
    void setError(const QString &e);
    QString eol() const;

    Settings *m_settings;
    QList<Task> m_tasks;
    bool m_changesPending;
    bool m_loaded;
    QString m_error;
    QTimer m_saveTimer;
    QTimer m_watchTimer;
    QFileSystemWatcher m_watcher;
    QDateTime m_fileMtime;
    qint64 m_fileSize;
    bool m_manualOrderNeeded;
};

#endif // TODOSTORE_H
