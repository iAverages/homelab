{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.chromium;
in {
  config = lib.mkIf cfg.enable {
    programs.chromium = {
      package = pkgs.google-chrome;
      commandLineArgs = [
        "--enable-features=VaapiVideoDecoder,VaapiOnNvidiaGPUs,VaapiIgnoreDriverChecks,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL"
        "--ignore-gpu-blocklist"
      ];
    };
  };
}
