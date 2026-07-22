{
  config,
  lib,
  ...
}: let
  cfg = config.services.tailscale;
in {
  config = lib.mkIf cfg.enable {
    services.tailscale.extraUpFlags = ["--ssh"];
    networking = {
      firewall = {
        trustedInterfaces = ["tailscale0"];
        allowedUDPPorts = [config.services.tailscale.port];
      };
    };
  };
}
