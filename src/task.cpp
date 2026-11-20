#include "task.h"

#include <QRegularExpression>
#include <QSet>
#include <algorithm>

int Task::s_nextId = 1;

namespace {

bool reMatch(const QString &pattern, const QString &s, QStringList *caps = 0)
{
    QRegularExpression re(QStringLiteral("\\A(?:") + pattern + QStringLiteral(")\\z"));
    QRegularExpressionMatch m = re.match(s);
    if (!m.hasMatch())
        return false;
    if (caps)
        *caps = m.capturedTexts();
    return true;
}

const char *RE_DATE = "\\d{4}-\\d{2}-\\d{2}";
const char *RE_LIST = "@(\\S+)";
const char *RE_TAG = "\\+(\\S+)";
const char *RE_HIDDEN = "[Hh]:([01])";
const char *RE_ORDER = "#(\\d+)";
const char *RE_PHONE = "[+]?[0-9,#()-]{4,}";
const char *RE_DUE = "[Dd][Uu][Ee]:(\\d{4}-\\d{2}-\\d{2})";
const char *RE_THRESHOLD = "[Tt]:(\\d{4}-\\d{2}-\\d{2})";
const char *RE_REC = "[Rr][Ee][Cc]:((\\+?)\\d*[dDwWmMyYbB])";
const char *RE_UUID = "[Uu][Uu][Ii][Dd]:([A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12})";
const char *RE_URI = "[a-z]+://(\\S+)";
const char *RE_MAIL = "[a-zA-Z0-9\\+\\._%\\-]{1,256}@[a-zA-Z0-9][a-zA-Z0-9\\-]{0,64}(\\.[a-zA-Z0-9][a-zA-Z0-9\\-]{0,25})+";
const char *RE_EXT = "(.+):(.+)";
const char *RE_PRIO = "\\(([A-Z])\\)";

QStringList splitWords(const QString &s)
{
    QStringList out;
    foreach (const QString &w, s.split(QRegularExpression("\\s+")))
        if (!w.isEmpty())
            out << w;
    return out;
}

Token mk(TokenType type, const QString &text, const QString &key = QString(), const QString &value = QString())
{
    Token t;
    t.type = type;
    t.text = text;
    t.key = key;
    t.value = value;
    return t;
}

Token keyValue(TokenType type, const QString &key, const QString &value)
{
    return mk(type, key + ":" + value, key, value);
}

} // namespace

Task::Task() : m_id(s_nextId++)
{
}

Task::Task(const QString &text, const QString &defaultCreateDate)
    : m_id(s_nextId++)
{
    m_tokens = parse(text);
    if (!defaultCreateDate.isEmpty() && createDate().isEmpty())
        setCreateDate(defaultCreateDate);
}

void Task::update(const QString &text)
{
    m_tokens = parse(text);
}

QString Task::text() const
{
    QStringList parts;
    foreach (const Token &t, m_tokens)
        parts << t.text;
    return parts.join(" ");
}

bool Task::isDate(const QString &s)
{
    return reMatch(RE_DATE, s);
}

QString Task::today()
{
    return QDate::currentDate().toString("yyyy-MM-dd");
}

bool Task::hasTaskText(const QString &line)
{
    QString s = line;
    s.replace(QRegularExpression(QStringLiteral("^\\s*x\\s+"),
                                 QRegularExpression::CaseInsensitiveOption), QStringLiteral(" "));
    s.replace(QRegularExpression(QStringLiteral("(^|\\s)(due|t|thr|rec|h|uuid|pri):\\S+"),
                                 QRegularExpression::CaseInsensitiveOption), QStringLiteral(" "));
    s.replace(QRegularExpression(QStringLiteral("\\d{4}-\\d{2}-\\d{2}")), QStringLiteral(" "));
    s.replace(QRegularExpression(QStringLiteral("(^|\\s)\\(\\w\\)")), QStringLiteral(" "));
    s.replace(QRegularExpression(QStringLiteral("(^|\\s)[@+]\\S+")), QStringLiteral(" "));
    return !s.trimmed().isEmpty();
}

QList<Token> Task::parse(const QString &text)
{
    QList<Token> tokens;
    // Simpletask lexes on single spaces and unicode separators, keeping
    // empty lexemes so that the line round-trips exactly.
    QStringList lexemes = text.split(QRegularExpression("[ \\x{2000}-\\x{200A}\\x{00A0}\\x{1680}\\x{202F}\\x{205F}\\x{3000}\\x{2028}\\x{2029}]"));
    int i = 0;
    const int n = lexemes.size();

    if (n > 0 && lexemes[0] == "x") {
        tokens << mk(TokenType::Completed, "x");
        i = 1;
        if (i < n && isDate(lexemes[i])) {
            tokens << mk(TokenType::CompletedDate, lexemes[i], QString(), lexemes[i]);
            i++;
            if (i < n && isDate(lexemes[i])) {
                tokens << mk(TokenType::CreateDate, lexemes[i], QString(), lexemes[i]);
                i++;
            }
        }
    }
    QStringList caps;
    if (i < n && reMatch(RE_PRIO, lexemes[i], &caps)) {
        tokens << mk(TokenType::Priority, lexemes[i], QString(), caps[1]);
        i++;
    }
    if (i < n && isDate(lexemes[i])) {
        tokens << mk(TokenType::CreateDate, lexemes[i], QString(), lexemes[i]);
        i++;
    }
    for (; i < n; ++i) {
        const QString &lx = lexemes[i];
        if (reMatch(RE_LIST, lx, &caps)) {
            tokens << mk(TokenType::List, lx, QString(), caps[1]);
        } else if (reMatch(RE_TAG, lx, &caps)) {
            tokens << mk(TokenType::Tag, lx, QString(), caps[1]);
        } else if (reMatch(RE_HIDDEN, lx, &caps)) {
            tokens << mk(TokenType::Hidden, lx, "h", caps[1]);
        } else if (reMatch(RE_ORDER, lx, &caps)) {
            tokens << mk(TokenType::Order, lx, QString(), caps[1]);
        } else if (reMatch(RE_PHONE, lx)) {
            tokens << mk(TokenType::Phone, lx, QString(), lx);
        } else if (reMatch(RE_DUE, lx, &caps)) {
            tokens << mk(TokenType::Due, lx, "due", caps[1]);
        } else if (reMatch(RE_THRESHOLD, lx, &caps)) {
            tokens << mk(TokenType::Threshold, lx, "t", caps[1]);
        } else if (reMatch(RE_REC, lx, &caps)) {
            tokens << mk(TokenType::Recurrence, lx, "rec", caps[1]);
        } else if (reMatch(RE_UUID, lx, &caps)) {
            tokens << mk(TokenType::Uuid, lx, "uuid", caps[1]);
        } else if (reMatch(RE_URI, lx)) {
            tokens << mk(TokenType::Link, lx, QString(), lx);
        } else if (reMatch(RE_MAIL, lx)) {
            tokens << mk(TokenType::Mail, lx, QString(), lx);
        } else if (reMatch(RE_EXT, lx, &caps)) {
            tokens << mk(TokenType::Ext, lx, caps[1], caps[2]);
        } else if (lx.trimmed().isEmpty()) {
            tokens << mk(TokenType::WhiteSpace, lx, QString(), lx);
        } else {
            tokens << mk(TokenType::Text, lx, QString(), lx);
        }
    }
    return tokens;
}

const Token *Task::firstToken(TokenType type) const
{
    for (int i = 0; i < m_tokens.size(); ++i)
        if (m_tokens[i].type == type)
            return &m_tokens[i];
    return 0;
}

void Task::upsertToken(const Token &t)
{
    bool found = false;
    for (int i = 0; i < m_tokens.size(); ++i) {
        if (m_tokens[i].type == t.type) {
            m_tokens[i] = t;
            found = true;
        }
    }
    if (!found)
        m_tokens << t;
}

void Task::removeTokens(TokenType type)
{
    for (int i = m_tokens.size() - 1; i >= 0; --i)
        if (m_tokens[i].type == type)
            m_tokens.removeAt(i);
}

void Task::appendToken(const Token &t)
{
    while (!m_tokens.isEmpty() && m_tokens.last().type == TokenType::WhiteSpace)
        m_tokens.removeLast();
    m_tokens << t;
}

bool Task::isCompleted() const
{
    return firstToken(TokenType::Completed) != 0;
}

bool Task::isHidden() const
{
    const Token *t = firstToken(TokenType::Hidden);
    return t && t->value == "1";
}

bool Task::isEmpty() const
{
    return text().trimmed().isEmpty();
}

bool Task::inFuture(const QString &today, bool createIsThreshold) const
{
    QString date = thresholdDate();
    if (date.isEmpty() && createIsThreshold)
        date = createDate();
    if (date.isEmpty())
        return false;
    return date > today;
}

QString Task::completionDate() const
{
    const Token *t = firstToken(TokenType::CompletedDate);
    return t ? t->value : QString();
}

QString Task::createDate() const
{
    const Token *t = firstToken(TokenType::CreateDate);
    return t ? t->value : QString();
}

void Task::setCreateDate(const QString &date)
{
    QList<Token> head;
    if (!m_tokens.isEmpty() && m_tokens.first().type == TokenType::Completed) {
        head << m_tokens.takeFirst();
        if (!m_tokens.isEmpty() && m_tokens.first().type == TokenType::CompletedDate)
            head << m_tokens.takeFirst();
    }
    if (!m_tokens.isEmpty() && m_tokens.first().type == TokenType::Priority)
        head << m_tokens.takeFirst();
    if (!m_tokens.isEmpty() && m_tokens.first().type == TokenType::CreateDate)
        m_tokens.removeFirst();
    if (!date.isEmpty())
        head << mk(TokenType::CreateDate, date, QString(), date);
    m_tokens = head + m_tokens;
}

QString Task::dueDate() const
{
    const Token *t = firstToken(TokenType::Due);
    return t ? t->value : QString();
}

void Task::setDueDate(const QString &date)
{
    if (date.isEmpty())
        removeTokens(TokenType::Due);
    else
        upsertToken(keyValue(TokenType::Due, "due", date));
}

QString Task::thresholdDate() const
{
    const Token *t = firstToken(TokenType::Threshold);
    return t ? t->value : QString();
}

void Task::setThresholdDate(const QString &date)
{
    if (date.isEmpty())
        removeTokens(TokenType::Threshold);
    else
        upsertToken(keyValue(TokenType::Threshold, "t", date));
}

QString Task::recurrence() const
{
    const Token *t = firstToken(TokenType::Recurrence);
    return t ? t->value : QString();
}

bool Task::isSeries() const
{
    return !recurrence().isEmpty() && (!dueDate().isEmpty() || !createDate().isEmpty());
}

QStringList Task::doneDates() const
{
    QStringList r;
    foreach (const Token &t, m_tokens)
        if (t.type == TokenType::Ext && t.key.compare("done", Qt::CaseInsensitive) == 0
                && isDate(t.value) && !r.contains(t.value))
            r << t.value;
    r.sort();
    return r;
}

void Task::addDoneDate(const QString &date)
{
    if (!isDate(date) || doneDates().contains(date))
        return;
    appendToken(keyValue(TokenType::Ext, "done", date));
}

void Task::removeDoneDate(const QString &date)
{
    for (int i = m_tokens.size() - 1; i >= 0; --i)
        if (m_tokens[i].type == TokenType::Ext
                && m_tokens[i].key.compare("done", Qt::CaseInsensitive) == 0
                && m_tokens[i].value == date)
            m_tokens.removeAt(i);
}

QString Task::uuid() const
{
    const Token *t = firstToken(TokenType::Uuid);
    return t ? t->value : QString();
}

QChar Task::priority() const
{
    const Token *t = firstToken(TokenType::Priority);
    return t ? t->value.at(0) : QChar('-');
}

void Task::setPriority(QChar code)
{
    if (code == '-' || code.isNull() || !code.isLetter()) {
        removeTokens(TokenType::Priority);
        return;
    }
    QString c = QString(code.toUpper());
    Token t = mk(TokenType::Priority, "(" + c + ")", QString(), c);
    if (firstToken(TokenType::Priority))
        upsertToken(t);
    else
        m_tokens.prepend(t);
}

int Task::manualOrder() const
{
    const Token *t = firstToken(TokenType::Order);
    return t ? t->value.toInt() : -1;
}

void Task::setManualOrder(int order)
{
    QString v = QString::number(order);
    Token t = mk(TokenType::Order, "#" + v, QString(), v);
    if (firstToken(TokenType::Order))
        upsertToken(t);
    else
        appendToken(t);
}

void Task::clearManualOrder()
{
    removeTokens(TokenType::Order);
}

static QStringList sortedUnique(const QStringList &in)
{
    QStringList out;
    foreach (const QString &s, in)
        if (!out.contains(s))
            out << s;
    std::sort(out.begin(), out.end());
    return out;
}

QStringList Task::lists() const
{
    QStringList r;
    foreach (const Token &t, m_tokens)
        if (t.type == TokenType::List)
            r << t.value;
    return sortedUnique(r);
}

QStringList Task::tags() const
{
    QStringList r;
    foreach (const Token &t, m_tokens)
        if (t.type == TokenType::Tag)
            r << t.value;
    return sortedUnique(r);
}

QStringList Task::links() const
{
    QStringList r;
    foreach (const Token &t, m_tokens)
        if (t.type == TokenType::Link && !r.contains(t.text))
            r << t.text;
    return r;
}

QStringList Task::phones() const
{
    QStringList r;
    foreach (const Token &t, m_tokens)
        if (t.type == TokenType::Phone && !r.contains(t.text))
            r << t.text;
    return r;
}

QStringList Task::mails() const
{
    QStringList r;
    foreach (const Token &t, m_tokens)
        if (t.type == TokenType::Mail && !r.contains(t.text))
            r << t.text;
    return r;
}

void Task::addList(const QString &names)
{
    QStringList current = lists();
    foreach (const QString &n, splitWords(names)) {
        if (!current.contains(n)) {
            appendToken(mk(TokenType::List, "@" + n, QString(), n));
            current << n;
        }
    }
}

void Task::addTag(const QString &names)
{
    QStringList current = tags();
    foreach (const QString &n, splitWords(names)) {
        if (!current.contains(n)) {
            appendToken(mk(TokenType::Tag, "+" + n, QString(), n));
            current << n;
        }
    }
}

void Task::removeList(const QString &name)
{
    for (int i = m_tokens.size() - 1; i >= 0; --i)
        if (m_tokens[i].type == TokenType::List && m_tokens[i].value == name)
            m_tokens.removeAt(i);
}

void Task::removeTag(const QString &name)
{
    for (int i = m_tokens.size() - 1; i >= 0; --i)
        if (m_tokens[i].type == TokenType::Tag && m_tokens[i].value == name)
            m_tokens.removeAt(i);
}

bool Task::markComplete(const QString &date, Task *newTask)
{
    if (isCompleted())
        return false;
    const QString original = text();
    QList<Token> head;
    head << mk(TokenType::Completed, "x") << mk(TokenType::CompletedDate, date, QString(), date);
    m_tokens = head + m_tokens;

    const QString pattern = recurrence();
    if (pattern.isEmpty() || !newTask)
        return false;

    QString deferFrom;
    if (!pattern.contains('+'))
        deferFrom = date;
    *newTask = Task(original);
    if (!newTask->dueDate().isEmpty())
        newTask->deferDueDate(pattern, deferFrom);
    if (!newTask->thresholdDate().isEmpty())
        newTask->deferThresholdDate(pattern, deferFrom);
    if (!createDate().isEmpty())
        newTask->setCreateDate(date);
    return true;
}

void Task::markIncomplete()
{
    removeTokens(TokenType::Completed);
    removeTokens(TokenType::CompletedDate);
}

QString Task::deferDate(const QString &deferString, const QString &fromDate) const
{
    if (isDate(deferString))
        return deferString;
    if (deferString.isEmpty())
        return QString();
    QDate from = fromDate.isEmpty() ? QDate::currentDate() : QDate::fromString(fromDate, "yyyy-MM-dd");
    if (!from.isValid())
        from = QDate::currentDate();
    return addInterval(from, deferString).toString("yyyy-MM-dd");
}

void Task::deferDueDate(const QString &deferString, const QString &fromDate)
{
    QString old = fromDate.isEmpty() ? dueDate() : fromDate;
    setDueDate(deferDate(deferString, old));
}

void Task::deferThresholdDate(const QString &deferString, const QString &fromDate)
{
    QString old = fromDate.isEmpty() ? thresholdDate() : fromDate;
    setThresholdDate(deferDate(deferString, old));
}

QDate Task::addInterval(const QDate &date, const QString &interval)
{
    QRegularExpression re("(\\d*)([dwmyb])");
    QRegularExpressionMatch m = re.match(interval.toLower());
    if (!m.hasMatch())
        return date;
    const QString amountStr = m.captured(1);
    int amount = amountStr.isEmpty() ? 1 : amountStr.toInt();
    const QString type = m.captured(2);
    if (type == "d")
        return date.addDays(amount);
    if (type == "w")
        return date.addDays(7 * amount);
    if (type == "m")
        return date.addMonths(amount);
    if (type == "y")
        return date.addYears(amount);
    if (type == "b") {
        QDate d = date;
        while (amount > 0) {
            int dow = d.dayOfWeek(); // 1 = Monday .. 7 = Sunday
            if (dow == 5)
                d = d.addDays(3);
            else if (dow == 6)
                d = d.addDays(2);
            else
                d = d.addDays(1);
            amount--;
        }
        return d;
    }
    return date;
}

QString Task::alphaParts() const
{
    QStringList parts;
    foreach (const Token &t, m_tokens)
        if (t.isAlpha())
            parts << t.text;
    return parts.join(" ");
}

QString Task::showParts(bool hideLists, bool hideTags, bool hideDates) const
{
    QStringList parts;
    foreach (const Token &t, m_tokens) {
        switch (t.type) {
        case TokenType::Completed:
        case TokenType::CompletedDate:
        case TokenType::CreateDate:
        case TokenType::Uuid:
        case TokenType::Order:
        case TokenType::Priority:
            continue;
        case TokenType::List:
            if (hideLists) continue;
            break;
        case TokenType::Tag:
            if (hideTags) continue;
            break;
        case TokenType::Due:
        case TokenType::Threshold:
        case TokenType::Recurrence:
            if (hideDates) continue;
            break;
        default:
            break;
        }
        parts << t.text;
    }
    return parts.join(" ").trimmed();
}
