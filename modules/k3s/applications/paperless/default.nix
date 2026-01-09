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

  config.services.k3s = lib.mkIf cfg.enable {
    autoDeployCharts.paperless = {
      name = "app-template";
      targetNamespace = "paperless";
      createNamespace = true;
      repo = "https://bjw-s-labs.github.io/helm-charts";
      version = "4.4.0";
      hash = "sha256-D9Wl/b+V8ydYwcsYsgMdrLp+tvVTq8tc18N7k8elvQ0=";
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
                  PAPERLESS_URL = "https://${cfg.domain}";
                  PAPERLESS_REDIS = "redis://paperless-dragonfly.paperless.svc.cluster.local";
                  PAPERLESS_FILENAME_FORMAT = "{{ `{{ created_year }}/{{ document_type }}/{{ created_year }}-{{ created_month }}-{{ created_day }}_{{ title }}` }}";
                  PAPERLESS_FILENAME_FORMAT_REMOVE_NONE = "true";
                  PAPERLESS_CONSUMER_ENABLE_BARCODES = "true";
                  PAPERLESS_CONSUMER_ENABLE_ASN_BARCODE = "true";
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
            className = "traefik";
            hosts = [
              {
                host = cfg.domain;
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
      paperless-dragonfly.content = {
        apiVersion = "dragonflydb.io/v1alpha1";
        kind = "Dragonfly";
        metadata = {
          name = "paperless-dragonfly";
          namespace = "paperless";
        };
        spec = {
          replicas = 1;
          resources = {
            requests = {
              cpu = "500m";
              memory = "500Mi";
            };
            limits = {
              cpu = "600m";
              memory = "750Mi";
            };
          };
        };
      };
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
