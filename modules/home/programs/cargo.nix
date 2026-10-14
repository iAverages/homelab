{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.cargo;
in {
  config = lib.mkIf cfg.enable {
    programs.cargo.settings.build.rustc-wrapper = "sccache";
    home.packages = [pkgs.sccache];
  };
}
