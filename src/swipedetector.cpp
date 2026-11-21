#include "swipedetector.h"

#include <QTouchEvent>
#include <QMouseEvent>
#include <QWindow>
#include <QDateTime>
#include <QtMath>

static const int MIN_MS = 800;
static const qint64 TOUCH_MOUSE_GUARD_MS = 400;

SwipeDetector::SwipeDetector(QObject *parent)
    : QObject(parent)
    , m_active(false)
    , m_touchActive(false)
    , m_lastTouchEnd(0)
{
}

void SwipeDetector::start(const QPointF &pos)
{
    m_active = true;
    m_start = pos;
    m_timer.start();
}

void SwipeDetector::finish(const QPointF &pos, QObject *watched)
{
    if (!m_active)
        return;
    m_active = false;

    QWindow *window = qobject_cast<QWindow *>(watched);
    const qreal width = window ? window->width() : 0;

    const QPointF delta = pos - m_start;
    const qreal minDistance = qMax<qreal>(150, width * 0.25);
    // Only leftward gestures are meaningful; rightward swipes from the left
    // edge are Sailfish's page back navigation and are ignored.
    if (delta.x() > -minDistance
            || qAbs(delta.x()) < qAbs(delta.y()) * 1.5
            || m_timer.elapsed() > MIN_MS)
        return;

    emit swipeLeft();
}

bool SwipeDetector::eventFilter(QObject *watched, QEvent *event)
{
    switch (event->type()) {
    case QEvent::TouchBegin: {
        QTouchEvent *te = static_cast<QTouchEvent *>(event);
        if (te->touchPoints().size() != 1)
            break;
        m_touchActive = true;
        start(te->touchPoints().first().pos());
        break;
    }
    case QEvent::TouchEnd: {
        QTouchEvent *te = static_cast<QTouchEvent *>(event);
        emit released();
        if (!m_touchActive || te->touchPoints().isEmpty())
            break;
        m_touchActive = false;
        m_lastTouchEnd = QDateTime::currentMSecsSinceEpoch();
        finish(te->touchPoints().first().pos(), watched);
        break;
    }
    case QEvent::TouchUpdate: {
        QTouchEvent *te = static_cast<QTouchEvent *>(event);
        if (te->touchPoints().size() == 1)
            emit touchMoved(te->touchPoints().first().scenePos());
        break;
    }
    case QEvent::TouchCancel: {
        emit released();
        break;
    }
    case QEvent::MouseButtonPress: {
        if (m_touchActive
                || QDateTime::currentMSecsSinceEpoch() - m_lastTouchEnd < TOUCH_MOUSE_GUARD_MS)
            break;
        start(static_cast<QMouseEvent *>(event)->localPos());
        break;
    }
    case QEvent::MouseButtonRelease: {
        emit released();
        if (m_touchActive
                || QDateTime::currentMSecsSinceEpoch() - m_lastTouchEnd < TOUCH_MOUSE_GUARD_MS)
            break;
        finish(static_cast<QMouseEvent *>(event)->localPos(), watched);
        break;
    }
    default:
        break;
    }
    return false;
}
