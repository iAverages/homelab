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
    manifests.pihole-dashboard.content = {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = "my-configmap";
        labels = {app = "my-application";};
      };
      data = {
        "config.file" = "# This is a sample configuration file\nsetting1=value1\nsetting2=value2\n";
        "another.key" = "Hello from ConfigMap!";
      };
    };

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
