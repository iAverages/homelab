{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.homelab;
in {
  config = lib.mkIf cfg.enable {
    systemd.services.k3s-prune-dangling-manifests = {
      description = "Delete dangling symlinks in k3s manifests dir";
      unitConfig = {
        ConditionPathIsDirectory = "/var/lib/rancher/k3s/server/manifests";
        After = "local-fs.target";
      };

      serviceConfig = {
        Type = "oneshot";
      };

      # Ensure tools are available
      path = [pkgs.findutils pkgs.coreutils];

      script = ''
        set -euo pipefail

        dir="/var/lib/rancher/k3s/server/manifests"

        ${pkgs.findutils}/bin/find -L "$dir" -maxdepth 1 -type l \
          -printf 'Deleting dangling: %p -> %l\n' -delete
      '';
    };

    systemd.paths.k3s-prune-dangling-manifests = {
      wantedBy = ["multi-user.target"];
      pathConfig = {
        Unit = "k3s-prune-dangling-manifests.service";

        PathChanged = "/var/lib/rancher/k3s/server/manifests";
        PathModified = "/var/lib/rancher/k3s/server/manifests";
      };
    };
  };
}
