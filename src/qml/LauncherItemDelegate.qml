
// This file is part of colorful-home, a nice user experience for touchscreens.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// Copyright (c) 2013, Jolla Ltd <robin.burchell@jollamobile.com>
// Copyright (c) 2012, Timur Kristóf <venemo@fedoraproject.org>
// Copyright (c) 2011, Tom Swindell <t.swindell@rubyx.co.uk>

import QtQuick 2.0
import QtQuick.Controls.Nemo 1.0
import QtQuick.Controls.Styles.Nemo 1.0
import org.nemomobile.lipstick 0.1

Item {
    id: wrapper
    property alias source: iconImage.source
    property alias iconCaption: iconText.text
    property bool reordering
    property int newIndex: -1
    property real oldY

    onXChanged: moveTimer.start()
    onYChanged: moveTimer.start()

    Timer {
        id: moveTimer
        interval: 1
        onTriggered: moveIcon()
    }

    function moveIcon() {
        if (!reordering) {
            if (!slideMoveAnim.running) {
                slideMoveAnim.start()
            }
        }
    }

    GridView {
        id: folderLoader
        anchors.top: parent.bottom
        width: gridview.width
        height: childrenRect.height
        cellWidth: gridview.cellWidth
        cellHeight: cellWidth + 30
        Rectangle {
            anchors.fill: parent
            opacity: 0.75
            color: "white"
        }

        delegate: MouseArea {
            width: gridview.cellWidth
            height: gridview.cellHeight
            Image {
                id: iconimage
                source: model.object.iconId == "" ? ":/images/icons/apps.png" : (model.object.iconId.indexOf("/") == 0 ? "file://" : "image://theme/") + model.object.iconId
            }
            Text {
                id: icontext
                // elide only works if an explicit width is set
                width: parent.width
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: gridview.cellWidth/10
                color: 'white'
                anchors {
                    left: parent.left
                    right: parent.right
                    top: iconimage.bottom
                    topMargin: 5
                }
            }
            onClicked: {
                model.object.launchApplication()
            }
        }
    }

    // Application icon for the launcher
    MouseArea {
        id: launcherItem
        width: wrapper.width
        height: wrapper.height
        parent: gridview.contentItem
        scale: reordering ? 1.3 : 1
        transformOrigin: Item.Center
        onXChanged: moved()
        onYChanged: moved()

        onClicked: {
            // TODO: disallow if close mode enabled
            if (model.object.type !== LauncherModel.Folder) {
                var winId = switcher.switchModel.getWindowIdForTitle(model.object.title)
                console.log("Window id found: " + winId)
                if (winId == 0)
                    model.object.launchApplication()
                else
                    Lipstick.compositor.windowToFront(winId)
            } else {
                if (!folderLoader.visible) {
                    folderLoader.visible = true
                    folderLoader.model = model.object
                } else {
                    folderLoader.visible = false
                }
            }
        }

        onPressAndHold: {
            reparent(gridview)
            reorderItem = launcherItem
            drag.target = launcherItem
            z = 1000
            reordering = true
            gridview.onUninstall = true

            // don't allow dragging an icon out of pages with a horizontal flick
            pager.interactive = false
        }

        onReleased: {
            if (reordering) {
                reordering = false
                reorderTimer.stop()
                drag.target = null
                reorderItem = null
                pager.interactive = true
                gridview.onUninstall = false
                deleter.remove.text = "Remove"
                deleter.uninstall.text = "Uninstall"

                reparent(gridview.contentItem)

                slideMoveAnim.start()
            }
        }

        function reparent(newParent) {
            var newPos = mapToItem(newParent, 0, 0)
            parent = newParent
            x = newPos.x - width/2 * (1-scale)
            y = newPos.y - height/2 * (1-scale)
        }

        function moved() {
            if (reordering) {
                var gridViewPos = gridview.contentItem.mapFromItem(launcherItem, width/2, height/2)
                var idx = gridview.indexAt(gridViewPos.x, gridViewPos.y)
                var delPos = deleter.remove.mapFromItem(launcherItem, width/2, height/2)
                var isdel = deleter.childAt(delPos.x, delPos.y)
                if (isdel === deleter.remove) {
                    deleter.remove.text = "Removing " + iconCaption
                } else if (isdel === deleter.uninstall) {
                    deleter.uninstall.text = "Uninstalling " + iconCaption
                }
                if (newIndex !== idx) {
                    reorderTimer.restart()
                    newIndex = idx
                }
            }
        }

        Timer {
            id: reorderTimer
            interval: 100
            onTriggered: {
                if (newIndex != -1 && newIndex !== index) {
                    launcherModel.move(index, newIndex)
                }
                newIndex = -1
            }
        }

        Behavior on scale {
            NumberAnimation { easing.type: Easing.InOutQuad; duration: 150 }
        }

        ParallelAnimation {
            id: slideMoveAnim
            NumberAnimation { target: launcherItem; property: "x"; to: wrapper.x; duration: 130; easing.type: Easing.OutQuint }
            NumberAnimation { target: launcherItem; property: "y"; to: wrapper.y; duration: 130; easing.type: Easing.OutQuint }
        }

        Image {
            id: iconImage
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                topMargin: 8
            }
            width: gridview.cellWidth - gridview.cellWidth/10
            height: width
            asynchronous: true

            Spinner {
                id: spinner
                anchors.centerIn: parent
                enabled: (model.object.type === LauncherModel.Application) ? model.object.isLaunching : false
            }
        }

        // Caption for the icon
        Text {
            id: iconText
            // elide only works if an explicit width is set
            width: parent.width
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: gridview.cellWidth/10
            color: 'white'
            anchors {
                left: parent.left
                right: parent.right
                top: iconImage.bottom
                topMargin: 5
            }
        }
    }
}
