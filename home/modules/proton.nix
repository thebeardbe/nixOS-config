{ pkgs, protonCli, ... }:

let
  # Thin wrappers over `proton drive items upload/download` for the
  # "share files between machines" workflow. Verified against v5.0.1:
  #   upload   SRC [DEST]  --recursive  --if-exists replace|rename|skip
  #   download PATH        --recursive  --dest-dir DIR
  #
  # proton-cli does not compare content, so a push is not a sync: it
  # re-uploads, and --if-exists replace keeps the old version as a revision.
  #
  # Both wrappers act as the *active* profile: PROTON_PROFILE, or the
  # `profile:` key in ~/.config/proton-cli/config.yaml (default: "default").
  protonPush = pkgs.writeShellApplication {
    name = "proton-push";
    runtimeInputs = [ protonCli ];
    text = ''
      if [ "$#" -lt 2 ]; then
        echo "usage: proton-push <local-path> <remote-folder>" >&2
        echo "" >&2
        echo "Uploads a file or directory to Proton Drive." >&2
        echo "Re-uploading a name keeps the previous version as a revision." >&2
        echo "" >&2
        echo "example: proton-push ./notes /Shared/laptop" >&2
        exit 2
      fi
      src="$1"
      dest="$2"
      # The upload destination must already exist as a folder; create it (and
      # any missing parent) when it is not there.
      if ! proton drive items get "$dest" >/dev/null 2>&1; then
        proton drive items create "$dest"
      fi
      if [ -d "$src" ]; then
        exec proton drive items upload --recursive --if-exists replace "$src" "$dest"
      else
        exec proton drive items upload --if-exists replace "$src" "$dest"
      fi
    '';
  };

  protonPull = pkgs.writeShellApplication {
    name = "proton-pull";
    runtimeInputs = [ pkgs.jq protonCli ];
    text = ''
      if [ "$#" -lt 2 ]; then
        echo "usage: proton-pull <remote-path> <local-dir>" >&2
        echo "" >&2
        echo "Downloads a file or folder from Proton Drive into <local-dir>." >&2
        echo "A folder lands as a directory of its own name inside <local-dir>." >&2
        echo "" >&2
        echo "example: proton-pull /Shared/notes ./incoming" >&2
        exit 2
      fi
      remote="$1"
      destdir="$2"
      mkdir -p "$destdir"
      # A folder needs --recursive; a file with --recursive is refused, so
      # ask the drive what this path is before choosing the flag set.
      kind="$(proton drive items get "$remote" -o json | jq -r '.type')"
      if [ "$kind" = "folder" ]; then
        exec proton drive items download "$remote" --recursive --dest-dir "$destdir"
      else
        exec proton drive items download "$remote" --dest-dir "$destdir"
      fi
    '';
  };
in
{
  home.packages = [
    protonCli      # `proton` — Proton Mail, Drive, Calendar, Contacts (upstream v5.0.1)
    protonPush
    protonPull
  ];
}
