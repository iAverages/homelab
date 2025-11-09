{
  lib,
  config,
  ...
}: let
  cfg = config.homelab.pihole;
  inherit (lib) types;
in {
  options.homelab.pihole = {
    enable = lib.mkOption {
      type = types.bool;
      default = false;
    };
    passwordFile = lib.mkOption {type = types.path;};
    dns = lib.mkOption {type = types.str;};
    domain = lib.mkOption {type = types.str;};
    dnsIp = lib.mkOption {type = types.str;};
  };

  config.services.k3s = lib.mkIf cfg.enable {
    autoDeployCharts.pihole = {
      name = "pihole";
      repo = "https://mojo2600.github.io/pihole-kubernetes/";
      version = "2.34.0";
      hash = "sha256-lE3DV9gvVFE2oc8oQh4OV0aftZmTx1iYbNlZBYSzidw=";
      targetNamespace = "pihole";
      createNamespace = true;

      values = {
        image = {
          tag = "2025.11.0";
        };
        DNS1 = "1.1.1.1";
        DNS2 = "1.0.0.1";
        dnsmasq = {
          customDnsEntries = [
            "address=/dan.local/192.168.1.12"
          ];
        };
        admin = {
          enable = true;
          existingSecret = "pihole-admin-password";
          passwordKey = "password";
        };
        persistentVolumeClaim = {
          enabled = true;
          existingClaim = "pihole-pvc";
        };
        serviceWeb = {
          https = {
            enabled = false; # traefik handles https
          };
        };
        ingress = {
          enabled = true;
          ingressClassName = "traefik";
          hosts = [
            cfg.domain
          ];
        };
        serviceDns = {
          loadBalancerIP = cfg.dnsIp;
          annotations = {"metallb.universe.tf/allow-shared-ip" = "pihole-svc";};
          type = "LoadBalancer";
        };
        monitoring = {
          podMonitor = {
            enabled = true;
          };
          sidecar = {
            enabled = true;
          };
        };
        podDnsConfig = {
          nameservers = ["127.0.0.1" "1.1.1.1"];
        };
      };
    };

    manifests = {
      pihole-pv.content = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = {
          name = "pihole-pv";
          namespace = "pihole";
        };
        spec = {
          capacity = {storage = "4Gi";};
          accessModes = ["ReadWriteOnce"];
          storageClassName = "local-path";
          persistentVolumeReclaimPolicy = "Retain";
          hostPath = {path = "/opt/kubernetes/pihole";};
        };
      };
      pihole-pvc.content = {
        apiVersion = "v1";
        kind = "PersistentVolumeClaim";
        metadata = {
          name = "pihole-pvc";
          namespace = "pihole";
        };
        spec = {
          resources = {requests = {storage = "4Gi";};};
          accessModes = ["ReadWriteOnce"];
          storageClassName = "local-path";
          volumeName = "pihole-pv";
        };
      };
    };

monitoring.dashboards = [
      {
        name = "pihole-grafana-dasbhard";
        namespace = "pihole";
        data = {
          "dashboard.json" = ./dashboard.json;
        }
      }
    ];

    secrets = [
      {
        name = "pihole-admin-password";
        namespace = "pihole";
        data = {
          password = cfg.passwordFile;
        };
      }
    ];
  };
}
