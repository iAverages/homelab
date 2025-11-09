{
  config,
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

  config.services.k3s = {
    autoDeployCharts.paperless = lib.mkIf cfg.enable {
      name = "hello-world";
      repo = "https://bjw-s-labs.github.io/helm-charts";
      version = "4.4.0";
      hash = "";
      values = {
        defaultPodOptions = {
          securityContext = {
            fsGroup = 65539;
            fsGroupChangePolicy = "OnRootMismatch";
          };
        };
        controllers = {
          paperless-ngx = {
            containers = {
              app = {
                image = {
                  tag = "2.19.5";
                  repository = "ghcr.io/paperless-ngx/paperless-ngx";
                };
                env = {
                  PAPERLESS_CONSUMER_POLLING = 5;
                  PAPERLESS_OCR_LANGUAGE = "eng";
                  PAPERLESS_PORT = 8000;
                  PAPERLESS_TIME_ZONE = "Europe/London";
                  PAPERLESS_URL = "https://paperless.dan.local";
                  PAPERLESS_REDIS = "redis://valkey-primary.default.svc.cluster.local";
                  PAPERLESS_FILENAME_FORMAT = "{{ `{{ created_year }}/{{ document_type }}/{{ created_year }}-{{ created_month }}-{{ created_day }}_{{ title }}` }}";
                  PAPERLESS_FILENAME_FORMAT_REMOVE_NONE = "true";
                  PAPERLESS_CONSUMER_ENABLE_BARCODES = 1;
                  PAPERLESS_CONSUMER_ENABLE_ASN_BARCODE = 1;
                };
              };
            };
          };
        };
        service = {
          app = {
            controller = "paperless-ngx";
            ports = {http = {port = 8000;};};
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
            existingClaim = "paperless-pvc";
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
    manifests = {
      paperless-pv.content = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = {
          name = "paperless-pv";
          namespace = "paperless";
        };
        spec = {
          capacity = {storage = "20Gi";};
          accessModes = ["ReadWriteOnce"];
          storageClassName = "local-path";
          persistentVolumeReclaimPolicy = "Retain";
          hostPath = {path = "/opt/kubernetes/paperless";};
        };
      };
      paperless-pvc.content = {
        apiVersion = "v1";
        kind = "PersistentVolumeClaim";
        metadata = {
          name = "paperless-pvc";
          namespace = "paperless";
        };
        spec = {
          resources = {requests = {storage = "20Gi";};};
          accessModes = ["ReadWriteOnce"];
          storageClassName = "local-path";
          volumeName = "paperless-pv";
        };
      };
    };
  };
}
