{
  config,
  lib,
  ...
}: let
  cfg = config.services.kanata;
in {
  config = lib.mkIf cfg.enable {
    services.kanata.keyboards.internalKeyboard.config = ''
      (defsrc
        esc
        caps
      )

      (deflayer base
        grave
        esc
      )
    '';
  };
}
