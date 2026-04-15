{
  lib,
  config,
  ...
}: let
  cfg = config.services.syncthing;
in {
  options = lib.mkIf cfg.enable {
    # dont create default ~/Sync folder
    systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

    services.syncthing = {
      openDefaultPorts = true;

      user = "dan";
      group = "users";

      # disable GUI setting changes
      overrideDevices = true;
      overrideFolders = true;
    };
  };
}
