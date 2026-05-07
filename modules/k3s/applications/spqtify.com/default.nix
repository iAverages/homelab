{
  config,
  lib,
  ...
}: let
  cfg = config.homelab.spqtify;
  inherit (lib) types;
in {
  options.homelab.spqtify = {
    enable = lib.mkEnableOption "spqtify";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "spqtify." + config.homelab.domain;
    };
    b2 = {
      b2_bucket_id = lib.mkOption {type = types.str;};
      b2_application_key_id = lib.mkOption {type = types.str;};
      b2_application_key = lib.mkOption {type = types.str;};
    };
  };

  config.services.k3s = lib.mkIf cfg.enable {
    autoDeployCharts.spqtify = {
      name = "spqtify";
      targetNamespace = "spqtify";
      createNamespace = true;
      repo = "oci://ghcr.io/iaverages/charts/spqtify.com";
      version = "1.0.2";
      hash = "sha256-oLbKeIV+0vfDhyfKfTICK+A7Qxe9yfvE2nlje8SyGQs=";
      values = {
        api = {
          image = {
            tag = "production-2b737132c5d22c059a8dee2076835da5af9828ab";
          };
          existingSecret = "spqtify-api-secrets";
        };

        "embed-image-service" = {
          image = {
            tag = "production-2b737132c5d22c059a8dee2076835da5af9828ab";
          };
        };

        ingress = {
          enabled = true;
          host = cfg.domain;
        };
      };
    };

    secrets = [
      {
        metadata = {
          name = "spqtify-api-secrets";
          namespace = "spqtify";
        };
        stringData = {
          B2_BUCKET_ID = cfg.b2.b2_bucket_id;
          B2_APPLICATION_KEY_ID = cfg.b2.b2_application_key_id;
          B2_APPLICATION_KEY = cfg.b2.b2_application_key;
        };
      }
    ];
  };
}
