#ifndef TASK_H
#define TASK_H

#include <QString>
#include <QStringList>
#include <QList>
#include <QDate>

// Port of Simpletask's Task.kt: lossless tokenizer for todo.txt lines.

enum class TokenType {
    Completed,      // "x"
    CompletedDate,
    CreateDate,
    Priority,       // "(A)"
    List,           // "@context"
    Tag,            // "+project"
    Hidden,         // h:1
    Order,          // #N (manual order, this port's extension)
    Phone,
    Due,            // due:YYYY-MM-DD
    Threshold,      // t:YYYY-MM-DD
    Recurrence,     // rec:[+]Nd
    Uuid,
    Link,
    Mail,
    Ext,            // key:value
    WhiteSpace,
    Text
};

struct Token {
    TokenType type;
    QString text;   // exact text as written in the file
    QString key;    // for key:value tokens
    QString value;  // parsed value (without prefix) where applicable

    bool isAlpha() const {
        return type == TokenType::Text || type == TokenType::WhiteSpace
            || type == TokenType::Mail || type == TokenType::Link
            || type == TokenType::Phone;
    }
    bool isKeyValue() const {
        return type == TokenType::Due || type == TokenType::Threshold
            || type == TokenType::Recurrence || type == TokenType::Hidden
            || type == TokenType::Uuid || type == TokenType::Ext;
    }
};

class Task
{
public:
    Task();
    explicit Task(const QString &text, const QString &defaultCreateDate = QString());

    int id() const { return m_id; }

    void update(const QString &text);
    QString text() const;

    const QList<Token> &tokens() const { return m_tokens; }

    bool isCompleted() const;
    bool isHidden() const;
    bool isEmpty() const;
    bool inFuture(const QString &today, bool createIsThreshold) const;

    QString completionDate() const;
    QString createDate() const;
    void setCreateDate(const QString &date);
    QString dueDate() const;
    void setDueDate(const QString &date);
    QString thresholdDate() const;
    void setThresholdDate(const QString &date);
    QString recurrence() const;
    // Occurrences of a recurring task that are marked done (done:YYYY-MM-DD).
    QStringList doneDates() const;
    void addDoneDate(const QString &date);
    void removeDoneDate(const QString &date);
    // True when the task is a recurring series anchored on a due date.
    bool isSeries() const;
    QString uuid() const;

    // Priority code: 'A'..'Z' or '-' for none
    QChar priority() const;
    void setPriority(QChar code);

    // Manual order (#N). -1 when absent.
    int manualOrder() const;
    void setManualOrder(int order);
    void clearManualOrder();

    QStringList lists() const;   // sorted, unique
    QStringList tags() const;    // sorted, unique
    QStringList links() const;
    QStringList phones() const;
    QStringList mails() const;

    void addList(const QString &names);
    void addTag(const QString &names);
    void removeList(const QString &name);
    void removeTag(const QString &name);

    // Marks the task completed. If the task recurs, *newTask receives the
    // next occurrence and true is returned.
    bool markComplete(const QString &date, Task *newTask);
    void markIncomplete();

    // deferString: "" removes, "YYYY-MM-DD" sets, "Nd/w/m/y/b" adds interval.
    // fromDate: empty = relative to current date value (or today if none).
    void deferDueDate(const QString &deferString, const QString &fromDate);
    void deferThresholdDate(const QString &deferString, const QString &fromDate);

    QString alphaParts() const;
    QString showParts(bool hideLists, bool hideTags, bool hideDates) const;

    static QDate addInterval(const QDate &date, const QString &interval);
    static bool isDate(const QString &s);
    static QString today();

    static QList<Token> parse(const QString &text);

private:
    const Token *firstToken(TokenType type) const;
    void upsertToken(const Token &t);
    void removeTokens(TokenType type);
    void appendToken(const Token &t);
    QString deferDate(const QString &deferString, const QString &fromDate) const;

    int m_id;
    QList<Token> m_tokens;
    static int s_nextId;
};

#endif // TASK_H
