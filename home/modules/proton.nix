{ pkgs, protonCli, ... }:

let
  # Thin wrappers over `proton drive items upload/download` for the
  # "share files between machines" workflow. Verified against the v5.0.1 docs:
  #   upload   SRC [DEST]  --recursive  --if-exists replace|rename|skip
  #   download PATH        --recursive  --dest-dir DIR
  #
  # Note: proton-cli does not compare content. A push re-uploads everything,
  # and --if-exists replace stores the previous version as a revision, so
  # repeated pushes accumulate history (and storage) rather than being a no-op.
  protonPush = pkgs.writeShellScriptBin "proton-push" ''
    set -euo pipefail
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
    if [ -d "$src" ]; then
      exec proton drive items upload --recursive --if-exists replace "$src" "$dest"
    else
      exec proton drive items upload --if-exists replace "$src" "$dest"
    fi
  '';

  protonPull = pkgs.writeShellScriptBin "proton-pull" ''
    set -euo pipefail
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
    exec proton drive items download "$remote" --recursive --dest-dir "$destdir"
  '';
in
{
  home.packages = [
    protonCli      # `proton` — Proton Mail, Drive, Calendar, Contacts (upstream v5.0.1)
    protonPush
    protonPull
  ];
}
