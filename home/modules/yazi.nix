{ pkgs, ... }:

let
  remote = pkgs.writeShellScriptBin "remote" ''
    set -euo pipefail

    SSH_CONFIG="$HOME/.ssh/config"
    MOUNT_BASE="/tmp/ssh-mounts"
    mkdir -p "$MOUNT_BASE"

    # ── List SSH hosts from config ──
    list_hosts() {
      grep -i "^Host " "$SSH_CONFIG" 2>/dev/null | \
        awk '{for (i=2; i<=NF; i++) print $i}' | \
        grep -v "[*?]" | sort -u
    }

    # ── List currently mounted hosts ──
    list_mounted() {
      for d in "$MOUNT_BASE"/*/; do
        [ -d "$d" ] || continue
        mountpoint -q "$d" 2>/dev/null && basename "$d"
      done | sort -u
    }

    # ── Mount a host ──
    cmd_mount() {
      local HOST="$1"
      local MP="$MOUNT_BASE/$HOST"
      mkdir -p "$MP"

      if mountpoint -q "$MP" 2>/dev/null; then
        echo "already-mounted"
        return 0
      fi

      if sshfs "$HOST": "$MP" \
        -o idmap=user,allow_other,follow_symlinks,reconnect 2>/dev/null; then
        echo "mounted"
        return 0
      else
        rmdir "$MP" 2>/dev/null
        echo "failed"
        return 1
      fi
    }

    # ── Unmount a host ──
    cmd_umount() {
      local HOST="$1"
      local MP="$MOUNT_BASE/$HOST"
      fusermount3 -u "$MP" 2>/dev/null || \
        fusermount -u "$MP" 2>/dev/null || \
        sudo umount "$MP" 2>/dev/null || true
      rmdir "$MP" 2>/dev/null
    }

    # ── Main menu ──
    case "''${1:-}" in
      mount)
        HOST="''${2:-}"
        if [ -z "$HOST" ]; then
          HOST=$(list_hosts | wofi --dmenu --prompt "Mount remote:")
          [ -z "$HOST" ] && exit 0
        fi
        case $(cmd_mount "$HOST") in
          mounted)  notify-send "Remote" "Mounted $HOST at $MOUNT_BASE/$HOST" ;;
          already-mounted) notify-send "Remote" "$HOST already mounted" ;;
          failed)   notify-send -u critical "Remote" "Failed to mount $HOST" ;;
        esac
        ;;
      umount|unmount)
        HOST="''${2:-}"
        if [ -z "$HOST" ]; then
          HOST=$(list_mounted | wofi --dmenu --prompt "Unmount:")
          [ -z "$HOST" ] && exit 0
        fi
        cmd_umount "$HOST"
        notify-send "Remote" "Unmounted $HOST"
        ;;
      browse)
        HOST="''${2:-}"
        if [ -z "$HOST" ]; then
          HOST=$(list_hosts | wofi --dmenu --prompt "Browse remote:")
          [ -z "$HOST" ] && exit 0
        fi
        case $(cmd_mount "$HOST") in
          mounted|already-mounted)
            yazi "$MOUNT_BASE/$HOST"
            cmd_umount "$HOST" # auto-unmount when yazi closes
            ;;
          failed) notify-send -u critical "Remote" "Failed to mount $HOST" ;;
        esac
        ;;
      list)
        echo "=== Mounted ==="
        list_mounted || echo "(none)"
        echo "=== Available ==="
        list_hosts || echo "(none)"
        ;;
      *)
        echo "Usage: remote <command> [host]"
        echo ""
        echo "Commands:"
        echo "  browse [host]   Mount and open in Yazi, auto-unmount on exit"
        echo "  mount  [host]   Mount host (stays mounted)"
        echo "  umount [host]   Unmount a host"
        echo "  list            Show mounted and available hosts"
        ;;
    esac
  '';

in {
  home.packages = with pkgs; [
    remote
  ];

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";

    settings = {
      manager = {
        show_hidden = true;
        sort_by = "natural";
      };
    };

    keymap = {
      manager.prepend_keymap = [
        {
          on = [ "M" ];
          run = "shell 'gio mount sftp://\${1:?Enter host} --block' --block";
          desc = "Mount SFTP server via GNOME";
        }
        {
          on = [ "g" "v" ];
          run = "cd /run/user/1000/gvfs";
          desc = "Go to GVfs mounts";
        }
      ];
    };
  };
}
