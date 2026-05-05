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
      version = "1.0.1";
      hash = "sha256-5LOzBWKq4o2E/RdIaQ8k4MwcXzYSQ7eyedncK1adL00=";
      values = {
        api = {
          image = {
            tag = "production-fbac8ad0786ed7b4a69fa234d8db917854dea375";
          };
          existingSecret = "spqtify-api-secrets";
        };

        "embed-image-service" = {
          image = {
            tag = "production-fbac8ad0786ed7b4a69fa234d8db917854dea375";
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
