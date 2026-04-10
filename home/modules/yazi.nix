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
        # Voeg hier je custom mounts toe
        {
          on = [ "M" ];
          run = "shell 'gio mount sftp://\${1:?Enter host} --block' --block";
          desc = "Mount SFTP server";
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
