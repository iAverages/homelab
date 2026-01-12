{
  config,
  lib,
  ...
}: let
  cfg = config.services.scanner;
in {
  options.services.scanner.enable = lib.mkEnableOption "scanner";

  config = lib.mkIf cfg.enable {
    hardware.sane.enable = true;
    users.users.dan.extraGroups = ["scanner" "lp"];
  };
}
