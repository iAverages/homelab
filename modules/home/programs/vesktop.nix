{
  config,
  lib,
  ...
}: let
  cfg = config.programs.vesktop;
in {
  config = lib.mkIf cfg.enable {
    programs.vesktop.settings = {
      frameless = true;
      autoUpdate = false;
      autoUpdateNotification = false;
      notifyAboutUpdates = false;
    };
  };
}
