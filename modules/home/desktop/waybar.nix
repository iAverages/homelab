{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.waybar;
in {
  config = lib.mkIf cfg.enable {
    programs.waybar.package = pkgs.waybar.overrideAttrs (oldAttrs: {
      meson = oldAttrs.mesonFlags ++ ["-Dexperimental=true"];
    });
  };
}
