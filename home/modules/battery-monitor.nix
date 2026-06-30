{ pkgs, lib, ... }:

let
  batteryAlert = pkgs.writeShellScriptBin "battery-alert" ''
    CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100)
    STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")

    # Only alert when discharging
    if [ "$STATUS" = "Discharging" ]; then
      if [ "$CAPACITY" -le 5 ]; then
        notify-send -u critical -t 0 "⚠️ CRITICAL" "Battery at ''${CAPACITY}% — about to die!"
      elif [ "$CAPACITY" -le 10 ]; then
        notify-send -u critical -t 5000 "⚠️ Low Battery" "Battery at ''${CAPACITY}% — plug in soon!"
      fi
    fi
  '';
in
{
  home.packages = [ batteryAlert ];

  # Run battery check every 2 minutes via a user systemd timer
  systemd.user.services.battery-monitor = {
    Unit = {
      Description = "Battery level monitor — alerts at 10% and 5%";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${batteryAlert}/bin/battery-alert";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.timers.battery-monitor = {
    Unit = {
      Description = "Periodic battery level check";
    };
    Timer = {
      OnCalendar = "*:0/2";  # Every 2 minutes
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
