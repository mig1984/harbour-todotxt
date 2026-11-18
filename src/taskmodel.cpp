#include "taskmodel.h"
#include "todostore.h"
#include "query.h"
#include "settings.h"
#include "rowdiff.h"

#include <QDate>
#include <QVariantMap>
#include <algorithm>

TaskModel::TaskModel(TodoStore *store, Query *query, Settings *settings, QObject *parent)
    : QAbstractListModel(parent)
    , m_store(store), m_query(query), m_settings(settings)
    , m_overdue(0), m_dueToday(0), m_pending(0), m_completed(0)
    , m_showSelected(true), m_moving(false), m_preserveScroll(false)
{
    m_rebuildTimer.setSingleShot(true);
    m_rebuildTimer.setInterval(0);
    connect(&m_rebuildTimer, SIGNAL(timeout()), this, SLOT(rebuild()));
    // A data change (complete, edit, delete, move, reload) keeps the view's
    // scroll position; a filter/sort change starts again at the top.
    connect(m_store, SIGNAL(tasksChanged()), this, SLOT(scheduleRebuildPreserve()));
    connect(m_query, SIGNAL(changed()), this, SLOT(scheduleRebuildReset()));
    connect(m_settings, SIGNAL(showDateBarChanged()), this, SLOT(scheduleRebuildReset()));
    connect(m_settings, SIGNAL(caseSensitiveSortChanged()), this, SLOT(scheduleRebuildReset()));
    m_today = Task::today();
}

QHash<int, QByteArray> TaskModel::roleNames() const
{
    QHash<int, QByteArray> r;
    r[IdRole] = "taskId";
    r[TextRole] = "text";
    r[DisplayRole] = "display";
    r[PriorityRole] = "priority";
    r[CompletedRole] = "completed";
    r[DueRole] = "due";
    r[ThresholdRole] = "threshold";
    r[CreateDateRole] = "createDate";
    r[CompletionDateRole] = "completionDate";
    r[ListsRole] = "lists";
    r[TagsRole] = "tags";
    r[LinksRole] = "links";
    r[PhonesRole] = "phones";
    r[MailsRole] = "mails";
    r[SectionRole] = "section";
    r[SelectedRole] = "isSelected";
    r[HiddenRole] = "hidden";
    r[InFutureRole] = "inFuture";
    r[AgeRole] = "age";
    r[RecurrenceRole] = "recurrence";
    r[OrderRole] = "order";
    return r;
}

int TaskModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

int TaskModel::totalCount() const
{
    return m_store->count();
}

const Task *TaskModel::taskAt(int row) const
{
    if (row < 0 || row >= m_rows.size())
        return 0;
    return m_store->findTask(m_rows[row]);
}

int TaskModel::dateState(const QString &date) const
{
    if (date.isEmpty())
        return 0;
    if (date < m_today)
        return 1;
    if (date == m_today)
        return 2;
    if (date == QDate::fromString(m_today, "yyyy-MM-dd").addDays(1).toString("yyyy-MM-dd"))
        return 3;
    return 4;
}

QString TaskModel::displayHtml(const Task &t) const
{
    const bool hideDates = m_settings->showDateBar();
    QStringList parts;
    foreach (const Token &tok, t.tokens()) {
        switch (tok.type) {
        case TokenType::Completed:
        case TokenType::CompletedDate:
        case TokenType::CreateDate:
        case TokenType::Uuid:
        case TokenType::Order:
        case TokenType::Priority:
            continue;
        case TokenType::List:
            if (m_query->hideLists()) continue;
            parts << "<font color=\"#SEC#\">" + tok.text.toHtmlEscaped() + "</font>";
            continue;
        case TokenType::Tag:
            if (m_query->hideTags()) continue;
            parts << "<font color=\"#SEC#\">" + tok.text.toHtmlEscaped() + "</font>";
            continue;
        case TokenType::Due:
        case TokenType::Threshold:
        case TokenType::Recurrence:
            if (hideDates) continue;
            parts << "<font color=\"#SEC#\">" + tok.text.toHtmlEscaped() + "</font>";
            continue;
        case TokenType::Link:
            parts << "<font color=\"#LINK#\">" + tok.text.toHtmlEscaped() + "</font>";
            continue;
        default:
            parts << tok.text.toHtmlEscaped();
        }
    }
    return parts.join(" ").trimmed();
}

QVariant TaskModel::data(const QModelIndex &index, int role) const
{
    const Task *t = taskAt(index.row());
    if (!t)
        return QVariant();
    switch (role) {
    case IdRole: return t->id();
    case TextRole: return t->text();
    case DisplayRole: return displayHtml(*t);
    case PriorityRole: return QString(t->priority());
    case CompletedRole: return t->isCompleted();
    case DueRole: return t->dueDate();
    case ThresholdRole: return t->thresholdDate();
    case CreateDateRole: return t->createDate();
    case CompletionDateRole: return t->completionDate();
    case ListsRole: return t->lists();
    case TagsRole: return t->tags();
    case LinksRole: return t->links();
    case PhonesRole: return t->phones();
    case MailsRole: return t->mails();
    case SectionRole: return m_query->section(*t, tr("None"));
    case SelectedRole: return m_selected.contains(t->id());
    case HiddenRole: return t->isHidden();
    case InFutureRole: return t->inFuture(m_today, m_query->createIsThreshold());
    case AgeRole: return t->createDate().isEmpty() ? QString() : relativeDate(t->createDate());
    case RecurrenceRole: return t->recurrence();
    case OrderRole: return t->manualOrder();
    }
    return QVariant();
}

QVariantMap TaskModel::get(int row) const
{
    QVariantMap m;
    QModelIndex idx = index(row);
    QHash<int, QByteArray> names = roleNames();
    for (QHash<int, QByteArray>::const_iterator it = names.begin(); it != names.end(); ++it)
        m[QString::fromLatin1(it.value())] = data(idx, it.key());
    return m;
}

int TaskModel::indexOfId(int id) const
{
    return m_rows.indexOf(id);
}

void TaskModel::refresh()
{
    m_preserveScroll = true;
    scheduleRebuild();
}

QStringList TaskModel::dueDates() const
{
    QSet<QString> seen;
    QStringList out;
    for (int i = 0; i < m_rows.size(); ++i) {
        const Task *t = m_store->findTask(m_rows[i]);
        if (!t || t->dueDate().isEmpty() || seen.contains(t->dueDate()))
            continue;
        seen.insert(t->dueDate());
        out << t->dueDate();
    }
    out.sort();
    return out;
}

int TaskModel::rowForDueDate(const QString &date) const
{
    int completedRow = -1;
    for (int i = 0; i < m_rows.size(); ++i) {
        const Task *t = m_store->findTask(m_rows[i]);
        if (!t || t->dueDate() != date)
            continue;
        if (!t->isCompleted())
            return i;
        if (completedRow < 0)
            completedRow = i;
    }
    return completedRow;
}

void TaskModel::setShowSelected(bool s)
{
    if (m_showSelected == s)
        return;
    m_showSelected = s;
    emit showSelectedChanged();
    m_preserveScroll = true;
    scheduleRebuild();
}

void TaskModel::scheduleRebuild()
{
    if (m_moving)
        return;
    m_rebuildTimer.start();
}

void TaskModel::scheduleRebuildPreserve()
{
    m_preserveScroll = true;
    scheduleRebuild();
}

void TaskModel::scheduleRebuildReset()
{
    m_preserveScroll = false;
    scheduleRebuild();
}

void TaskModel::rebuild()
{
    if (m_moving)
        return;
    m_today = Task::today();
    m_query->setCaseSensitive(m_settings->caseSensitiveSort());

    QList<const Task *> visible;
    const QList<Task> &all = m_store->tasks();
    QSet<int> existing;
    int completed = 0;
    for (int i = 0; i < all.size(); ++i) {
        const Task &t = all[i];
        existing.insert(t.id());
        if (t.isCompleted())
            completed++;
        if ((m_showSelected && m_selected.contains(t.id())) || m_query->matches(t, m_today))
            visible << &t;
    }
    // Forget selection of tasks that no longer exist.
    QSet<int> sel;
    foreach (int id, m_selected)
        if (existing.contains(id))
            sel.insert(id);
    bool selChanged = sel.size() != m_selected.size();
    m_selected = sel;

    Query *q = m_query;
    std::stable_sort(visible.begin(), visible.end(), [q](const Task *a, const Task *b) {
        return q->compare(*a, *b) < 0;
    });

    QList<int> rows;
    int overdue = 0, dueToday = 0, pending = 0;
    foreach (const Task *t, visible) {
        rows << t->id();
        if (!t->isCompleted()) {
            pending++;
            int s = dateState(t->dueDate());
            if (s == 1) overdue++;
            else if (s == 2) dueToday++;
        }
    }
    m_overdue = overdue;
    m_dueToday = dueToday;
    m_pending = pending;
    m_completed = completed;

    // A filter/sort change starts a fresh view (scroll back to the top); a data
    // change keeps the current position and is applied incrementally.
    if (m_preserveScroll)
        applyRowDiff(rows);
    else
        fullReset(rows, false);
    emit countChanged();
    if (selChanged)
        emit selectionChanged();
}

void TaskModel::fullReset(const QList<int> &rows, bool preserveScroll)
{
    if (preserveScroll)
        emit rebuildResetPreserving();
    else
        emit rebuildResetTop();
    beginResetModel();
    m_rows = rows;
    endResetModel();
    if (preserveScroll)
        emit rebuildResetPreservingFinished();
    else
        emit rebuildResetTopFinished();
}

// Change m_rows to `rows` with granular insert/remove/move operations, so the
// view keeps its delegates (and any running undo bars) instead of tearing them
// all down. Falls back to a full reset when the change is too large.
void TaskModel::applyRowDiff(const QList<int> &rows)
{
    if (rows == m_rows) {
        if (!m_rows.isEmpty())
            emit dataChanged(index(0), index(m_rows.size() - 1));
        return;
    }
    if (m_rows.isEmpty()) {
        beginInsertRows(QModelIndex(), 0, rows.size() - 1);
        m_rows = rows;
        endInsertRows();
        return;
    }
    if (rows.isEmpty()) {
        beginRemoveRows(QModelIndex(), 0, m_rows.size() - 1);
        m_rows.clear();
        endRemoveRows();
        return;
    }

    const QList<RowDiff::Op> ops = RowDiff::compute(m_rows, rows);

    // A huge change (e.g. a full file reload) is smoother as a single reset.
    const int maxOps = 24;
    if (ops.size() > maxOps) {
        fullReset(rows, m_preserveScroll);
        return;
    }

    foreach (const RowDiff::Op &op, ops) {
        switch (op.kind) {
        case RowDiff::Op::Remove:
            beginRemoveRows(QModelIndex(), op.from, op.from);
            m_rows.removeAt(op.from);
            endRemoveRows();
            break;
        case RowDiff::Op::Insert:
            beginInsertRows(QModelIndex(), op.to, op.to);
            m_rows.insert(op.to, op.id);
            endInsertRows();
            break;
        case RowDiff::Op::Move: {
            int dest = op.to > op.from ? op.to + 1 : op.to;
            beginMoveRows(QModelIndex(), op.from, op.from, QModelIndex(), dest);
            m_rows.move(op.from, op.to);
            endMoveRows();
            break;
        }
        }
    }

    emit dataChanged(index(0), index(m_rows.size() - 1));
}

void TaskModel::toggleSelected(int id)
{
    setSelected(id, !m_selected.contains(id));
}

void TaskModel::setSelected(int id, bool on)
{
    if (on == m_selected.contains(id))
        return;
    if (on)
        m_selected.insert(id);
    else
        m_selected.remove(id);
    int row = m_rows.indexOf(id);
    if (row >= 0)
        emit dataChanged(index(row), index(row), QVector<int>() << SelectedRole);
    emit selectionChanged();
}

void TaskModel::selectAll()
{
    foreach (int id, m_rows)
        m_selected.insert(id);
    if (!m_rows.isEmpty())
        emit dataChanged(index(0), index(m_rows.size() - 1), QVector<int>() << SelectedRole);
    emit selectionChanged();
}

void TaskModel::clearSelection()
{
    if (m_selected.isEmpty())
        return;
    m_selected.clear();
    emit selectionChanged();
    // selected-but-filtered tasks may disappear now
    m_preserveScroll = true;
    scheduleRebuild();
    if (!m_rows.isEmpty())
        emit dataChanged(index(0), index(m_rows.size() - 1), QVector<int>() << SelectedRole);
}

QVariantList TaskModel::selectedIds() const
{
    QVariantList r;
    foreach (int id, m_rows)
        if (m_selected.contains(id))
            r << id;
    return r;
}

static QString coverPriorityRank(QChar p)
{
    return p == '-' ? QString("~") : QString(p);
}

QVariantList TaskModel::coverTasks() const
{
    const int maxItems = 8;
    const QString dayAfter = QDate::fromString(m_today, "yyyy-MM-dd").addDays(2)
                                 .toString("yyyy-MM-dd");

    QList<const Task *> soon, rest;
    for (int i = 0; i < m_rows.size(); ++i) {
        const Task *t = m_store->findTask(m_rows[i]);
        if (!t || t->isCompleted())
            continue;
        const QString due = t->dueDate();
        if (!due.isEmpty() && due <= dayAfter)
            soon << t;
        else
            rest << t;
    }
    std::stable_sort(soon.begin(), soon.end(), [](const Task *a, const Task *b) {
        if (a->dueDate() != b->dueDate())
            return a->dueDate() < b->dueDate();
        return coverPriorityRank(a->priority()) < coverPriorityRank(b->priority());
    });

    QVariantList out;
    foreach (const Task *t, soon) {
        if (out.size() >= maxItems) break;
        QVariantMap m;
        m["text"] = displayHtml(*t);
        m["priority"] = QString(t->priority());
        m["due"] = t->dueDate();
        m["completed"] = t->isCompleted();
        out << m;
    }
    foreach (const Task *t, rest) {
        if (out.size() >= maxItems) break;
        QVariantMap m;
        m["text"] = displayHtml(*t);
        m["priority"] = QString(t->priority());
        m["due"] = t->dueDate();
        m["completed"] = t->isCompleted();
        out << m;
    }
    return out;
}

QVariantList TaskModel::completedVisibleIds() const
{
    QVariantList r;
    foreach (int id, m_rows) {
        const Task *t = m_store->findTask(id);
        if (t && t->isCompleted())
            r << id;
    }
    return r;
}

QVariantList TaskModel::allCompletedIds() const
{
    QVariantList r;
    const QList<Task> &all = m_store->tasks();
    for (int i = 0; i < all.size(); ++i)
        if (all[i].isCompleted())
            r << all[i].id();
    return r;
}

static int stateOf(int have, int total)
{
    if (total == 0 || have == 0)
        return 0;
    return have == total ? 2 : 1;
}

int TaskModel::listState(const QVariantList &ids, const QString &name) const
{
    int have = 0;
    foreach (const QVariant &v, ids) {
        const Task *t = m_store->findTask(v.toInt());
        if (t && t->lists().contains(name))
            have++;
    }
    return stateOf(have, ids.size());
}

int TaskModel::tagState(const QVariantList &ids, const QString &name) const
{
    int have = 0;
    foreach (const QVariant &v, ids) {
        const Task *t = m_store->findTask(v.toInt());
        if (t && t->tags().contains(name))
            have++;
    }
    return stateOf(have, ids.size());
}

bool TaskModel::canMove(int from, int to) const
{
    if (from == to)
        return true;
    int m = m_query->manualSort() ? m_query->manualSortIndex() : -1;
    if (m < 0 || from < 0 || to < 0 || from >= m_rows.size() || to >= m_rows.size())
        return false;
    QList<int> rows = m_rows;
    rows.move(from, to);
    const Task *moved = m_store->findTask(rows[to]);
    if (!moved)
        return false;
    if (to > 0) {
        const Task *prev = m_store->findTask(rows[to - 1]);
        if (prev && m_query->compare(*prev, *moved, m) > 0)
            return false;
    }
    if (to + 1 < rows.size()) {
        const Task *next = m_store->findTask(rows[to + 1]);
        if (next && m_query->compare(*moved, *next, m) > 0)
            return false;
    }
    return true;
}

bool TaskModel::previewMove(int from, int to)
{
    if (from == to)
        return true;
    if (!canMove(from, to))
        return false;
    m_moving = true;
    int dest = to > from ? to + 1 : to;
    if (!beginMoveRows(QModelIndex(), from, from, QModelIndex(), dest))
        return false;
    m_rows.move(from, to);
    endMoveRows();
    return true;
}

void TaskModel::commitMove(int row)
{
    m_moving = false;
    int m = m_query->manualSort() ? m_query->manualSortIndex() : -1;
    const Task *moved = taskAt(row);
    if (m < 0 || !moved) {
        rebuild();
        return;
    }
    // Tie group: contiguous rows equal to the moved task on the keys before "manual".
    int start = row, end = row;
    while (start > 0) {
        const Task *p = taskAt(start - 1);
        if (!p || m_query->compare(*p, *moved, m) != 0)
            break;
        start--;
    }
    while (end + 1 < m_rows.size()) {
        const Task *n = taskAt(end + 1);
        if (!n || m_query->compare(*moved, *n, m) != 0)
            break;
        end++;
    }
    // Number everything up to the last numbered task (or the moved one).
    int last = row;
    for (int i = end; i > row; --i) {
        const Task *t = taskAt(i);
        if (t && t->manualOrder() >= 0) {
            last = i;
            break;
        }
    }
    int counter = 1024;
    for (int i = start; i <= last; ++i) {
        Task *t = m_store->findTask(m_rows[i]);
        if (t && !t->isCompleted()) {
            t->setManualOrder(counter);
            counter += 1024;
        }
    }
    m_store->notifyChanged();
}

void TaskModel::moveToDue(int row, int targetRow)
{
    if (row < 0 || targetRow < 0 || row >= m_rows.size() || targetRow >= m_rows.size())
        return;
    Task *moved = m_store->findTask(m_rows[row]);
    const Task *target = taskAt(targetRow);
    if (!moved || !target || moved->id() == target->id())
        return;
    const QString due = target->dueDate();
    if (moved->dueDate() == due)
        return;

    const int targetId = target->id();
    moved->setDueDate(due);
    m_store->notifyChanged();

    // Rebuild so the moved task is grouped under its new due date, then place
    // it at the row where it was dropped (commitMove renumbers #N there).
    m_moving = false;
    rebuild();
    int mIdx = m_rows.indexOf(moved->id());
    int tIdx = m_rows.indexOf(targetId);
    if (mIdx < 0 || tIdx < 0 || mIdx == tIdx)
        return;
    if (previewMove(mIdx, tIdx))
        commitMove(tIdx);
}

QString TaskModel::dueAt(int row) const
{
    const Task *t = taskAt(row);
    return t ? t->dueDate() : QString();
}

QString TaskModel::today()
{
    return Task::today();
}

QString TaskModel::relativeDate(const QString &date)
{
    QDate d = QDate::fromString(date, "yyyy-MM-dd");
    if (!d.isValid())
        return date;
    qint64 days = QDate::currentDate().daysTo(d);
    if (days == 0)
        return tr("today");
    if (days == 1)
        return tr("tomorrow");
    if (days == -1)
        return tr("yesterday");
    qint64 a = days < 0 ? -days : days;
    QString unit;
    if (a < 14)
        unit = tr("%1 days").arg(a);
    else if (a < 60)
        unit = a / 7 == 1 ? tr("1 week") : tr("%1 weeks").arg(a / 7);
    else if (a < 730)
        unit = a / 30 == 1 ? tr("1 month") : tr("%1 months").arg(a / 30);
    else
        unit = a / 365 == 1 ? tr("1 year") : tr("%1 years").arg(a / 365);
    return days < 0 ? tr("%1 ago").arg(unit) : tr("in %1").arg(unit);
}
