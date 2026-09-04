{
  config,
  lib,
  ...
}: let
  cfg = config.services.anki-sync-server;
in {
  config = lib.mkIf cfg.enable {
    services.anki-sync-server.address = "127.0.0.1";
    systemd.services.anki-sync-server.environment.PASSWORDS_HASHED = "1";
    services.tailscale.enable = true;

    # cant use built in nix module since we need https -> http
    systemd.services.anki-sync-tailscale = {
      description = "Expose Anki sync through Tailscale";
      after = ["anki-sync-server.service" "tailscaled-autoconnect.service"];
      requires = ["anki-sync-server.service"];
      wants = ["tailscaled.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe config.services.tailscale.package} serve --yes --service=svc:anki-sync --https=443 http://127.0.0.1:${toString cfg.port}";
        ExecStop = "${lib.getExe config.services.tailscale.package} serve drain svc:anki-sync";
      };
    };
  };
}
