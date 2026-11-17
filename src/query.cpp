#include "query.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QRegularExpression>

static const char *LAST_DATE = "9999-99-99";

Query::Query(QObject *parent)
    : QObject(parent)
    , m_contextsNot(false), m_projectsNot(false), m_prioritiesNot(false)
    , m_hideCompleted(false), m_hideFuture(false), m_hideHidden(true)
    , m_hideLists(false), m_hideTags(false), m_createIsThreshold(false)
    , m_caseSensitive(false)
{
}

QStringList Query::allSortKeys()
{
    // Order is also the default sort order (see defaultSorts()).
    return QStringList() << "completed" << "by_due_date" << "manual"
                         << "by_context" << "by_prio" << "by_project" << "by_creation_date"
                         << "in_future" << "by_threshold_date" << "by_completion_date"
                         << "alphabetical";
}

QStringList Query::defaultSorts()
{
    QStringList r;
    foreach (const QString &k, allSortKeys())
        r << "+!" + k;
    return r;
}

QString Query::sortKeyLabel(const QString &key)
{
    QString k = key;
    if (k.contains('!'))
        k = k.section('!', 1);
    if (k == "completed") return tr("Completed last");
    if (k == "by_context") return tr("Context");
    if (k == "by_prio") return tr("Priority");
    if (k == "alphabetical") return tr("Alphabetical");
    if (k == "manual") return tr("Manual order (#N)");
    if (k == "by_project") return tr("Project");
    if (k == "by_creation_date") return tr("Creation date");
    if (k == "in_future") return tr("Future tasks last");
    if (k == "by_due_date") return tr("Due date");
    if (k == "by_threshold_date") return tr("Threshold date");
    if (k == "by_completion_date") return tr("Completion date");
    return k;
}

QStringList Query::effectiveSorts() const
{
    QStringList r;
    foreach (const QString &s, m_sorts)
        if (!s.isEmpty())
            r << (s.contains('!') ? s : "+!" + s);
    if (r.isEmpty())
        return defaultSorts();
    return r;
}

bool Query::manualSort() const
{
    // Manual order only matters when it is applied before the alphabetical key
    // (after it there are practically no ties left to order by hand).
    int m = manualSortIndex();
    if (m < 0)
        return false;
    QStringList s = effectiveSorts();
    for (int i = 0; i < m; ++i)
        if (s[i].section('!', 1) == "alphabetical")
            return false;
    return true;
}

int Query::manualSortIndex() const
{
    QStringList s = effectiveSorts();
    for (int i = 0; i < s.size(); ++i)
        if (s[i].section('!', 1) == "manual")
            return i;
    return -1;
}

bool Query::hasFilter() const
{
    return !m_contexts.isEmpty() || !m_projects.isEmpty() || !m_priorities.isEmpty()
        || !m_search.trimmed().isEmpty();
}

QString Query::summary() const
{
    QStringList parts;
    if (!m_priorities.isEmpty())
        parts << (m_prioritiesNot ? "!" : "") + m_priorities.join(",");
    foreach (const QString &c, m_contexts)
        parts << (m_contextsNot ? "!@" : "@") + c;
    foreach (const QString &p, m_projects)
        parts << (m_projectsNot ? "!+" : "+") + p;
    if (!m_search.trimmed().isEmpty())
        parts << "\"" + m_search.trimmed() + "\"";
    return parts.join(" ");
}

QString Query::proposedName() const
{
    QStringList applied;
    foreach (const QString &c, m_contexts)
        if (c != "-") applied << c;
    applied << m_priorities;
    foreach (const QString &p, m_projects)
        if (p != "-") applied << p;
    return applied.size() == 1 ? applied.first() : QString();
}

QString Query::prefill() const
{
    QStringList parts;
    if (!m_prioritiesNot && m_priorities.size() == 1 && m_priorities.first() != "-")
        parts << "(" + m_priorities.first() + ")";
    if (!m_contextsNot && m_contexts.size() == 1 && m_contexts.first() != "-")
        parts << "@" + m_contexts.first();
    if (!m_projectsNot && m_projects.size() == 1 && m_projects.first() != "-")
        parts << "+" + m_projects.first();
    return parts.join(" ");
}

static QStringList toStringList(const QJsonValue &v)
{
    QStringList r;
    foreach (const QJsonValue &x, v.toArray())
        r << x.toString();
    return r;
}

QString Query::toJson() const
{
    QJsonObject o;
    o["contexts"] = QJsonArray::fromStringList(m_contexts);
    o["projects"] = QJsonArray::fromStringList(m_projects);
    o["priorities"] = QJsonArray::fromStringList(m_priorities);
    o["contextsNot"] = m_contextsNot;
    o["projectsNot"] = m_projectsNot;
    o["prioritiesNot"] = m_prioritiesNot;
    o["hideCompleted"] = m_hideCompleted;
    o["hideFuture"] = m_hideFuture;
    o["hideHidden"] = m_hideHidden;
    o["hideLists"] = m_hideLists;
    o["hideTags"] = m_hideTags;
    o["createIsThreshold"] = m_createIsThreshold;
    o["search"] = m_search;
    o["sorts"] = QJsonArray::fromStringList(m_sorts);
    o["name"] = m_name;
    return QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact));
}

void Query::fromJson(const QString &json)
{
    QJsonObject o = QJsonDocument::fromJson(json.toUtf8()).object();
    m_contexts = toStringList(o["contexts"]);
    m_projects = toStringList(o["projects"]);
    m_priorities = toStringList(o["priorities"]);
    m_contextsNot = o["contextsNot"].toBool(false);
    m_projectsNot = o["projectsNot"].toBool(false);
    m_prioritiesNot = o["prioritiesNot"].toBool(false);
    m_hideCompleted = o["hideCompleted"].toBool(false);
    m_hideFuture = o["hideFuture"].toBool(false);
    m_hideHidden = o["hideHidden"].toBool(true);
    m_hideLists = o["hideLists"].toBool(false);
    m_hideTags = o["hideTags"].toBool(false);
    m_createIsThreshold = o["createIsThreshold"].toBool(false);
    m_search = o["search"].toString();
    m_sorts = toStringList(o["sorts"]);
    m_name = o["name"].toString();
    emit changed();
}

void Query::clear()
{
    m_contexts.clear();
    m_projects.clear();
    m_priorities.clear();
    m_contextsNot = m_projectsNot = m_prioritiesNot = false;
    m_search.clear();
    m_name.clear();
    emit changed();
}

void Query::clearContexts()
{
    setContexts(QStringList());
    setContextsNot(false);
}

void Query::clearProjects()
{
    setProjects(QStringList());
    setProjectsNot(false);
}

void Query::clearPriorities()
{
    setPriorities(QStringList());
    setPrioritiesNot(false);
}

static void toggle(QStringList &list, const QString &v, bool on)
{
    if (on && !list.contains(v))
        list << v;
    else if (!on)
        list.removeAll(v);
}

void Query::toggleContext(const QString &c, bool on)
{
    QStringList l = m_contexts;
    toggle(l, c, on);
    setContexts(l);
}

void Query::toggleProject(const QString &p, bool on)
{
    QStringList l = m_projects;
    toggle(l, p, on);
    setProjects(l);
}

void Query::togglePriority(const QString &p, bool on)
{
    QStringList l = m_priorities;
    toggle(l, p, on);
    setPriorities(l);
}

void Query::setSortDirection(int index, bool reversed)
{
    QStringList s = effectiveSorts();
    if (index < 0 || index >= s.size())
        return;
    s[index] = (reversed ? "-!" : "+!") + s[index].section('!', 1);
    setSorts(s);
}

void Query::moveSort(int from, int to)
{
    QStringList s = effectiveSorts();
    if (from < 0 || from >= s.size() || to < 0 || to >= s.size() || from == to)
        return;
    s.move(from, to);
    setSorts(s);
}

bool Query::matches(const Task &t, const QString &today) const
{
    if (m_hideCompleted && t.isCompleted())
        return false;
    if (m_hideFuture && t.inFuture(today, m_createIsThreshold))
        return false;
    if (m_hideHidden && t.isHidden())
        return false;
    if (t.isEmpty())
        return false;

    if (!m_priorities.isEmpty()) {
        bool found = m_priorities.contains(QString(t.priority()));
        if (found == m_prioritiesNot)
            return false;
    }
    if (!m_contexts.isEmpty()) {
        QStringList lists = t.lists();
        bool found = false;
        if (lists.isEmpty() && m_contexts.contains("-"))
            found = true;
        foreach (const QString &l, lists)
            if (m_contexts.contains(l)) { found = true; break; }
        if (found == m_contextsNot)
            return false;
    }
    if (!m_projects.isEmpty()) {
        QStringList tags = t.tags();
        bool found = false;
        if (tags.isEmpty() && m_projects.contains("-"))
            found = true;
        foreach (const QString &p, tags)
            if (m_projects.contains(p)) { found = true; break; }
        if (found == m_projectsNot)
            return false;
    }
    QString search = m_search.trimmed();
    if (!search.isEmpty()) {
        QString text = t.text().toUpper();
        foreach (const QString &part, search.toUpper().split(QRegularExpression("\\s+"))) {
            if (!part.isEmpty() && !text.contains(part))
                return false;
        }
    }
    return true;
}

static QString prioSortValue(QChar p)
{
    // A..Z sort before none
    return p == '-' ? QString("~") : QString(p);
}

QString Query::sortValue(const Task &t, const QString &key) const
{
    if (key == "completed")
        return t.isCompleted() ? "1" : "0";
    if (key == "by_context") {
        QStringList l = t.lists();
        QString v = l.isEmpty() ? QString() : l.first();
        return m_caseSensitive ? v : v.toLower();
    }
    if (key == "by_project") {
        QStringList l = t.tags();
        QString v = l.isEmpty() ? QString() : l.first();
        return m_caseSensitive ? v : v.toLower();
    }
    if (key == "alphabetical")
        return m_caseSensitive ? t.alphaParts() : t.alphaParts().toLower();
    if (key == "by_prio")
        return prioSortValue(t.priority());
    if (key == "by_creation_date")
        return t.createDate().isEmpty() ? LAST_DATE : t.createDate();
    if (key == "in_future")
        return t.inFuture(Task::today(), m_createIsThreshold) ? "1" : "0";
    if (key == "by_due_date")
        return t.dueDate().isEmpty() ? LAST_DATE : t.dueDate();
    if (key == "by_threshold_date") {
        if (!t.thresholdDate().isEmpty())
            return t.thresholdDate();
        if (m_createIsThreshold && !t.createDate().isEmpty())
            return t.createDate();
        return LAST_DATE;
    }
    if (key == "by_completion_date")
        return t.completionDate().isEmpty() ? LAST_DATE : t.completionDate();
    if (key == "manual") {
        int o = t.manualOrder();
        // tasks without #N sort after numbered ones
        return o < 0 ? QString("~") : QString("%1").arg(o, 12, 10, QChar('0'));
    }
    return QString();
}

int Query::compare(const Task &a, const Task &b, int keyCount) const
{
    QStringList s = effectiveSorts();
    int n = keyCount < 0 ? s.size() : qMin(keyCount, s.size());
    for (int i = 0; i < n; ++i) {
        bool reversed = s[i].startsWith("-!");
        QString key = s[i].section('!', 1);
        QString va = sortValue(a, key);
        QString vb = sortValue(b, key);
        int c = QString::compare(va, vb);
        if (c != 0)
            return reversed ? -c : c;
    }
    return 0;
}

QString Query::sectionKey() const
{
    QStringList s = effectiveSorts();
    for (int i = 0; i < s.size() && i < 3; ++i) {
        QString k = s[i].section('!', 1);
        if (k != "completed" && k != "in_future")
            return k;
    }
    return QString();
}

QString Query::section(const Task &t, const QString &empty) const
{
    QString key = sectionKey();
    if (key == "by_context") {
        QStringList l = t.lists();
        return l.isEmpty() ? empty : l.first();
    }
    if (key == "by_project") {
        QStringList l = t.tags();
        return l.isEmpty() ? empty : l.first();
    }
    if (key == "by_threshold_date") {
        if (!t.thresholdDate().isEmpty()) return t.thresholdDate();
        if (m_createIsThreshold && !t.createDate().isEmpty()) return t.createDate();
        return empty;
    }
    if (key == "by_prio")
        return QString(t.priority());
    if (key == "by_due_date")
        return t.dueDate().isEmpty() ? empty : t.dueDate();
    return QString();
}
