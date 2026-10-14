{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.yt-dlp;
in {
  config = lib.mkIf cfg.enable {
    home.packages = [pkgs.ffmpeg];
  };
}
