{
  config,
  lib,
  ...
}: let
  cfg = config.programs.herdr;
in {
  config = lib.mkIf cfg.enable {
    programs.herdr.settings = {
      keys.prefix = "ctrl+m";
      session.resume_agents_on_restore = false;
      onboarding = false;
      ui.toast.delivery = "system";
      theme = {
        name = "rose-pine";
        auto_switch = false;
      };
    };
  };
}
