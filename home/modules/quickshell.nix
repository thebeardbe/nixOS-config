{ config, pkgs, theme, ... }: 
let
  # Helper to remove # and add alpha
  alphaHex = color: alpha: "#" + alpha + (builtins.substring 1 6 color);
in
{
  home.packages = [ pkgs.quickshell ];

  # Modular Quickshell configuration
  xdg.configFile."quickshell/shell.qml".text = ''
    import QtQuick
    import Quickshell
    import Quickshell.Wayland
    import Quickshell.Hyprland

    ShellRoot {
      // --- WALLPAPERS ---
      Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
          screen: modelData
          anchors {
            top: true
            bottom: true
            left: true
            right: true
          }
          WlrLayershell.layer: WlrLayer.Background
          WlrLayershell.namespace: "wallpaper"
          exclusionMode: ExclusionMode.None
          focusable: false
          
          Rectangle {
            anchors.fill: parent
            color: "${theme.colors.background}"
            
            Canvas {
              anchors.fill: parent
              onPaint: {
                var ctx = getContext("2d");
                ctx.strokeStyle = "${alphaHex theme.colors.accent "10"}";
                ctx.lineWidth = 1;
                for (var i = 0; i < width; i += 50) {
                  ctx.beginPath(); ctx.moveTo(i, 0); ctx.lineTo(i, height); ctx.stroke();
                }
                for (var j = 0; j < height; j += 50) {
                  ctx.beginPath(); ctx.moveTo(0, j); ctx.lineTo(width, j); ctx.stroke();
                }
              }
            }
          }
        }
      }

      // --- BARS ---
      Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
          id: bar
          screen: modelData
          anchors {
            top: true
            left: true
            right: true
          }
          height: 34
          WlrLayershell.layer: WlrLayer.Top
          WlrLayershell.namespace: "bar"
          
          Rectangle {
            anchors.fill: parent
            color: "${theme.colors.background}"
            
            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: 2
              color: "${theme.colors.accent}"
            }
          }

          Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
              text: "OTHERLAND"
              color: "${theme.colors.text}"
              font.family: "${theme.font.family}"
              font.pixelSize: 14
              font.bold: true
            }

            Row {
              spacing: 8
              Repeater {
                model: Hyprland.workspaces
                Rectangle {
                  width: 8; height: 8
                  radius: 4
                  color: (modelData.id == Hyprland.focusedWorkspace.id) ? "${theme.colors.accent}" : "${theme.colors.border}"
                  opacity: (modelData.id == Hyprland.focusedWorkspace.id) ? 1.0 : 0.4
                  
                  Behavior on opacity { NumberAnimation { duration: 200 } }
                  Behavior on color { ColorAnimation { duration: 200 } }
                }
              }
            }
          }

          Text {
            anchors.centerIn: parent
            text: (Hyprland.activeWindow && Hyprland.focusedMonitor == modelData) ? Hyprland.activeWindow.title : "THE NET IS STABLE"
            color: "${theme.colors.accent}"
            font.family: "${theme.font.family}"
            font.pixelSize: 11
            elide: Text.ElideRight
            width: 400
            horizontalAlignment: Text.AlignHCenter
          }

          Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 15

            Text {
              text: "SYS: " + Math.round(modelData.width) + "x" + Math.round(modelData.height)
              color: "${theme.colors.text}"
              font.family: "${theme.font.family}"
              font.pixelSize: 10
              opacity: 0.7
            }

            Text {
              text: Qt.formatDateTime(new Date(), "hh:mm")
              color: "${theme.colors.text}"
              font.family: "${theme.font.family}"
              font.pixelSize: 12
              
              Timer {
                interval: 60000; running: true; repeat: true
                onTriggered: parent.text = Qt.formatDateTime(new Date(), "hh:mm")
              }
            }
          }
        }
      }
    }
  '';
}
