import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3
import Lomiri.Components.Themes 1.3
import QtQuick 2.7
import QtQuick.Layouts 1.3
import QtQuick.Controls 2.5 as QC
import Qt.labs.settings 1.0

import "../util"

Page {
   id: settingsPage
   anchors.fill: parent
   signal updateIntervalChanged(var interval, var enabled)
   signal apiKeyChanged(var key)

   property var plantsModel: null
   property bool showApiKey: false
   property bool testingApiKey: false
   property string initialApiKey: plantsModel ? plantsModel.loadApiKey() : ""

   Settings {
      id: settings
      property bool keepDisplayOn
   }

   Connections {
      target: plantsModel
      function onApiKeyTestResult(ok, error) {
         testingApiKey = false

         if (ok)
            Dialogs.showErrorDialog(root, i18n.tr("API key valid"),
                                    i18n.tr("The Pl@ntNet API key works correctly."))
         else
            Dialogs.showErrorDialog(root, i18n.tr("API key test failed"), error)
      }
   }

   header: PageHeader {
      id: header
      title: i18n.tr("Settings")
   }

   Flickable {
      id: flickable
      anchors.top: header.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.bottomMargin: keyboardRect.visible ? keyboardRect.height : anchors.margins

      contentWidth: parent.width
      contentHeight: settingsColumn.height

      flickableDirection: Flickable.AutoFlickIfNeeded

      Column {
         id: settingsColumn
         anchors.left: parent.left
         anchors.right: parent.right
         anchors.top: parent.top

         ListItem {
            height: l1.height + (divider.visible ? divider.height : 0)

            ListItemLayout {
               id: l1
               title.text: i18n.tr("Pl@ntNet API key")
               title.font.bold: true
               title.color: Theme.palette.normal.baseText
            }
         }

         ListItem {
            anchors.left: parent.left
            anchors.right: parent.right
            height: l2.height + (divider.visible ? divider.height : 0)

            SlotsLayout {
               id: l2
               mainSlot: Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.RichText
                  text: i18n.tr(
                           "In order to use the Pl@ntNet plant identification service, it is necessary to register at their website as developer and obtain an API-Key. This key needs to be configured within this app.\n\nPlease visit <a href=\"https://my.plantnet.org/signup\">https://my.plantnet.org/signup</a> and create a developer account. Afterwards visit <a href=\"https://my.plantnet.org/account\">https://my.plantnet.org/account</a> and click the eye-symbol at the very top (\"my API key\") to show the API-Key. Copy this key and paste it into the below text input field.")
                  color: Theme.palette.normal.baseText
                  wrapMode: Text.WordWrap
                  onLinkActivated: Qt.openUrlExternally(link)
               }
            }
         }

         ListItem {
            anchors.left: parent.left
            anchors.right: parent.right
            height: l4.height + (divider.visible ? divider.height : 0)

            SlotsLayout {
               id: l4
               mainSlot: Column {
                  spacing: units.gu(1)
                  Text {
                     text: i18n.tr("API-Key:")
                     color: Theme.palette.normal.baseText
                  }

                  Row {
                     anchors.left: parent.left
                     anchors.right: parent.right
                     anchors.rightMargin: units.gu(1)
                     spacing: units.gu(1)

                     TextField {
                        id: apiKeyInput
                        placeholderText: i18n.tr("Enter API-Key")
                        width: parent.width - units.gu(2) - saveButton.width
                        text: settingsPage.initialApiKey
                        echoMode: settingsPage.showApiKey ? TextInput.Normal : TextInput.Password

                        onActiveFocusChanged: {
                                keyboardRect.visible = activeFocus
                            if (activeFocus) {

                              var posWithinFlickable = mapToItem(settingsColumn, 0, height / 2);
                              flickable.contentY = posWithinFlickable.y - flickable.height / 2;
                            }
                        }
                     }

                     Button {
                        id: saveButton
                        enabled: settingsPage.initialApiKey !== apiKeyInput.text
                        text: i18n.tr("Save")
                        onClicked: {
                           plantsModel.persistApiKey(apiKeyInput.text)
                           emit: apiKeyChanged(apiKeyInput.text)
                           pageStack.pop()
                        }
                     }
                  }

                  Row {
                     anchors.left: parent.left
                     spacing: units.gu(1)

                     Text {
                        text: settingsPage.showApiKey ? i18n.tr("Hide API-Key") : i18n.tr(
                                                           "Show API-Key")
                        color: LomiriColors.blue
                        font.underline: true

                        MouseArea {
                           anchors.fill: parent
                           onClicked: settingsPage.showApiKey = !settingsPage.showApiKey
                        }
                     }
                  }

                  Row {
                     anchors.left: parent.left
                     spacing: units.gu(1)

                     Button {
                        id: testApiKeyButton
                        text: i18n.tr("Test key")
                        enabled: apiKeyInput.text.length > 0 && !settingsPage.testingApiKey
                                 && settingsPage.plantsModel
                        onClicked: {
                           settingsPage.testingApiKey = true
                           settingsPage.plantsModel.testApiKey(apiKeyInput.text)
                        }
                     }

                     QC.BusyIndicator {
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.gu(3)
                        height: units.gu(3)
                        visible: settingsPage.testingApiKey
                        running: settingsPage.testingApiKey
                     }
                  }
               }
            }
         }

         ListItem {
            anchors.left: parent.left
            anchors.right: parent.right
            height: l5.height + (divider.visible ? divider.height : 0)

            SlotsLayout {
               id: l5
               mainSlot: Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: i18n.tr("Keep display on while using the app")
                  color: Theme.palette.normal.baseText
                  wrapMode: Text.WordWrap
               }
               Switch {
                  checked: settings.keepDisplayOn
                  SlotsLayout.position: SlotsLayout.Trailing

                  onClicked: {
                     settings.keepDisplayOn = checked
                  }
               }
            }
         }
      }
   }

   Rectangle {
      id: keyboardRect
      width: parent.width
      height: parent.height * 0.3
      anchors.bottom: parent.bottom
      color: "white"
      visible: false
   }
}
