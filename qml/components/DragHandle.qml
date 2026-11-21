import QtQuick 2.0
import Sailfish.Silica 1.0

// Drag handle for manual ordering in a ListView. Owns the input handling
// (including the workaround for Silica swallowing the touch release) and the
// edge auto-scroll. What a drop at a given scene position means - and how it is
// committed - is up to the host, which reacts to moved()/finished().
Item {
    id: root

    // The SilicaListView this handle reorders, and (optionally) an outer
    // flickable whose interaction is suspended during the drag.
    property var listView
    property var scrollFlickable
    // Whether the handle is shown and usable (e.g. only base rows, not in
    // selection mode).
    property bool active: true
    // Set by the host: the current drop would be rejected, so show a cancel
    // icon instead of the menu grip.
    property bool blocked: false
    readonly property bool dragging: _dragging

    property bool _dragging: false
    // Set once the finger has actually moved past moveThreshold. Until then the
    // list is left untouched: changing interactive/cacheBuffer re-anchors the
    // content and makes the list jump even while the finger is still.
    property bool _armed: false
    property real _pressX: 0
    property real _pressY: 0
    readonly property real moveThreshold: Theme.paddingMedium

    signal started(real sceneX, real sceneY)
    signal moved(real sceneX, real sceneY)
    signal finished()

    visible: active
    width: active ? Theme.itemSizeSmall : 0
    height: parent ? parent.height : 0

    // A drag must not outlive the handle (e.g. selection mode turning on).
    onActiveChanged: if (!active) finish()

    // Pointer position in scene coordinates: it stays valid while the list
    // auto-scrolls under a still finger, and is independent of the row being
    // reordered (unlike the MouseArea's local mouse position, which shifts when
    // the delegate moves).
    property real pointerX: 0
    property real pointerY: 0
    property bool scrollUp: false
    property bool scrollDown: false
    readonly property real sceneTop: listView ? listView.mapToItem(null, 0, 0).y : 0
    readonly property real sceneBottom: listView ? listView.mapToItem(null, 0, listView.height).y : 0
    readonly property real edge: Theme.itemSizeMedium
    // Extra margin so once scrolling, the finger has to move a bit past the
    // boundary to stop (avoids flicker at the boundary).
    readonly property real hysteresis: Theme.itemSizeSmall
    readonly property real maxScrollStep: 24

    function finish() {
        if (!_dragging) return
        _dragging = false
        _armed = false
        scrollUp = false
        scrollDown = false
        if (listView) {
            listView.interactive = true
            listView.cacheBuffer = Theme.itemSizeMedium * 8
        }
        if (scrollFlickable)
            scrollFlickable.interactive = true
        finished()
    }

    // Start a real drag. Called on the first movement past moveThreshold, not on
    // the initial press, so a still finger never re-anchors the list content.
    function beginDrag() {
        if (_armed) return
        _armed = true
        if (listView) {
            listView.interactive = false
            // Keep the dragged delegate alive while auto-scrolling.
            listView.cacheBuffer = Theme.itemSizeMedium * 60
        }
        if (scrollFlickable)
            scrollFlickable.interactive = false
        started(pointerX, pointerY)
    }

    // Recompute the auto-scroll direction; called on every move and every tick,
    // so reversing the finger changes/stops the direction right away.
    function updateAutoScroll() {
        if (!_dragging || !mouseArea.pressed || !_armed) { scrollUp = false; scrollDown = false; return }
        var top = sceneTop + edge + (scrollUp ? hysteresis : 0)
        var bottom = sceneBottom - edge - (scrollDown ? hysteresis : 0)
        if (pointerY < top) { scrollUp = true; scrollDown = false }
        else if (pointerY > bottom) { scrollUp = false; scrollDown = true }
        else { scrollUp = false; scrollDown = false }
    }
    // How far (0..1) the finger is past the edge zone; the deeper it is, the
    // faster the auto-scroll gets.
    function edgeOvershoot() {
        var over = 0
        if (scrollUp)
            over = (sceneTop + edge - pointerY) / edge
        else if (scrollDown)
            over = (pointerY - (sceneBottom - edge)) / edge
        return Math.max(0, Math.min(1, over))
    }
    function scrollSpeed() {
        return 3 + edgeOvershoot() * (maxScrollStep - 3)
    }

    // Finger position in scene coordinates, coming from the window-level touch
    // handler (stable while the rows are being reordered).
    function onFinger(x, y) {
        if (!_dragging) return
        mouseArea.useTouch = true
        pointerX = x
        pointerY = y
        if (!_armed) {
            var dx = x - _pressX
            var dy = y - _pressY
            if (Math.sqrt(dx * dx + dy * dy) <= moveThreshold)
                return
            beginDrag()
        }
        moved(x, y)
        updateAutoScroll()
    }

    Icon {
        anchors.centerIn: parent
        source: root.blocked ? "image://theme/icon-m-cancel" : "image://theme/icon-m-menu"
        color: root.dragging ? Theme.highlightColor : Theme.secondaryColor
        opacity: 0.8
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        preventStealing: true

        // Whether touch positions are arriving via swipeDetector.touchMoved;
        // while they are, onPositionChanged (mouse) must not override them.
        property bool useTouch: false

        onPressed: {
            root._dragging = true
            root._armed = false
            useTouch = false
            var s = mapToItem(null, mouse.x, mouse.y)
            root.pointerX = s.x
            root.pointerY = s.y
            root._pressX = s.x
            root._pressY = s.y
        }
        onPositionChanged: {
            if (!root._dragging || useTouch) return
            var s = mapToItem(null, mouse.x, mouse.y)
            root.pointerX = s.x
            root.pointerY = s.y
            if (!root._armed) {
                var dx = s.x - root._pressX
                var dy = s.y - root._pressY
                if (Math.sqrt(dx * dx + dy * dy) <= root.moveThreshold)
                    return
                root.beginDrag()
            }
            root.moved(root.pointerX, root.pointerY)
            root.updateAutoScroll()
        }
        onReleased: root.finish()
        onCanceled: root.finish()
    }

    // Silica keeps the touch grab, so the MouseArea may never receive a
    // released/canceled event; end the drag when the window sees the finger
    // lift, and track its position from the same source.
    Connections {
        target: swipeDetector
        onReleased: root.finish()
        onTouchMoved: root.onFinger(scenePos.x, scenePos.y)
    }

    // Auto-scroll while the finger is past an edge. Speed grows with how far
    // past the edge it is. Direction is re-checked every tick.
    Timer {
        interval: 16
        repeat: true
        running: root._dragging && root._armed && mouseArea.pressed && (root.scrollUp || root.scrollDown)
        onTriggered: {
            root.updateAutoScroll()
            if (!root.scrollUp && !root.scrollDown) return
            var dy = root.scrollUp ? -root.scrollSpeed() : root.scrollSpeed()
            var maxY = Math.max(0, listView.contentHeight - listView.height)
            var y = Math.max(0, Math.min(listView.contentY + dy, maxY))
            if (y !== listView.contentY) {
                listView.contentY = y
                root.moved(root.pointerX, root.pointerY)
            }
        }
    }
}
