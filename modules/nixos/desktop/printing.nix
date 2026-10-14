{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.printing;
in {
  config = lib.mkIf cfg.enable {
    services.printing.drivers = with pkgs; [
      cups-filters
      cups-browsed
    ];
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };
}
