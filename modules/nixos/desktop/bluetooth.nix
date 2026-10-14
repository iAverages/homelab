{
  config,
  lib,
  ...
}: let
  cfg = config.hardware.bluetooth;
in {
  config = lib.mkIf (cfg.enable && config.programs.hyprland.enable) {
    hardware.bluetooth = {
      powerOnBoot = true;
      settings.General.Experimental = "true";
    };
    services.blueman.enable = true;
  };
}
