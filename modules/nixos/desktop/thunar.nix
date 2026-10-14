{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.thunar;
in {
  config = lib.mkIf cfg.enable {
    programs.thunar.plugins = with pkgs; [thunar-archive-plugin thunar-volman];
    programs.xfconf.enable = true;
    services.gvfs.enable = true;
    services.tumbler.enable = true;
  };
}
