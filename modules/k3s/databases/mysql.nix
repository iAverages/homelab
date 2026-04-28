{
  lib,
  config,
  ...
}: let
  cfg = config.homelab.cnpg;
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
      version = "0.26.1";
      hash = "sha256-hkaaSse56AZgLX4ORajhfwjXyifMVbRdWwhOCE6koHU=";
      targetNamespace = "mysql-operator";
      createNamespace = true;
    };
  };
}
