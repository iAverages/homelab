{
  config,
  lib,
  ...
}: let
  cfg = config.programs.nh;
in {
  config = lib.mkIf cfg.enable {
    programs.nh.flake = "${config.home.homeDirectory}/homelab";
  };
}
