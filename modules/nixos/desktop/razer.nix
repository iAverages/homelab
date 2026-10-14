{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.hardware.openrazer;
in {
  config = lib.mkIf cfg.enable {
    hardware.openrazer = {
      users = ["dan"];
      batteryNotifier.enable = false;
    };
    environment.systemPackages = [pkgs.polychromatic];
  };
}
