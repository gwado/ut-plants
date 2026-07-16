import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3
import Lomiri.Content 1.1
import QtQuick.Controls 2.5 as QC

import "../util"

import PlantsModel 1.0

Page {
   id: mainPage
   anchors.fill: parent

   property var plantsModel: nil
   property var resultsData: []

   header: PageHeader {
      id: header
      title: i18n.tr('Identification results')
   }

   Component.onCompleted: {
      resultsData.forEach(function (res) {
         resultsModel.append(res)
      })
   }

   ListModel {
      id: resultsModel
   }

   Text {
      id: summaryLabel
      anchors.top: header.bottom
      anchors.topMargin: units.gu(1)
      anchors.left: parent.left
      anchors.leftMargin: units.gu(2)
      color: Theme.palette.normal.baseText
      text: resultsModel.count == 1 ? i18n.tr("1 result found") : i18n.tr(
                                        "%1 results found").arg(resultsModel.count)
   }

   ListView {
      id: summaryList
      anchors.top: summaryLabel.bottom
      anchors.topMargin: units.gu(1)
      anchors.left: parent.left
      anchors.right: parent.right
      height: units.gu(11)

      clip: true
      orientation: ListView.Horizontal
      spacing: units.gu(1)
      leftMargin: units.gu(2)
      rightMargin: units.gu(2)

      model: resultsModel

      Connections {
         target: resultList
         function onCurrentIndexChanged() {
            summaryList.positionViewAtIndex(resultList.currentIndex, ListView.Contain)
         }
      }

      delegate: Component {
         Rectangle {
            id: summaryItem
            width: units.gu(9)
            height: summaryList.height
            radius: units.gu(1)
            color: index === resultList.currentIndex ? "#669900" : "#e8e8e8"
            border.width: index === resultList.currentIndex ? 0 : 1
            border.color: "#cdcdcd"

            property var resultData: resultsData[index]
            property int scoreValue: resultData ? Math.round(resultData.score * 100) : 0

            MouseArea {
               anchors.fill: parent
               onClicked: resultList.currentIndex = index
            }

            Column {
               anchors.fill: parent
               anchors.margins: units.gu(0.5)
               spacing: units.gu(0.5)

               Image {
                  width: parent.width
                  height: units.gu(6)
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  source: summaryItem.resultData && summaryItem.resultData.images.length
                          ? prepareSummaryImageUrl(summaryItem.resultData.images[0].url) : ''
               }

               Text {
                  width: parent.width
                  text: summaryItem.resultData ? summaryItem.resultData.species : ''
                  elide: Text.ElideRight
                  font.pixelSize: units.gu(1.3)
                  font.bold: true
                  color: index === resultList.currentIndex ? "white" : "#232323"
               }

               Text {
                  text: summaryItem.scoreValue + "%"
                  font.pixelSize: units.gu(1.3)
                  font.bold: true
                  color: summaryItem.scoreValue > 80 ? (index === resultList.currentIndex
                                                        ? "white" : "#232323") : (summaryItem.scoreValue
                                                        > 50 ? LomiriColors.orange : LomiriColors.red)
               }
            }
         }
      }
   }

   function prepareSummaryImageUrl(url) {
      if (!url)
         return url

      if (url[0] === '/')
         return 'file://' + url

      return url
   }

   QC.PageIndicator {
      id: pageIndicator
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: units.gu(2)

      currentIndex: resultList.currentIndex
      count: resultList.count
   }

   ListView {
      id: resultList
      anchors.top: summaryList.bottom
      anchors.topMargin: units.gu(2)
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: pageIndicator.top
      anchors.bottomMargin: units.gu(2)

      clip: true
      orientation: ListView.Horizontal
      snapMode: ListView.SnapToItem
      highlightRangeMode: ListView.StrictlyEnforceRange

      // Use a constant scroll speed instead of a fixed duration: jumping several
      // results at once (tapping a distant thumbnail in the summary strip) would
      // otherwise cover a bigger distance in the same time, looking sped up.
      highlightMoveDuration: -1
      highlightMoveVelocity: width * 3

      property double elementSpacing: units.gu(2)

      model: resultsModel

      delegate: Component {
         PlantCard {
            width: resultList.width
            height: resultList.height

            plant: resultsData[index]
            resultView: true

            saveFunction: function (plant) {
               var err = plantsModel.savePlant(plant)

               if (!err) {
                  saveToast.show()
               } else {
                  Dialogs.showErrorDialog(
                           root, i18n.tr("Saving result failed"),
                           i18n.tr("Result could not be saved (%1).").arg(err))
               }
            }
         }
      }
   }

   Toast {
      id: saveToast
      text: i18n.tr("Plant saved")
      onDismissed: pageStack.pop()
   }
}
