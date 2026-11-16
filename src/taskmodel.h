#ifndef TASKMODEL_H
#define TASKMODEL_H

#include <QAbstractListModel>
#include <QSet>
#include <QTimer>
#include <QVariantList>

class TodoStore;
class Query;
class Settings;
class Task;

// Visible (filtered + sorted) view of the TodoStore for one Query.
class TaskModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY countChanged)
    Q_PROPERTY(int selectedCount READ selectedCount NOTIFY selectionChanged)
    Q_PROPERTY(int overdueCount READ overdueCount NOTIFY countChanged)
    Q_PROPERTY(int dueTodayCount READ dueTodayCount NOTIFY countChanged)
    Q_PROPERTY(bool showSelected READ showSelected WRITE setShowSelected NOTIFY showSelectedChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        TextRole,
        DisplayRole,
        PriorityRole,
        CompletedRole,
        DueRole,
        ThresholdRole,
        CreateDateRole,
        CompletionDateRole,
        ListsRole,
        TagsRole,
        LinksRole,
        PhonesRole,
        MailsRole,
        SectionRole,
        SelectedRole,
        HiddenRole,
        InFutureRole,
        AgeRole,
        DueStateRole,      // 0 none, 1 overdue, 2 today, 3 tomorrow, 4 later
        ThresholdStateRole,
        RecurrenceRole,
        OrderRole
    };

    TaskModel(TodoStore *store, Query *query, Settings *settings, QObject *parent = 0);

    int rowCount(const QModelIndex &parent = QModelIndex()) const;
    QVariant data(const QModelIndex &index, int role) const;
    QHash<int, QByteArray> roleNames() const;

    int count() const { return m_rows.size(); }
    int totalCount() const;
    int selectedCount() const { return m_selected.size(); }
    int overdueCount() const { return m_overdue; }
    int dueTodayCount() const { return m_dueToday; }
    bool showSelected() const { return m_showSelected; }
    void setShowSelected(bool s);

    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE int indexOfId(int id) const;
    Q_INVOKABLE void refresh();

    // Selection
    Q_INVOKABLE void toggleSelected(int id);
    Q_INVOKABLE void setSelected(int id, bool on);
    Q_INVOKABLE bool isSelected(int id) const { return m_selected.contains(id); }
    Q_INVOKABLE void selectAll();
    Q_INVOKABLE void clearSelection();
    Q_INVOKABLE QVariantList selectedIds() const;
    Q_INVOKABLE QVariantList completedVisibleIds() const;

    // Lists/tags state of a set of tasks: 0 none, 1 some, 2 all
    Q_INVOKABLE int listState(const QVariantList &ids, const QString &name) const;
    Q_INVOKABLE int tagState(const QVariantList &ids, const QString &name) const;

    // Manual order (#N) drag support
    Q_INVOKABLE bool canMove(int from, int to) const;
    Q_INVOKABLE bool previewMove(int from, int to);  // reorders rows only
    Q_INVOKABLE void commitMove(int row);            // renumbers #N around row

    Q_INVOKABLE static QString relativeDate(const QString &date);
    Q_INVOKABLE static QString today();

signals:
    void countChanged();
    void selectionChanged();
    void showSelectedChanged();

private slots:
    void scheduleRebuild();
    void rebuild();

private:
    const Task *taskAt(int row) const;
    QString displayHtml(const Task &t) const;
    int dateState(const QString &date) const;

    TodoStore *m_store;
    Query *m_query;
    Settings *m_settings;
    QList<int> m_rows;          // task ids in visible order
    QSet<int> m_selected;
    QTimer m_rebuildTimer;
    QString m_today;
    int m_overdue;
    int m_dueToday;
    bool m_showSelected;
    bool m_moving;
};

#endif // TASKMODEL_H
