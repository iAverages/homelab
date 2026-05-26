{
  lib,
  config,
  ...
}: let
  cfg = config.services.nixflix;
  vpnAll = false;
in {
  options.services.nixflix = {
    enable = lib.mkEnableOption "nixflix";
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = {
      allowedTCPPorts = [80];
    };
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
        vpn.enable = vpnAll;
        config = {
          apiKey._secret = config.sops.secrets."sonarr/api_key".path;
          hostConfig.password._secret = config.sops.secrets."sonarr/password".path;
          delayProfiles = [
            {
              enableUsenet = false;
              enableTorrent = true;
              preferredProtocol = "torrent";
              usenetDelay = 0;
              torrentDelay = 0;
              bypassIfHighestQuality = true;
              bypassIfAboveCustomFormatScore = false;
              minimumCustomFormatScore = 0;
              order = 2147483647;
              tags = [];
              id = 1;
            }
          ];
        };
      };
      sonarr-anime = {
        enable = true;
        vpn.enable = vpnAll;

        config = {
          apiKey._secret = config.sops.secrets."sonarr/api_key".path;
          hostConfig.password._secret = config.sops.secrets."sonarr/password".path;
          delayProfiles = [
            {
              enableUsenet = false;
              enableTorrent = true;
              preferredProtocol = "torrent";
              usenetDelay = 0;
              torrentDelay = 0;
              bypassIfHighestQuality = true;
              bypassIfAboveCustomFormatScore = false;
              minimumCustomFormatScore = 0;
              order = 2147483647;
              tags = [];
              id = 1;
            }
          ];
        };
      };

      radarr = {
        enable = true;
        vpn.enable = vpnAll;
        config = {
          apiKey._secret = config.sops.secrets."radarr/api_key".path;
          hostConfig.password._secret = config.sops.secrets."radarr/password".path;
        };
      };

      lidarr = {
        enable = true;
        vpn.enable = vpnAll;
        config = {
          apiKey._secret = config.sops.secrets."lidarr/api_key".path;
          hostConfig.password._secret = config.sops.secrets."lidarr/password".path;
          delayProfiles = [
            {
              enableUsenet = false;
              enableTorrent = true;
              usenetDelay = 0;
              torrentDelay = 0;
              bypassIfHighestQuality = true;
              bypassIfAboveCustomFormatScore = false;
              minimumCustomFormatScore = 0;
              order = 2147483647;
              tags = [];
              id = 1;
            }
          ];
        };
      };

      prowlarr = {
        enable = true;
        vpn.enable = vpnAll;

        config = {
          apiKey._secret = config.sops.secrets."prowlarr/api_key".path;
          hostConfig.password._secret = config.sops.secrets."prowlarr/password".path;
          indexers = [
            {
              enable = true;
              name = "Nyaa.si";
              baseUrl = "https://nyaa.si/";
              radarr_compatibility = true;
              lidarr_compatibility = true;
              sonarr_compatibility = true;
            }
          ];
        };
      };

      torrentClients.qbittorrent = {
        enable = true;
        password._secret = config.sops.secrets."qbittorrent/password".path;
        serverConfig = {
          LegalNotice.Accepted = true;
          BitTorrent = {
            Session = {
              AddTorrentStopped = false;
              Port = 45500;
              QueueingSystemEnabled = true;
              SSL.Port = 32380;

              # required for port forwarding from a VPN
              ReannounceWhenAddressChanged = true;
            };
          };
          Session = {
            GlobalDLSpeedLimit = 10240;
            GlobalUPSpeedLimit = 2048;
          };
          Preferences = {
            WebUI = {
              Username = "dan";
              Password_PBKDF2 = "@ByteArray(QsIFptzfizTLc8kS7WxzwQ==:8gRqIshUXfssUclyK2sfUVRZx18r6U1nj3jvCjJJ4udrClxKegxaB1B1T7tSaKV0Geu20D8lRHbqNyVENUNPfQ==)";
            };
            General.Locale = "en";
          };
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
        encoding = {
          allowAv1Encoding = true;
          allowHevcEncoding = true;
          # hardwareAccelerationType = "nvenc";
        };
        system.pluginRepositories = {
          "Jellyfin Stable" = {
            url = "https://repo.jellyfin.org/files/plugin/manifest.json";
            hash = lib.mkForce "1ykrpwya7px7dz4h92994kpqlf5jd429z7r4dckbw13236x5mpbx";
            enabled = true;
          };
        };
      };

      seerr = {
        enable = true;
        apiKey._secret = config.sops.secrets."seerr/api_key".path;
      };

      recyclarr = {
        enable = true;
        cleanupUnmanagedProfiles.enable = true;
      };

      vpn = {
        enable = true;

        wgConfFile = config.sops.secrets."wireguard/conf".path;
        accessibleFrom = ["192.168.1.0/24"];
      };
    };
  };
}
