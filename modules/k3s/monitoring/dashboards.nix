{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.k3s;
in {
  options.services.k3s.monitoring.dashboards = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          name = lib.mkOption {type = lib.types.str;};
          namespace = lib.mkOption {type = lib.types.nullOr lib.types.str;};
          data = lib.mkOption {
            type = lib.types.attrsOf lib.types.path;
            description = "Attribute set where keys are secret keys and values are paths to files containing the config map values";
          };
        };
      }
    );
    default = [];
  };

  config = lib.mkMerge [
    (lib.mkIf (builtins.length cfg.secrets > 0) {
      systemd.services = lib.listToAttrs (
        lib.map (configMap: {
          name = "k3s-configmap-${configMap.name}";
          value = {
            inherit (configMap) enable;
            description = "k3s config map for ${configMap.name}";
            after = ["k3s.service"];
            requires = ["k3s.service"];
            wantedBy = ["multi-user.target"];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };

            environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
            script = ''
              ${lib.optionalString (configMap.namespace != null) ''
                ${pkgs.kubectl}/bin/kubectl get namespace ${configMap.namespace} >/dev/null 2>&1 || \
                ${pkgs.kubectl}/bin/kubectl create namespace ${configMap.namespace}
              ''}
              ${pkgs.kubectl}/bin/kubectl apply -f - <<EOF
              apiVersion: v1
              kind: ConfigMap
              metadata:
                name: ${configMap.name}
                ${lib.optionalString (configMap.namespace != null) "namespace: ${configMap.namespace}"}
              type: ${configMap.type}
              data:
                ${lib.concatStringsSep "\n  " (
                lib.mapAttrsToList (key: path: "${key}: $(${pkgs.coreutils}/bin/cat ${path} | ${pkgs.coreutils}/bin/base64 -w 0)") configMap.data
              )}
              EOF
            '';
          };
        })
        cfg.secrets
      );
    })
  ];
}
