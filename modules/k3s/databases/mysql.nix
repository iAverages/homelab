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
      version = "2.2.7";
      hash = "sha256-2I21COh+cCJNU0qTa8vlZEbRpi5BNnRKbMrrhYJjcZE=";
      targetNamespace = "mysql-operator";
      createNamespace = true;
    };
  };
}
