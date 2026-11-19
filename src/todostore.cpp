#include "todostore.h"
#include "settings.h"

#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QSaveFile>
#include <QTextStream>
#include <QDebug>
#include <algorithm>

TodoStore::TodoStore(Settings *settings, QObject *parent)
    : QObject(parent)
    , m_settings(settings)
    , m_changesPending(false)
    , m_loaded(false)
    , m_fileSize(-1)
    , m_manualOrderNeeded(false)
{
    m_saveTimer.setSingleShot(true);
    connect(&m_saveTimer, SIGNAL(timeout()), this, SLOT(saveNow()));
    m_watchTimer.setSingleShot(true);
    m_watchTimer.setInterval(700);
    connect(&m_watchTimer, SIGNAL(timeout()), this, SLOT(reload()));
    connect(&m_watcher, SIGNAL(fileChanged(QString)), this, SLOT(onFileChanged(QString)));
    connect(&m_watcher, SIGNAL(directoryChanged(QString)), this, SLOT(onDirectoryChanged(QString)));
    connect(m_settings, SIGNAL(todoFolderChanged()), this, SLOT(onTodoFileSettingChanged()));
}

QString TodoStore::todoFile() const
{
    return m_settings->todoFile();
}

QString TodoStore::eol() const
{
    return m_settings->windowsEol() ? "\r\n" : "\n";
}

void TodoStore::setError(const QString &e)
{
    if (m_error == e)
        return;
    m_error = e;
    emit errorChanged();
}

Task *TodoStore::findTask(int id)
{
    for (int i = 0; i < m_tasks.size(); ++i)
        if (m_tasks[i].id() == id)
            return &m_tasks[i];
    return 0;
}

int TodoStore::indexOfId(int id) const
{
    for (int i = 0; i < m_tasks.size(); ++i)
        if (m_tasks[i].id() == id)
            return i;
    return -1;
}

QList<Task *> TodoStore::resolve(const QVariantList &ids)
{
    QList<Task *> r;
    foreach (const QVariant &v, ids) {
        Task *t = findTask(v.toInt());
        if (t)
            r << t;
    }
    return r;
}

void TodoStore::notifyChanged()
{
    markDirty();
}

void TodoStore::markDirty()
{
    if (!m_changesPending) {
        m_changesPending = true;
        emit changesPendingChanged();
    }
    m_saveTimer.start(qMax(0, m_settings->idleBeforeSave()) * 1000);
    emit tasksChanged();
}

void TodoStore::onTodoFileSettingChanged()
{
    if (m_changesPending)
        saveNow();
    emit todoFileChanged();
    reload();
}

void TodoStore::updateWatcher()
{
    if (!m_watcher.files().isEmpty())
        m_watcher.removePaths(m_watcher.files());
    if (!m_watcher.directories().isEmpty())
        m_watcher.removePaths(m_watcher.directories());
    QFileInfo fi(todoFile());
    if (fi.exists())
        m_watcher.addPath(fi.absoluteFilePath());
    if (fi.dir().exists())
        m_watcher.addPath(fi.dir().absolutePath());
}

void TodoStore::rememberFileState()
{
    QFileInfo fi(todoFile());
    fi.refresh();
    m_fileMtime = fi.lastModified();
    m_fileSize = fi.exists() ? fi.size() : -1;
}

bool TodoStore::fileStateChanged() const
{
    QFileInfo fi(todoFile());
    fi.refresh();
    qint64 size = fi.exists() ? fi.size() : -1;
    return size != m_fileSize || fi.lastModified() != m_fileMtime;
}

void TodoStore::onFileChanged(const QString &)
{
    updateWatcher();
    if (fileStateChanged())
        m_watchTimer.start();
}

void TodoStore::onDirectoryChanged(const QString &)
{
    updateWatcher();
    if (fileStateChanged())
        m_watchTimer.start();
}

void TodoStore::reload()
{
    m_watchTimer.stop();
    if (m_changesPending) {
        // Local edits win; they will overwrite the external change.
        saveNow();
        return;
    }
    const QString path = todoFile();
    QFile f(path);
    QList<Task> tasks;
    if (f.exists()) {
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            setError(tr("Cannot read %1").arg(path));
            updateWatcher();
            return;
        }
        QTextStream in(&f);
#if QT_VERSION < 0x060000
        in.setCodec("UTF-8");
#endif
        while (!in.atEnd()) {
            QString line = in.readLine();
            if (line.endsWith('\r'))
                line.chop(1);
            tasks << Task(line);
        }
        f.close();
    } else {
        QDir().mkpath(QFileInfo(path).absolutePath());
    }
    setError(QString());
    m_tasks = tasks;
    rememberFileState();
    updateWatcher();
    if (!m_loaded) {
        m_loaded = true;
        emit loadedChanged();
    }
    emit tasksChanged();
}

bool TodoStore::writeFile(const QString &path, const QStringList &lines)
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile f(path);
    if (!f.open(QIODevice::WriteOnly)) {
        setError(tr("Cannot write %1").arg(path));
        return false;
    }
    QByteArray data;
    const QString e = eol();
    foreach (const QString &l, lines)
        data += (l + e).toUtf8();
    f.write(data);
    if (!f.commit()) {
        setError(tr("Cannot write %1").arg(path));
        return false;
    }
    setError(QString());
    return true;
}

void TodoStore::cleanupManualOrder()
{
    for (int i = 0; i < m_tasks.size(); ++i) {
        if (m_tasks[i].manualOrder() < 0)
            continue;
        if (!m_manualOrderNeeded || m_tasks[i].isCompleted())
            m_tasks[i].clearManualOrder();
    }
}

void TodoStore::setManualOrderNeeded(bool needed)
{
    m_manualOrderNeeded = needed;
}

void TodoStore::saveNow()
{
    m_saveTimer.stop();
    if (!m_changesPending)
        return;
    cleanupManualOrder();
    QStringList lines;
    foreach (const Task &t, m_tasks)
        lines << t.text();
    // Drop trailing empty lines (the file always ends with one EOL).
    while (!lines.isEmpty() && lines.last().trimmed().isEmpty())
        lines.removeLast();
    if (writeFile(todoFile(), lines)) {
        m_changesPending = false;
        emit changesPendingChanged();
        rememberFileState();
        updateWatcher();
    } else {
        // retry later
        m_saveTimer.start(10000);
    }
}

QVariantList TodoStore::addTasks(const QString &text)
{
    QVariantList ids;
    const QString today = Task::today();
    const QString prepend = m_settings->prependDate() ? today : QString();
    QList<Task> added;
    foreach (const QString &line, text.split('\n')) {
        if (line.trimmed().isEmpty())
            continue;
        Task t(line, prepend);
        ids << t.id();
        added << t;
    }
    if (added.isEmpty())
        return ids;
    if (m_settings->appendAtEnd())
        m_tasks += added;
    else
        m_tasks = added + m_tasks;
    markDirty();
    return ids;
}

void TodoStore::updateTasks(const QVariantList &ids, const QString &text)
{
    QStringList lines = text.split('\n');
    QList<Task *> tasks = resolve(ids);
    int i = 0;
    QString extra;
    QVariantList toRemove;
    for (; i < lines.size(); ++i) {
        if (i < tasks.size()) {
            tasks[i]->update(lines[i]);
        } else if (!lines[i].trimmed().isEmpty()) {
            extra += lines[i] + "\n";
        }
    }
    for (; i < tasks.size(); ++i)
        toRemove << tasks[i]->id();
    if (!toRemove.isEmpty()) {
        foreach (const QVariant &v, toRemove) {
            int idx = indexOfId(v.toInt());
            if (idx >= 0)
                m_tasks.removeAt(idx);
        }
    }
    markDirty();
    if (!extra.isEmpty())
        addTasks(extra);
}

QString TodoStore::taskText(int id) const
{
    int idx = indexOfId(id);
    return idx < 0 ? QString() : m_tasks[idx].text();
}

void TodoStore::complete(const QVariantList &ids)
{
    const QString today = Task::today();
    QList<Task> recurring;
    QVariantList completedIds;
    foreach (const QVariant &v, ids) {
        Task *t = findTask(v.toInt());
        if (!t || t->isCompleted())
            continue;
        if (t->isSeries()) {
            // Recurring series: mark this occurrence done, keep the task.
            t->addDoneDate(t->dueDate());
            continue;
        }
        Task n;
        if (t->markComplete(today, &n))
            recurring << n;
        if (!m_settings->keepPriority())
            t->setPriority('-');
        completedIds << t->id();
    }
    if (!recurring.isEmpty()) {
        if (m_settings->appendAtEnd())
            m_tasks += recurring;
        else
            m_tasks = recurring + m_tasks;
    }
    markDirty();
    if (m_settings->autoArchive() && !completedIds.isEmpty())
        archive(completedIds);
}

void TodoStore::uncomplete(const QVariantList &ids)
{
    foreach (Task *t, resolve(ids)) {
        if (t->isSeries())
            t->removeDoneDate(t->dueDate());
        else
            t->markIncomplete();
    }
    markDirty();
}

void TodoStore::toggleComplete(int id)
{
    Task *t = findTask(id);
    if (!t)
        return;
    QVariantList ids;
    ids << id;
    if (t->isSeries()) {
        if (t->doneDates().contains(t->dueDate()))
            t->removeDoneDate(t->dueDate());
        else
            t->addDoneDate(t->dueDate());
        markDirty();
        return;
    }
    if (t->isCompleted())
        uncomplete(ids);
    else
        complete(ids);
}

void TodoStore::toggleDone(int id, const QString &date)
{
    Task *t = findTask(id);
    if (!t || date.isEmpty())
        return;
    if (t->doneDates().contains(date))
        t->removeDoneDate(date);
    else
        t->addDoneDate(date);
    markDirty();
}

void TodoStore::remove(const QVariantList &ids)
{
    foreach (const QVariant &v, ids) {
        int idx = indexOfId(v.toInt());
        if (idx >= 0)
            m_tasks.removeAt(idx);
    }
    markDirty();
}

void TodoStore::setPriority(const QVariantList &ids, const QString &code)
{
    QChar c = code.isEmpty() ? QChar('-') : code.at(0);
    foreach (Task *t, resolve(ids))
        t->setPriority(c);
    markDirty();
}

void TodoStore::deferDue(const QVariantList &ids, const QString &deferString)
{
    foreach (Task *t, resolve(ids))
        t->deferDueDate(deferString, Task::today());
    markDirty();
}

void TodoStore::deferThreshold(const QVariantList &ids, const QString &deferString)
{
    foreach (Task *t, resolve(ids))
        t->deferThresholdDate(deferString, Task::today());
    markDirty();
}

void TodoStore::addLists(const QVariantList &ids, const QStringList &names)
{
    foreach (Task *t, resolve(ids))
        foreach (const QString &n, names)
            t->addList(n);
    markDirty();
}

void TodoStore::removeLists(const QVariantList &ids, const QStringList &names)
{
    foreach (Task *t, resolve(ids))
        foreach (const QString &n, names)
            t->removeList(n);
    markDirty();
}

void TodoStore::addTags(const QVariantList &ids, const QStringList &names)
{
    foreach (Task *t, resolve(ids))
        foreach (const QString &n, names)
            t->addTag(n);
    markDirty();
}

void TodoStore::removeTags(const QVariantList &ids, const QStringList &names)
{
    foreach (Task *t, resolve(ids))
        foreach (const QString &n, names)
            t->removeTag(n);
    markDirty();
}

int TodoStore::archive(const QVariantList &ids)
{
    QStringList lines;
    QList<int> idxs;
    foreach (const QVariant &v, ids) {
        int idx = indexOfId(v.toInt());
        if (idx >= 0 && m_tasks[idx].isCompleted()) {
            Task t = m_tasks[idx];
            t.clearManualOrder();
            lines << t.text();
            idxs << idx;
        }
    }
    if (lines.isEmpty())
        return 0;
    const QString donePath = m_settings->doneFile();
    if (QFileInfo(donePath) == QFileInfo(todoFile()))
        return 0;
    QFile f(donePath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Append)) {
        setError(tr("Cannot write %1").arg(donePath));
        return 0;
    }
    const QString e = eol();
    foreach (const QString &l, lines)
        f.write((l + e).toUtf8());
    f.close();
    std::sort(idxs.begin(), idxs.end());
    for (int i = idxs.size() - 1; i >= 0; --i)
        m_tasks.removeAt(idxs[i]);
    markDirty();
    emit archived(lines.size());
    return lines.size();
}

static QStringList sortedUnique(QStringList l)
{
    l.removeDuplicates();
    std::sort(l.begin(), l.end(), [](const QString &a, const QString &b) {
        return QString::compare(a, b, Qt::CaseInsensitive) < 0;
    });
    return l;
}

QStringList TodoStore::allLists() const
{
    QStringList r;
    foreach (const Task &t, m_tasks)
        r += t.lists();
    return sortedUnique(r);
}

QStringList TodoStore::allTags() const
{
    QStringList r;
    foreach (const Task &t, m_tasks)
        r += t.tags();
    return sortedUnique(r);
}

QStringList TodoStore::allPriorities() const
{
    QStringList r;
    foreach (const Task &t, m_tasks)
        if (t.priority() != '-')
            r << QString(t.priority());
    r.removeDuplicates();
    std::sort(r.begin(), r.end());
    return r;
}
