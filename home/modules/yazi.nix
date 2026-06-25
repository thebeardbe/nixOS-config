{ pkgs, ... }:

let
  sshMountSelect = pkgs.writeShellScriptBin "ssh-mount-select" ''
    SSH_CONFIG="$HOME/.ssh/config"
    MOUNT_BASE="/tmp/ssh-mounts"
    mkdir -p "$MOUNT_BASE"

    # Extract host entries from SSH config, excluding wildcards
    HOSTS=$(grep -i "^Host " "$SSH_CONFIG" 2>/dev/null | \
      awk '{for (i=2; i<=NF; i++) print $i}' | \
      grep -v "[*?]" | sort -u)

    if [ -z "$HOSTS" ]; then
      notify-send "SSH Mount" "No SSH hosts found in ~/.ssh/config"
      exit 1
    fi

    # Pick a host via wofi
    HOST=$(echo "$HOSTS" | wofi --dmenu --prompt "Mount remote:")
    [ -z "$HOST" ] && exit 0

    MOUNT_POINT="$MOUNT_BASE/$HOST"
    mkdir -p "$MOUNT_POINT"

    # Check if already mounted
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
      notify-send "SSH Mount" "Opening $HOST..."
    else
      # Mount via sshfs
      notify-send "SSH Mount" "Mounting $HOST..."
      if sshfs "$HOST": "$MOUNT_POINT" \
        -o idmap=user,allow_other,follow_symlinks,reconnect 2>/tmp/ssh-mount-err; then
        notify-send "SSH Mount" "Mounted $HOST at $MOUNT_POINT"
      else
        err=$(cat /tmp/ssh-mount-err)
        notify-send -u critical "SSH Mount" "Failed: $err"
        rmdir "$MOUNT_POINT" 2>/dev/null
        exit 1
      fi
    fi

    # Navigate Yazi to the mount point
    ya emit cd "$MOUNT_POINT"
  '';

  sshUmount = pkgs.writeShellScriptBin "ssh-umount" ''
    MOUNT_BASE="/tmp/ssh-mounts"

    # Find active mounts
    MOUNT_LIST=""
    for d in "$MOUNT_BASE"/*/; do
      [ -d "$d" ] || continue
      if mountpoint -q "$d" 2>/dev/null; then
        HOST=$(basename "$d")
        MOUNT_LIST="$MOUNT_LIST$HOST\n"
      fi
    done

    if [ -z "$MOUNT_LIST" ]; then
      notify-send "SSH Umount" "No active mounts"
      exit 0
    fi

    HOST=$(echo -e "$MOUNT_LIST" | wofi --dmenu --prompt "Unmount:")
    [ -z "$HOST" ] && exit 0

    MOUNT_POINT="$MOUNT_BASE/$HOST"
    fusermount3 -u "$MOUNT_POINT" 2>/dev/null || \
      fusermount -u "$MOUNT_POINT" 2>/dev/null || \
      (sudo umount "$MOUNT_POINT" 2>/dev/null)

    rmdir "$MOUNT_POINT" 2>/dev/null
    notify-send "SSH Umount" "Unmounted $HOST"

    # Go back to home in Yazi
    ya emit cd ~
  '';

  # Upload selected files to remote
  sshUpload = pkgs.writeShellScriptBin "ssh-upload" ''
    MOUNT_BASE="/tmp/ssh-mounts"

    # Find active mounts
    MOUNT_LIST=""
    for d in "$MOUNT_BASE"/*/; do
      [ -d "$d" ] || continue
      if mountpoint -q "$d" 2>/dev/null; then
        HOST=$(basename "$d")
        MOUNT_LIST="$MOUNT_LIST$HOST\n"
      fi
    done

    if [ -z "$MOUNT_LIST" ]; then
      notify-send "SSH Upload" "No active mounts. Mount a host first."
      exit 0
    fi

    HOST=$(echo -e "$MOUNT_LIST" | wofi --dmenu --prompt "Upload to:")
    [ -z "$HOST" ] && exit 0

    MOUNT_POINT="$MOUNT_BASE/$HOST"

    # Copy selected files to the mount (Yazi sets $1, $2, etc. for selections)
    # If we receive args from Yazi, use them; otherwise copy current file
    if [ $# -gt 0 ]; then
      for f in "$@"; do
        cp -r "$f" "$MOUNT_POINT/" 2>/tmp/ssh-cp-err || true
      done
    else
      notify-send "SSH Upload" "No files selected"
      exit 0
    fi

    notify-send "SSH Upload" "Copied to $HOST"
  '';

in {
  home.packages = with pkgs; [
    sshMountSelect
    sshUmount
    sshUpload
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
          run = "shell 'ssh-mount-select'";
          desc = "Mount remote host via SSH";
        }
        {
          on = [ "U" ];
          run = "shell 'ssh-umount'";
          desc = "Unmount remote host";
        }
        {
          on = [ "g" "m" ];
          run = "cd /tmp/ssh-mounts";
          desc = "Go to SSH mounts";
        }
        {
          on = [ "C" ];
          run = ''shell 'ssh-upload "$@"' --confirm'';
          desc = "Copy selected files to remote";
        }
      ];
    };
  };
}
