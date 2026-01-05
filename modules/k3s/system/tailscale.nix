{
  lib,
  config,
  ...
}: let
  cfg = config.homelab.tailscale;
  inherit (lib) types;
in {
  options.homelab.tailscale = {
    enable = lib.mkEnableOption "tailscale";
    oauth = {
      clientId = lib.mkOption {type = types.str;};
      clientSecret = lib.mkOption {type = types.str;};
    };
  };

  config.services.k3s = lib.mkIf cfg.enable {
    autoDeployCharts.tailscale = {
      name = "tailscale-operator";
      repo = "https://pkgs.tailscale.com/helmcharts";
      version = "1.92.4";
      hash = "sha256-pkgolk7ji3lEilTlL12BnaIpXtEIVt4MiUFKouH8fcM=";
      targetNamespace = "tailscale";
      createNamespace = true;

      values = {
        apiServerProxyConfig.mode = true;
        operatorConfig = {
          hostname = "${config.networking.hostName}-operator";
        };
      };
    };
    secrets = [
      {
        metadata = {
          name = "operator-oauth";
          namespace = "tailscale";
        };
        stringData = {
          client_id = cfg.oauth.clientId;
          client_secret = cfg.oauth.clientSecret;
        };
      }
    ];
  };
}
