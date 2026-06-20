{ pkgs, theme, ... }: {
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
        # Press 'M' to mount an SFTP server interactively
        {
          on = [ "M" ];
          run = "shell 'gio mount sftp://\${1:?Enter host} --block' --block";
          desc = "Mount SFTP server";
        }
        # Press 'g' then 'v' to jump to GVfs mount point
        {
          on = [ "g" "v" ];
          run = "cd /run/user/1000/gvfs";
          desc = "Go to GVfs mounts";
        }
      ];
    };
  };
}
