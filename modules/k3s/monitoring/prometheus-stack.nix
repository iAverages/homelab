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
          enabled = true;
          config = {
            receivers = [
              # TODO: setup
              # {
              #   name = "email-receiver";
              #   email_configs = [
              #     {
              #       to = "alerts@danielraybone.com";
              #       from = "no-reply@danielraybone.com";
              #       smarthost = "smtp.example.com:587";
              #       auth_username = {
              #         name = "alertmanager-email-creds";
              #         key = "smtp-username";
              #       };
              #       auth_password = {
              #         name = "alertmanager-email-creds";
              #         key = "smtp-password";
              #       };
              #     }
              #   ];
              # }
              (lib.optionals
                (cfg.discordWebhookUrl != null)
                {
                  name = "discord-receiver";
                  webhook_configs = [
                    {
                      url = {
                        name = "alertmanager-discord-webhook";
                        key = "url";
                      };
                    }
                  ];
                })
            ];
            route = {
              group_by = ["alertname"];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "4h";
              receiver = "default-receiver";
              routes = [
                {
                  match_re = {severity = "critical|warning";};
                  receiver = "email-receiver";
                }
                {
                  match_re = {severity = "critical";};
                  receiver = "discord-receiver";
                }
              ];
            };
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
        name = "alertmanager-discord-webhook";
        namespace = "monitoring";
        data = {
          url = cfg.discordWebhookUrl;
        };
      }
    ];
  };
}
