{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.jellyfin-mpv-shim;
in {
  config = lib.mkIf cfg.enable {
    services.jellyfin-mpv-shim.settings = {
      mpv_ext = true;
      mpv_ext_path = lib.getExe pkgs.mpv;
      mpv_ext_no_ovr = true;
    };
  };
}
