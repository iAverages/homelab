{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.homelab.garage;
  inherit (lib) types;
  downloadHelmChartFromUrl = {
    repo,
    chartHash ? lib.fakeHash,
  }:
    pkgs.stdenv.mkDerivation {
      name = "garage-helm-chart.tgz";
      nativeBuildInputs = [pkgs.cacert];
      phases = ["installPhase"];
      src = builtins.fetchTarball {
        url = repo;
        sha256 = chartHash;
      };
      installPhase = ''
        # find top level
        local_src_dir="$src"
        if [ -d "$src/$(ls -A "$src" | head -n 1)" ] && [ "$(ls -A "$src" | wc -l)" -eq 1 ]; then
          local_src_dir="$src/$(ls -A "$src" | head -n 1)"
        fi

        ${pkgs.gnutar}/bin/tar -zcvf garage.tar.gz -C $local_src_dir .
        cp garage.tar.gz "$out"
      '';
    };
in {
  options.homelab.garage = {
    enable = lib.mkOption {
      type = types.bool;
      default = false;
    };
    rpcSecret = lib.mkOption {
      type = types.path;
    };
    apiHost = lib.mkOption {
      type = types.str;
    };
    webHost = lib.mkOption {
      type = types.str;
    };
  };

  config.services.k3s = lib.mkIf cfg.enable {
    autoDeployCharts.garage = {
      package = downloadHelmChartFromUrl {
        repo = "https://git.deuxfleurs.fr/Deuxfleurs/garage/archive/4b1fdbef55ee6a6bd68e904aa91863e7c3289555:script/helm/garage.tar.gz";
        chartHash = "sha256:1sv5zgh3vzqqzc0ij0wbk3mdwz565vgvkikqgwqxc4mv7wkvz45c";
      };
      targetNamespace = "garage";
      createNamespace = true;

      values = {
        garage = {
          replicationMode = "1";
          rpcSecretName = "garage-rpc-secret";
          s3 = {
            api = {
              region = "garage";
              rootDomain = ".s3.dan.local";
            };
          };
        };
        persistence = {
          enable = true;
          meta = {
            storageClassName = "local-path";
            hostPath = "/opt/kubernetes/garage/meta";
          };

          data = {
            storageClassName = "local-path";
            hostPath = "/opt/data/garage";
          };
        };
        deployment = {
          replicaCount = 1;
        };
        ingress.s3 = {
          api = {
            enable = true;
            className = "traefik";
            hosts = [
              {
                host = cfg.apiHost;
              }
            ];
          };
          web = {
            enable = true;
            className = "traefik";
            hosts = [
              {
                host = cfg.webHost;
              }
            ];
          };
        };
        monitoring.metrics = {
          enabled = true;
          serviceMonitor = {
            enabled = true;
          };
        };
      };
    };
    secrets = [
      {
        metadata = {
          name = "garage-rpc-secret";
          namespace = "garage";

          # "trick" the helm chart into thinking it created the secret
          annotations = {
            "meta.helm.sh/release-name" = "garage";
            "meta.helm.sh/release-namespace" = "garage";
          };
          labels = {
            "app.kubernetes.io/managed-by" = "Helm";
          };
        };
        stringData = {
          rpcSecret = cfg.rpcSecret;
        };
      }
    ];
  };
}
