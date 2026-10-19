{
  config,
  lib,
  ...
}: let
  cfg = config.xdg.mimeApps;
  associate = app: types: lib.genAttrs types (_: app);
in {
  config = lib.mkIf cfg.enable {
    xdg.mimeApps.defaultApplications =
      associate "google-chrome.desktop" [
        "application/pdf"
        "text/html"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ]
      // associate "com.interversehq.qView.desktop" [
        "image/jpeg"
        "image/png"
        "image/gif"
        "image/bmp"
        "image/webp"
        "image/tiff"
        "image/svg+xml"
      ]
      // associate "mpv.desktop" [
        "video/mp4"
        "video/x-matroska"
        "video/webm"
        "video/quicktime"
        "video/x-msvideo"
        "video/mpeg"
        "video/ogg"
        "audio/mpeg"
        "audio/flac"
        "audio/ogg"
        "audio/opus"
        "audio/wav"
        "audio/x-wav"
        "audio/aac"
        "audio/mp4"
      ]
      // associate "writer.desktop" [
        "application/msword"
        "application/rtf"
        "application/vnd.oasis.opendocument.text"
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      ]
      // associate "calc.desktop" [
        "text/csv"
        "application/vnd.ms-excel"
        "application/vnd.oasis.opendocument.spreadsheet"
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      ]
      // associate "impress.desktop" [
        "application/vnd.ms-powerpoint"
        "application/vnd.oasis.opendocument.presentation"
        "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      ]
      // {
        "x-scheme-handler/mailto" = "proton-mail.desktop";
        "x-scheme-handler/discord" = "vesktop.desktop";
      };
  };
}
