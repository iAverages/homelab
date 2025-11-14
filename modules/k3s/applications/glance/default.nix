{
  lib,
  config,
  ...
}: let
  inherit (lib) types;
  cfg = config.homelab.glance;

  glanceConfig = {
    server = {
      assets-path = "/app/assets";
    };
    branding = {
      app-name = "dashboard";
      hide-footer = true;
    };
    theme = {
      background-color = "240 13 14";
      primary-color = "51 33 68";
      negative-color = "358 100 68";
      contrast-multiplier = 1.2;
      disable-picker = true;
      custom-css-file = "/assets/custom-css.css";
    };
    pages = [
      {
        name = "home";
        width = "slim";
        "hide-desktop-navigation" = true;
        "center-vertically" = true;
        columns = [
          {
            size = "small";
            widgets = [
              {
                type = "clock";
                hour-format = "24h";
              }
              {
                type = "server-stats";
                servers = [
                  {
                    type = "local";
                    name = "local";
                    hide-mountpoints-by-default = true;
                    mountpoints = {
                      "/" = {
                        hide = false;
                      };
                      "/opt/data" = {
                        hide = false;
                      };
                    };
                  }
                ];
              }
            ];
          }
          {
            size = "full";
            widgets = [
              {
                type = "monitor";
                cache = "1m";
                title = "Applications";
                sites = [
                  (
                    lib.optionals
                    (config.homelab.pihole.enable && config.homelab.pihole.domain != null)
                    {
                      title = "paperless";
                      url = "https://${config.homelab.paperless.domain}";
                      "check-url" = "http://paperless.paperless.svc.cluster.local:8000";
                      icon = "di:paperless-ngx";
                    }
                  )
                ];
              }
              {
                type = "monitor";
                cache = "1m";
                title = "System";
                sites =
                  [
                    {
                      title = "traefik";
                      url = "https://${config.homelab.traefik.domain}";
                      icon = "di:traefik";
                    }
                    {
                      title = "grafana";
                      url = "https://${config.homelab.monitoring.prometheus-stack.grafanaDomain}";
                      "check-url" = "http://prometheus-stack-grafana.monitoring.svc.cluster.local:80";
                      icon = "di:grafana";
                    }
                    (
                      lib.optionals
                      (config.homelab.pihole.enable && config.homelab.pihole.domain != null)
                      {
                        title = "pi-hole";
                        url = "https://${config.homelab.pihole.domain}/admin";
                        "check-url" = "http://pihole-web.pihole.svc.cluster.local:80/admin";
                        icon = "di:pi-hole";
                      }
                    )
                  ]
                  ++ cfg.additionalSystemServices;
              }
            ];
          }
        ];
      }
    ];
  };

  monitorSchema = lib.mkOption {
    type = types.listOf (
      types.submodule {
        options = {
          title = lib.mkOption {
            type = types.str;
          };
          url = lib.mkOption {
            type = types.str;
          };
          check-url = lib.mkOption {
            type = types.str;
          };
          icon = lib.mkOption {type = types.str;};
        };
      }
    );
    default = [];
  };
in {
  options.homelab.glance = {
    enable = lib.mkEnableOption "glance";
    domain = lib.mkOption {
      type = types.nullOr types.str;
      default = config.homelab.domain;
      description = "Hostname for glance ingress (defaults to <homelab.domain> if domain is set)";
    };
    additionalSystemServices = monitorSchema;
    additionalWebsites = monitorSchema;
  };

  config.services.k3s = lib.mkIf cfg.enable {
    autoDeployCharts.glance = {
      name = "glance";
      repo = "https://rubxkube.github.io/charts/";
      version = "0.0.9";
      hash = "sha256-kET0Lbl7r+hRnxMDOc3GZcahfEjgf2ya+JJgopTMAJQ=";
      targetNamespace = "glance";
      createNamespace = true;
      values.common = {
        name = "glance";
        service = {
          servicePort = 8080;
          containerPort = 8080;
        };
        deployment = {
          port = 8080;
          args = [
            "--config"
            "/mnt/glance.yml"
          ];
        };
        image = {
          repository = "glanceapp/glance";
          tag = "v0.8.3";
          pullPolicy = "IfNotPresent";
        };
        configMap = {
          enabled = true;
          data = [
            {
              name = "config";
              mountPath = "/mnt";
              data = [
                {
                  content = {
                    "glance.yml" = lib.generators.toYAML {} glanceConfig;
                  };
                }
              ];
            }
            {
              name = "custom-css";
              mountPath = "/app/assets";
              data = [
                {
                  content = {
                    "custom-css.css" = ''
                      * {
                        text-transform: lowercase;
                      }

                      .uppercase {
                        text-transform: lowercase !important;
                      }
                    '';
                  };
                }
              ];
            }
          ];
        };
        startupProbeEnabled = true;
        startupProbe = {
          httpGet = {
            path = "/";
            port = 8080;
          };
          initialDelaySeconds = 10;
          periodSeconds = 10;
          timeoutSeconds = 5;
          failureThreshold = 3;
        };
        readinessProbeEnabled = false;
        readinessProbe = {};
        livenessProbeEnabled = false;
        livenessProbe = {};
        persistence = {
          enabled = true;
          volumes = [];
        };
        ingress =
          {
            enabled = cfg.domain != null;
          }
          // lib.optionalAttrs (cfg.domain != null) {
            hostName = cfg.domain;
            ingressClassName = "traefik";
          };
      };
    };
  };
}
