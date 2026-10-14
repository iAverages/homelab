{
  config,
  lib,
  ...
}: let
  cfg = config.xdg.mimeApps;
in {
  config = lib.mkIf cfg.enable {
    xdg.mimeApps.defaultApplications = {
      "application/pdf" = "google-chrome.desktop";
      "image/jpeg" = "qview.desktop";
      "image/png" = "qview.desktop";
      "image/gif" = "qview.desktop";
      "image/bmp" = "qview.desktop";
      "image/webp" = "qview.desktop";
      "image/tiff" = "qview.desktop";
      "image/svg+xml" = "qview.desktop";
    };
  };
}
