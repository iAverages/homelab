{
  lib,
  config,
  ...
}: let
  cfg = config.homelab.cnpg;
  inherit (lib) types;
in {
  options.homelab.cnpg = {
    enable = lib.mkOption {
      type = types.bool;
      default = false;
    };
  };

  config.services.k3s = lib.mkIf cfg.enable {
    autoDeployCharts.cnpg = {
      name = "cloudnative-pg";
      repo = "https://cloudnative-pg.github.io/charts";
      version = "0.26.1";
      hash = "";
      targetNamespace = "cnpg";
      createNamespace = true;

      values = {
        monitoring = {
          podMonitorEnabled = true;
          grafanaDashboard.create = true;
        };
      };
    };

    secrets = [
      {
        name = "pihole-admin-password";
        namespace = "pihole";
        data = {
          password = cfg.passwordFile;
        };
      }
    ];
  };
}
