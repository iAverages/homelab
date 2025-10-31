{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.homelab.paperless;
in {
  options.homelab.paperless = {
    enable = lib.mkEnableOption "paperless";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "paperless." + config.homelab.domain;
    };
  };

  config.services.k3s.autoDeployCharts.paperless = lib.mkIf cfg.enable {
    package = pkgs.lib.downloadHelmChart {
      repo = "https://bjw-s-labs.github.io/helm-charts";
      chart = "app-template";
      version = "4.3.0";
      chartHash = "";
    };
    targetNamespace = "paperless";
    createNamespace = true;

    values = {
      controllers = {
        paperless-ngx = {
          pod = {
            securityContext = {
              fsGroup = 65539;
              fsGroupChangePolicy = "OnRootMismatch";
            };
          };
          containers = {
            app = {
              image = {
                tag = "2.18.4";
                repository = "ghcr.io/paperless-ngx/paperless-ngx";
                digest = "";
              };
              env = {
                PAPERLESS_CONSUMER_POLLING = "5";
                PAPERLESS_OCR_LANGUAGE = "eng";
                PAPERLESS_PORT = "8000";
                PAPERLESS_TIME_ZONE = "Europe/London";
                PAPERLESS_URL = "https://paperless.dan.local";
                PAPERLESS_REDIS = "redis://valkey.paperless.svc.cluster.local";
                PAPERLESS_FILENAME_FORMAT = ''{{ created_year }}/{{ document_type }}/{{ created_year }}-{{ created_month }}-{{ created_day }}_{{ title }}'';
                PAPERLESS_FILENAME_FORMAT_REMOVE_NONE = "true";
                PAPERLESS_CONSUMER_ENABLE_BARCODES = "1";
                PAPERLESS_CONSUMER_ENABLE_ASN_BARCODE = "1";
              };
            };
          };
        };
      };

      service = {
        app = {
          controller = "paperless-ngx";
          ports = {
            http = {
              port = 8000;
            };
          };
        };
      };

      ingress = {
        main = {
          enabled = true;
          className = "internal";
          hosts = [
            {
              host = "paperless.dan.local";
              paths = [
                {
                  path = "/";
                  service = {
                    identifier = "app";
                    port = "http";
                  };
                }
              ];
            }
          ];
        };
      };

      persistence = {
        config = {
          type = "persistentVolumeClaim";
          accessMode = "ReadWriteOnce";
          size = "20Gi";
          globalMounts = [
            {
              subPath = "data";
              path = "/usr/src/paperless/data";
            }
            {
              subPath = "media";
              path = "/usr/src/paperless/media";
            }
          ];
        };
      };
    };
  };
}
# defaultPodOptions:
#   securityContext:
#     fsGroup: 65539
#     fsGroupChangePolicy: OnRootMismatch
#
# controllers:
#   paperless-ngx:
#     containers:
#       app:
#         image:
#           tag: 2.18.4
#           repository: ghcr.io/paperless-ngx/paperless-ngx
#         env:
#           PAPERLESS_CONSUMER_POLLING: 5
#           PAPERLESS_OCR_LANGUAGE: eng
#           PAPERLESS_PORT: 8000
#           PAPERLESS_TIME_ZONE: Europe/London
#           PAPERLESS_URL: https://paperless.dan.local
#           PAPERLESS_REDIS: redis://valkey-primary.default.svc.cluster.local
#  #         PAPERLESS_ENABLE_HTTP_REMOTE_USER: "true"
#           PAPERLESS_FILENAME_FORMAT: "{{ `{{ created_year }}/{{ document_type }}/{{ created_year }}-{{ created_month }}-{{ created_day }}_{{ title }}` }}"
#           PAPERLESS_FILENAME_FORMAT_REMOVE_NONE: "true"
#           PAPERLESS_CONSUMER_ENABLE_BARCODES: 1
#           PAPERLESS_CONSUMER_ENABLE_ASN_BARCODE: 1
#
# service:
#   app:
#     controller: paperless-ngx
#     ports:
#       http:
#         port: 8000
#
# ingress:
#   main:
#     enabled: true
#     className: "internal"
#     hosts:
#       - host: "paperless.dan.local"
#         paths:
#           - path: /
#             service:
#               identifier: app
#               port: http
#
# persistence:
#   config:
#     type: persistentVolumeClaim
#     accessMode: ReadWriteOnce
#     size: 20Gi
#     globalMounts:
#       - subPath: data
#         path: /usr/src/paperless/data
#       - subPath: media
#         path: /usr/src/paperless/media

