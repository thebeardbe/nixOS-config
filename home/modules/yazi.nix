{ pkgs, ... }:

let
  remote = pkgs.writeShellScriptBin "remote" ''
    set -eo pipefail

    SSH_CONFIG="$HOME/.ssh/config"

    list_hosts() {
      grep -i "^Host " "$SSH_CONFIG" 2>/dev/null | \
        awk "{for (i=2; i<=NF; i++) print \$i}" | \
        grep -v "[*?]" | sort -u
    }

    list_mounted() {
      gio mount -l 2>/dev/null | grep "sftp://" | \
        sed "s/.*sftp:\\/\\/\\([^@]*@\\)\\?\\([^/]*\\).*/\\2/" | sort -u || true
    }

    gvfs_uri() {
      local HOST="$1"
      local USER
      USER=$(grep -A5 "^Host $HOST$" "$SSH_CONFIG" 2>/dev/null | grep -i "user " | awk "{print \$2}") || true
      if [ -z "$USER" ]; then USER="$USER"; fi
      echo "sftp://$USER@$HOST/"
    }

    mount_point() {
      local HOST="$1"
      local USER
      USER=$(grep -A5 "^Host $HOST$" "$SSH_CONFIG" 2>/dev/null | grep -i "user " | awk "{print \$2}") || true
      if [ -z "$USER" ]; then USER="$USER"; fi
      echo "/run/user/$(id -u)/gvfs/sftp:host=$HOST,user=$USER"
    }

    is_mounted() {
      local HOST="$1"
      local MP
      MP=$(mount_point "$HOST")
      [ -d "$MP" ] && ls "$MP" &>/dev/null 2>&1
    }

    cmd_mount() {
      local HOST="$1"
      if is_mounted "$HOST"; then
        echo "already-mounted"
        return 0
      fi
      local URI
      URI=$(gvfs_uri "$HOST")
      if gio mount "$URI" 2>/tmp/remote-mount-err; then
        echo "mounted"
        return 0
      else
        echo "failed"
        return 1
      fi
    }

    cmd_umount() {
      local HOST="$1"
      local URI
      URI=$(gvfs_uri "$HOST")
      gio mount -u "$URI" 2>/dev/null || true
    }

    CMD="$1"
    HOST_ARG="$2"

    case "$CMD" in
      mount)
        HOST="$HOST_ARG"
        if [ -z "$HOST" ]; then
          HOST=$(list_hosts | wofi --dmenu --prompt "Mount remote:")
          [ -z "$HOST" ] && exit 0
        fi
        case $(cmd_mount "$HOST") in
          mounted)         notify-send "Remote" "Mounted $HOST" ;;
          already-mounted) notify-send "Remote" "$HOST already mounted" ;;
          failed)          notify-send -u critical "Remote" "Failed to mount $HOST" ;;
        esac
        ;;
      umount|unmount)
        HOST="$HOST_ARG"
        if [ -z "$HOST" ]; then
          HOST=$(list_mounted | wofi --dmenu --prompt "Unmount:")
          [ -z "$HOST" ] && exit 0
        fi
        cmd_umount "$HOST"
        notify-send "Remote" "Unmounted $HOST"
        ;;
      browse)
        HOST="$HOST_ARG"
        if [ -z "$HOST" ]; then
          HOST=$(list_hosts | wofi --dmenu --prompt "Browse remote:")
          [ -z "$HOST" ] && exit 0
        fi
        case $(cmd_mount "$HOST") in
          mounted|already-mounted)
            yazi "$(mount_point "$HOST")"
            cmd_umount "$HOST"
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
          run = ''shell 'gio mount sftp://$'' + "{1:?Enter host}" + '' --block' --block'';
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
