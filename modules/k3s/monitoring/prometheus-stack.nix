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
    discordWebhookUrl = lib.mkOption {
      type = types.nullOr types.str;
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
        alertmanager = {
          extraSecret = {name = "alertmanager-config-secrets";};
          config = {
            receivers = [
              {name = "null";}
              {
                name = "default";
                discord_configs = [
                  {
                    webhook_url = "\${DISCORD_WEBHOOK_URL}";
                    content = "\<@307952129958477824>";
                  }
                ];

                # email_configs = [
                #   {
                #     to = "kurumi-alerts@danielraybone.com";
                #     send_resolved = true;
                #     html = true;
                #   }
                # ];
              }
            ];
            global = {resolve_timeout = "5m";};
            inhibit_rules = [
              {
                source_matchers = ["severity = critical"];
                target_matchers = ["severity =~ warning|info"];
                equal = ["namespace" "alertname"];
              }
              {
                source_matchers = ["severity = warning"];
                target_matchers = ["severity = info"];
                equal = ["namespace" "alertname"];
              }
              {
                source_matchers = ["alertname = InfoInhibitor"];
                target_matchers = ["severity = info"];
                equal = ["namespace"];
              }
              {target_matchers = ["alertname = InfoInhibitor"];}
            ];
            route = {
              group_by = ["job"];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "1h";
              receiver = "default";
              routes = [
                {
                  receiver = "null";
                  matchers = ["alertname = \"Watchdog\""];
                }
              ];
            };

            templates = ["/etc/alertmanager/config/*.tmpl"];
          };
        };

        grafana = {
          admin.existingSecret = "grafana-admin-password";
          initChownData.enabled = false;
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
      {
        name = "alertmanager-config-secrets";
        namespace = "monitoring";
        data = {
          DISCORD_WEBHOOK_URL = cfg.discordWebhookUrl;
        };
      }
    ];
  };
}
