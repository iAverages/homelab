{
  lib,
  config,
  ...
}: let
  cfg = config.homelab.mysql;
  inherit (lib) types;
in {
  options.homelab.mysql = {
    enable = lib.mkOption {
      type = types.bool;
      default = false;
    };
  };

  config.services.k3s = lib.mkIf cfg.enable {
    autoDeployCharts.mysql-operator = {
      name = "mysql-operator";
      repo = "https://mysql.github.io/mysql-operator/";
      version = "2.2.8";
      hash = "sha256-NeMklciKcD6oXYbOvjBcdzJjnpmBg3rSrs7wSTosuqQ=";
      targetNamespace = "mysql-operator";
      createNamespace = true;
    };
  };
}
