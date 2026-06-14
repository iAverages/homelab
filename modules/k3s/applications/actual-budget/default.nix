{
  lib,
  config,
  ...
}: let
  cfg = config.homelab.actual-budget;
in {
  options.homelab.actual-budget = {
    enable = lib.mkEnableOption "actual-budget";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "budget.${config.homelab.domain}";
    };
  };

  config = lib.mkIf cfg.enable {
    services.k3s = {
      autoDeployCharts.actual-budget = {
        name = "actual-budget";
        repo = " https://kriegalex.github.io/k8s-charts";
        version = "0.2.3";
        hash = "sha256-TsJ2korwemXgQMly9N8SrZGoLOuTkFzdz+L4TvQEAos=";
        targetNamespace = "actual-budget";
        createNamespace = true;

        values = {
          ingress = {
            enabled = true;
            url = cfg.domain;
          };
        };
      };
    };
  };
}
