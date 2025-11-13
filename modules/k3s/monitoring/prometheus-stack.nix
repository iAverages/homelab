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
    # TODO: make both of these optional
    discordWebhookUrl = lib.mkOption {
      type = types.str;
    };

    mail = {
      to = lib.mkOption {
        type = types.str;
      };
      from = lib.mkOption {
        type = types.str;
      };
      host = lib.mkOption {
        type = types.str;
      };
      username = lib.mkOption {
        type = types.str;
      };
      password = lib.mkOption {
        type = types.path;
      };
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
        # TODO: figure out how to allow prometheus to discover these services.
        # disable monitoring for these, i believe since they are not
        # deployed as a pod prometheus cannot discover them?
        kubeControllerManager.enable = false;
        kubeScheduler.enable = false;
        kubeProxy.enable = false;
        defaultRules.rules = {
          kubeControllerManager = false;
          kubeSchedulerAlerting = false;
          kubeSchedulerRecording = false;
          kubeProxy = false;
        };

        alertmanager = {
          alertmanagerSpec = {
            alertmanagerConfiguration = {
              name = "alertmanager-config";
            };
          };
          config = {
            global = {resolve_timeout = "5m";};
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

    manifests = {
      alertmanager-config.content = {
        apiVersion = "monitoring.coreos.com/v1alpha1";
        kind = "AlertmanagerConfig";
        metadata = {
          name = "alertmanager-config";
          namespace = "monitoring";
        };
        spec = {
          receivers = [
            {name = "null";}
            {
              name = "default";
              discordConfigs = [
                {
                  apiURL = {
                    name = "alertmanager-config-secrets";
                    key = "DISCORD_WEBHOOK_URL";
                  };
                  content = "<@307952129958477824>";
                  message = ''
                    {{ range .Alerts.Firing }}
                        Alert: **{{ printf "%.150s" .Annotations.summary }}** ({{ .Labels.severity }})
                        Description: {{ printf "%.150s" .Annotations.description }}
                        Alertname: {{ .Labels.alertname }}
                        Namespace: {{ .Labels.namespace }}
                        Service: {{ .Labels.service }}
                    {{ end }}
                    {{ range .Alerts.Resolved }}
                        Alert: **{{ printf "%.150s" .Annotations.summary }}** ({{ .Labels.severity }})
                        Description: {{ printf "%.150s" .Annotations.description }}
                        Alertname: {{ .Labels.alertname }}
                        Namespace: {{ .Labels.namespace }}
                        Service: {{ .Labels.service }}
                    {{ end }}
                  '';
                }
              ];
              emailConfigs = [
                {
                  to = cfg.mail.to;
                  from = cfg.mail.from;
                  smarthost = cfg.mail.host;
                  authUsername = cfg.mail.username;
                  authPassword = {
                    name = "alertmanager-config-secrets";
                    key = "mailPassword";
                  };
                  sendResolved = true;
                  requireTLS = true;
                }
              ];
            }
          ];
          route = {
            receiver = "default";
            groupWait = "30s";
            groupInterval = "5m";
            repeatInterval = "10m";
            routes = [
              {
                receiver = "null";
                matchers = [
                  {
                    name = "alertname";
                    value = "Watchdog";
                    matchType = "=";
                  }
                ];
              }
              {
                receiver = "null";
                matchers = [
                  {
                    name = "alertname";
                    value = "InfoInhibitor";
                    matchType = "=";
                  }
                ];
              }
            ];
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
          mailPassword = cfg.mail.password;
        };
      }
    ];
  };
}
