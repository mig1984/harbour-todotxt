#ifndef SWIPEDETECTOR_H
#define SWIPEDETECTOR_H

#include <QObject>
#include <QPointF>
#include <QElapsedTimer>

// Detects a horizontal swipe on the application window without stealing
// events from the QML scene. Used for the new task (swipe left) shortcut on
// the main page; the page itself decides whether the gesture is currently
// relevant.
class SwipeDetector : public QObject
{
    Q_OBJECT
public:
    explicit SwipeDetector(QObject *parent = 0);

signals:
    void swipeLeft();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void start(const QPointF &pos);
    void finish(const QPointF &pos, QObject *watched);

    bool m_active;
    QPointF m_start;
    QElapsedTimer m_timer;
    bool m_touchActive;
    qint64 m_lastTouchEnd;
};

#endif // SWIPEDETECTOR_H
