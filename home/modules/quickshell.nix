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
    import Quickshell.Io
    import Quickshell.Services.SystemTray

    // ... (rest of imports)

    ShellRoot {
      // --- WALLPAPERS ---
      Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
          id: wallpaper
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
            
            // Subtle Grid
            Canvas {
              anchors.fill: parent
              opacity: 0.15
              onPaint: {
                var ctx = getContext("2d");
                ctx.strokeStyle = "${theme.colors.accent}";
                ctx.lineWidth = 1;
                for (var i = 0; i < width; i += 80) {
                  ctx.beginPath(); ctx.moveTo(i, 0); ctx.lineTo(i, height); ctx.stroke();
                }
                for (var j = 0; j < height; j += 80) {
                  ctx.beginPath(); ctx.moveTo(0, j); ctx.lineTo(width, j); ctx.stroke();
                }
              }
            }

            // Corrupted "Image" Glitch
            Rectangle {
              id: imageGlitch
              anchors.fill: parent
              opacity: 0
              gradient: Gradient {
                GradientStop { position: 0.0; color: "${theme.colors.background}" }
                GradientStop { position: 0.5; color: "${theme.colors.accent}" }
                GradientStop { position: 1.0; color: "${theme.colors.background}" }
              }
              
              Timer {
                interval: 5000; running: true; repeat: true
                onTriggered: {
                  imageGlitch.opacity = Math.random() > 0.95 ? 0.2 : 0;
                  imageGlitch.rotation = Math.random() * 5 - 2.5;
                }
              }
            }

            // Glitch Layer
            Item {
              id: glitchLayer
              anchors.fill: parent
              
              property var codeSnippets: [
                "0x00 0xFF 0x42 0x13",
                "int *ptr = NULL;",
                "while(true) { fork(); }",
                "segmentation fault (core dumped)",
                "SYSTEM_HALTED_RECOVERY_MODE",
                "CONNECTING_TO_OTHERLAND...",
                "import Quickshell.Wayland",
                "yield syscall_exit;"
              ]

              Repeater {
                model: 5
                Rectangle {
                  id: glitchBlock
                  width: Math.random() * 200 + 50
                  height: Math.random() * 20 + 5
                  x: Math.random() * parent.width
                  y: Math.random() * parent.height
                  color: "${theme.colors.accent}"
                  opacity: 0
                  
                  Timer {
                    interval: Math.random() * 2000 + 500
                    running: true
                    repeat: true
                    onTriggered: {
                      glitchBlock.opacity = Math.random() > 0.8 ? 0.4 : 0;
                      glitchBlock.x = Math.random() * parent.width;
                      glitchBlock.y = Math.random() * parent.height;
                    }
                  }
                }
              }

              Repeater {
                model: 3
                Text {
                  id: glitchText
                  text: glitchLayer.codeSnippets[Math.floor(Math.random() * glitchLayer.codeSnippets.length)]
                  color: "${theme.colors.accent}"
                  font.family: "${theme.font.family}"
                  font.pixelSize: 10
                  opacity: 0
                  x: Math.random() * parent.width
                  y: Math.random() * parent.height
                  
                  Timer {
                    interval: Math.random() * 3000 + 1000
                    running: true
                    repeat: true
                    onTriggered: {
                      glitchText.opacity = Math.random() > 0.9 ? 0.6 : 0;
                      glitchText.text = glitchLayer.codeSnippets[Math.floor(Math.random() * glitchLayer.codeSnippets.length)];
                      glitchText.x = Math.random() * parent.width;
                      glitchText.y = Math.random() * parent.height;
                    }
                  }
                }
              }
            }

            // Vertical Data Streams
            Repeater {
               model: 10
               Text {
                 id: dataStream
                 text: "01"
                 color: "${theme.colors.accent}"
                 font.family: "${theme.font.family}"
                 font.pixelSize: 8
                 opacity: 0
                 x: Math.random() * parent.width
                 y: 0
                 
                 property int speed: Math.random() * 20 + 5
                 
                 Timer {
                   interval: 30; running: true; repeat: true
                   onTriggered: {
                     dataStream.y += dataStream.speed;
                     if (dataStream.y > parent.height) {
                       dataStream.y = -50;
                       dataStream.x = Math.random() * parent.width;
                       dataStream.opacity = Math.random() > 0.7 ? 0.2 : 0;
                       dataStream.text = Math.random() > 0.5 ? "10110" : "00101";
                     }
                   }
                 }
               }
            }

            // Central "Logo" / Pulse
            Rectangle {
               anchors.centerIn: parent
               width: 300
               height: 300
               radius: 150
               color: "transparent"
               border.color: "${theme.colors.accent}"
               border.width: 1
               opacity: 0.05

               PropertyAnimation on scale {
                 from: 0.95; to: 1.05
                 duration: 4000
                 loops: Animation.Infinite
                 easing.type: Easing.InOutSine
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
            color: "${alphaHex theme.colors.background "CC"}" // Black glass
            
            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: 1
              color: "${theme.colors.accent}"
            }
          }

          Row {
            anchors.left: parent.left
            anchors.leftMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            spacing: 15

            Text {
              text: "OTHERLAND"
              color: "${theme.colors.accent}"
              font.family: "${theme.font.family}"
              font.pixelSize: 14
              font.bold: true
              
              // Pulsing effect for the name
              SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.6; duration: 2000; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.6; to: 1.0; duration: 2000; easing.type: Easing.InOutQuad }
              }
            }

            Row {
              spacing: 10
              Repeater {
                model: Hyprland.workspaces
                Rectangle {
                  width: 24; height: 4
                  radius: 2
                  color: (modelData.id == Hyprland.focusedWorkspace.id) ? "${theme.colors.accent}" : "${theme.colors.text}"
                  opacity: (modelData.id == Hyprland.focusedWorkspace.id) ? 1.0 : 0.2
                  
                  Behavior on opacity { NumberAnimation { duration: 200 } }
                  Behavior on color { ColorAnimation { duration: 200 } }
                }
              }
            }
          }

          Text {
            anchors.centerIn: parent
            text: (Hyprland.activeWindow && Hyprland.focusedMonitor == modelData) ? Hyprland.activeWindow.title : "SECURE CONNECTION ESTABLISHED"
            color: "${theme.colors.text}"
            font.family: "${theme.font.family}"
            font.pixelSize: 11
            elide: Text.ElideRight
            width: 400
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.8
          }

          Row {
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            spacing: 20

            // System Tray
            Row {
               spacing: 8
               Repeater {
                 model: SystemTray.items
                 Image {
                   source: modelData.icon
                   width: 18; height: 18
                   fillMode: Image.PreserveAspectFit
                   
                   MouseArea {
                      anchors.fill: parent
                      acceptedButtons: Qt.LeftButton | Qt.RightButton
                      onClicked: (mouse) => {
                         if (mouse.button == Qt.RightButton) modelData.activate(0, 0);
                         else modelData.activate(0, 0);
                      }
                   }
                 }
               }
            }

            // Volume (Pavucontrol launcher)
            Text {
              text: "󰕾 " + volumeLevel + "%"
              color: "${theme.colors.text}"
              font.family: "${theme.font.family}"
              font.pixelSize: 12
              
              property string volumeLevel: "0"
              
              Process {
                id: volProcess
                command: ["pamixer", "--get-volume"]
                running: true
                stdout: SplitParser {
                  onRead: (data) => volumeLevel = data.trim()
                }
              }
              
              Timer {
                interval: 2000; running: true; repeat: true
                onTriggered: volProcess.running = true
              }

              MouseArea {
                anchors.fill: parent
                onClicked: {
                   var p = Qt.createQmlObject('import Quickshell.Io; Process { command: ["pavucontrol"] }', parent);
                   p.running = true;
                }
              }
            }

            // Wifi
            Text {
              text: "󰖩 " + ssid
              color: "${theme.colors.text}"
              font.family: "${theme.font.family}"
              font.pixelSize: 12
              
              property string ssid: "..."
              
              Process {
                id: wifiProcess
                command: ["nmcli", "-t", "-f", "active,ssid", "dev", "wifi"]
                running: true
                stdout: SplitParser {
                  onRead: (data) => {
                    var lines = data.split("\n");
                    for (var i = 0; i < lines.length; i++) {
                      if (lines[i].startsWith("yes:")) {
                        ssid = lines[i].substring(4);
                        return;
                      }
                    }
                    ssid = "DISCONNECTED";
                  }
                }
              }
              
              Timer {
                interval: 10000; running: true; repeat: true
                onTriggered: wifiProcess.running = true
              }
            }

            // Bluetooth
            Text {
              text: "󰂯"
              color: btEnabled ? "${theme.colors.accent}" : "${theme.colors.text}"
              font.family: "${theme.font.family}"
              font.pixelSize: 14
              opacity: btEnabled ? 1.0 : 0.5
              
              property bool btEnabled: false
              
              Process {
                id: btProcess
                command: ["bluetoothctl", "show"]
                running: true
                stdout: StdioCollector {
                  onStreamFinished: btEnabled = this.text.includes("Powered: yes")
                }
              }
              
              Timer {
                interval: 5000; running: true; repeat: true
                onTriggered: btProcess.running = true
              }
            }

            // Clock
            Text {
              text: Qt.formatDateTime(new Date(), "hh:mm")
              color: "${theme.colors.text}"
              font.family: "${theme.font.family}"
              font.pixelSize: 13
              font.bold: true
              
              Timer {
                interval: 10000; running: true; repeat: true
                onTriggered: parent.text = Qt.formatDateTime(new Date(), "hh:mm")
              }
            }

            // Power Menu
            Text {
              text: "󰐥"
              color: "${theme.colors.critical}"
              font.family: "${theme.font.family}"
              font.pixelSize: 16
              
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                   // Simple logout for now
                   var p = Qt.createQmlObject('import Quickshell.Io; Process { command: ["hyprctl", "dispatch", "exit"] }', parent);
                   p.running = true;
                }
              }
            }
          }
        }
      }
    }
  '';
}
