import QtQuick 2.7
import Lomiri.Components 1.3

Item {
   id: toast
   anchors.fill: parent
   z: 500

   property alias text: toastText.text
   property int displayDuration: 1500

   signal dismissed

   function show() {
      toastRect.opacity = 1
      hideTimer.restart()
   }

   Rectangle {
      id: toastRect
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: units.gu(4)
      radius: units.gu(1)
      color: "#232323"
      opacity: 0
      width: toastText.width + units.gu(4)
      height: toastText.height + units.gu(2)

      Behavior on opacity {
         NumberAnimation {
            duration: 200
         }
      }

      Text {
         id: toastText
         anchors.centerIn: parent
         color: "white"
      }
   }

   Timer {
      id: hideTimer
      interval: toast.displayDuration
      onTriggered: {
         toastRect.opacity = 0
         toast.dismissed()
      }
   }
}
