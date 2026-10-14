{
  config,
  lib,
  ...
}: let
  cfg = config.programs.rofi;
in {
  config = lib.mkIf cfg.enable {
    programs.rofi.theme = ./theme.rasi;
  };
}
