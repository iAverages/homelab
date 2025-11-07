{
  lib,
  config,
  ...
}: let
  cfg = config.homelab.prometheus-stack;
  inherit (lib) types;
in {
  options.homelab.monitoring.prometheus-stack = {
    enable = lib.mkOption {
      type = types.bool;
      default = false;
    };
  };

  config.services.k3s = lib.mkIf cfg.enable {
    autoDeployCharts.prometheus-stack = {
      name = "kube-prometheus-stack";
      repo = "https://prometheus-community.github.io/helm-charts";
      version = "79.2.1";
      hash = "";
      targetNamespace = "monitoring";
      createNamespace = true;
    };
  };
}
