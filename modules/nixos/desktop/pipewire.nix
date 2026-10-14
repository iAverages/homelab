{
  config,
  lib,
  ...
}: let
  cfg = config.services.pipewire;
in {
  config = lib.mkIf cfg.enable {
    security.rtkit.enable = true;
    services.pipewire = {
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
  };
}
