{
  lib,
  config,
  ...
}: let
  cfg = config.homelab.monitoring.prometheus-stack;
  inherit (lib) types;
in {
  options.homelab.monitoring.prometheus-stack = {
    enable = lib.mkOption {
      type = types.bool;
      default = false;
    };
    grafanaUser = lib.mkOption {
      type = types.str;
      default = "admin";
    };
    grafanaPasswordFile = lib.mkOption {
      type = types.path;
    };
    grafanaDomain = lib.mkOption {
      type = types.nullOr types.str;
      default =
        if config.homelab.domain != null
        then "grafana.${config.homelab.domain}"
        else null;
    };
  };

  config.services.k3s = lib.mkIf cfg.enable {
    autoDeployCharts.prometheus-stack = {
      name = "kube-prometheus-stack";
      repo = "https://prometheus-community.github.io/helm-charts";
      version = "79.2.1";
      hash = "sha256-rUZcfcB+O7hrr2swEARXFujN7VvfC0IkaaAeJTi0mN0=";
      targetNamespace = "monitoring";
      createNamespace = true;
      values = {
        grafana = {
          admin.existingSecret = "grafana-admin-password";
          persistence.enabled = true;
          ingress = {
            enabled = true;
            ingressClassName = "traefik";
            hosts = [
              cfg.grafanaDomain
            ];
          };
        };
        prometheus-node-exporter = {
          prometheusSpec = {
            scrapeInterval = "10s";
          };
        };
        prometheus = {
          prometheusSpec = {
            podMonitorNamespaceSelector.matchLabels = {};
            podMonitorSelectorNilUsesHelmValues = false;
            serviceMonitorNamespaceSelector.matchLabels = {};
            serviceMonitorSelectorNilUsesHelmValues = false;
          };
        };
      };
    };
    secrets = [
      {
        name = "grafana-admin-password";
        namespace = "monitoring";
        data = {
          admin-user = cfg.grafanaUser;
          admin-password = cfg.grafanaPasswordFile;
        };
      }
    ];
  };
}
