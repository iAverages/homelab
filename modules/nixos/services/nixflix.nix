{
  lib,
  config,
  ...
}: let
  cfg = config.services.nixflix;
in {
  options.services.nixflix = {
    enable = lib.mkEnableOption "nixflix";
  };

  config = lib.mkIf cfg.enable {
    nixflix = {
      enable = true;
      mediaDir = "/opt/nixflix/media";
      stateDir = "/opt/nixflix/.state";

      nginx = {
        enable = true;
        addHostsEntries = true;
      };

      postgres.enable = true;

      sonarr = {
        enable = true;
        config = {
          apiKey._secret = config.sops.secrets."sonarr/api_key".path;
          hostConfig.password._secret = config.sops.secrets."sonarr/password".path;
        };
      };

      radarr = {
        enable = true;
        config = {
          apiKey._secret = config.sops.secrets."radarr/api_key".path;
          hostConfig.password._secret = config.sops.secrets."radarr/password".path;
        };
      };

      recyclarr = {
        enable = true;
        #cleanupUnmanagedProfiles = true;
      };

      lidarr = {
        enable = true;
        config = {
          apiKey._secret = config.sops.secrets."lidarr/api_key".path;
          hostConfig.password._secret = config.sops.secrets."lidarr/password".path;
        };
      };

      prowlarr = {
        enable = false;
        config = {
          apiKey._secret = config.sops.secrets."prowlarr/api_key".path;
          hostConfig.password._secret = config.sops.secrets."prowlarr/password".path;

          indexers = [
          ];
        };
      };

      jellyfin = {
        enable = true;
        apiKey._secret = config.sops.secrets."jellyfin/api_key".path;
        users = {
          admin = {
            mutable = false;
            policy.isAdministrator = true;
            password._secret = config.sops.secrets."jellyfin/dan_password".path;
          };
        };
      };

      seerr = {
        enable = true;
        apiKey._secret = config.sops.secrets."seerr/api_key".path;
      };

      vpn = {
        # TODO
        enable = false;

        wgConfFile = config.sops.secrets."wireguard/conf".path;
        accessibleFrom = ["192.168.1.0/24"];
      };
    };
  };
}
