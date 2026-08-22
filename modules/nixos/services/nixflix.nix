{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.services.nixflix;
  vpnAll = false;
  slskdDownloads = "${cfg.storagePath}/downloads/slskd";
  lidarrUid = toString config.nixflix.globals.uids.lidarr;
  mediaGid = toString config.nixflix.globals.gids.media;
  qbittorrentWebUi = "http://192.168.15.1:8282/";
  waitForQbittorrent = "${pkgs.curl}/bin/curl --retry 30 --retry-delay 2 --retry-connrefused -fsS -o /dev/null ${qbittorrentWebUi}";
in {
  options.services.nixflix = {
    enable = lib.mkEnableOption "nixflix";
    storagePath = lib.mkOption {
      type = lib.types.str;
      default = "/opt/nixflix";
    };
    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/opt/nixflix-state";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.templates = {
      "slskd.env" = {
        owner = "slskd";
        content = ''
          SLSKD_SLSK_USERNAME=${config.sops.placeholder."slskd/username"}
          SLSKD_SLSK_PASSWORD=${config.sops.placeholder."slskd/password"}
          SLSKD_USERNAME=dan
          SLSKD_PASSWORD=${config.sops.placeholder."jellyfin/dan_password"}
          SLSKD_API_KEY=${config.sops.placeholder."slskd/api_key"}
        '';
      };
      "navidrome.env" = {
        owner = "navidrome";
        content = ''
          ND_LASTFM_APIKEY=${config.sops.placeholder."lastfm/api_key"}
          ND_LASTFM_SECRET=${config.sops.placeholder."lastfm/secret"}
        '';
      };
      "soularr/config.ini" = {
        mode = "0440";
        group = "media";
        content = ''
          [Lidarr]
          api_key = ${config.sops.placeholder."lidarr/api_key"}
          host_url = http://127.0.0.1:8686
          download_dir = ${slskdDownloads}
          disable_sync = False

          [Slskd]
          api_key = ${config.sops.placeholder."slskd/api_key"}
          host_url = http://${config.vpnNamespaces.wg.namespaceAddress}:5030
          url_base = /
          download_dir = /downloads
          delete_searches = False
          stalled_timeout = 3600
          remote_queue_timeout = 300

          [Release Settings]
          use_selected_lidarr_release = False
          use_most_common_tracknum = True
          allow_multi_disc = True
          accepted_countries = Europe,Japan,United Kingdom,United States,[Worldwide],Australia,Canada
          skip_region_check = False
          accepted_formats = CD,Digital Media,Vinyl

          [Search Settings]
          search_timeout = 5000
          maximum_peer_queue = 50
          minimum_peer_upload_speed = 0
          minimum_filename_match_ratio = 0.8
          minimum_search_interval = 5
          allowed_filetypes = flac 24/192,flac 16/44.1,flac,mp3 320,mp3
          album_prepend_artist = False
          search_type = incrementing_page
          number_of_albums_to_grab = 10
          search_source = missing
          failed_import_denylist = True

          [Download Settings]
          download_filtering = True
          use_extension_whitelist = False
          extensions_whitelist = lrc,nfo,txt
          rename_download_folders = True

          [Logging]
          level = INFO
          format = [%(levelname)s|%(module)s|L%(lineno)d] %(asctime)s: %(message)s
          datefmt = %Y-%m-%dT%H:%M:%S%z
          log_to_file = True
          log_file = soularr.log
          max_bytes = 1048576
          backup_count = 3
        '';
      };
    };

    networking.firewall = {
      allowedTCPPorts = [80];
    };

    services.slskd = {
      enable = true;
      group = "media";
      domain = "slskd.nixflix";
      environmentFile = config.sops.templates."slskd.env".path;
      settings = {
        directories = {
          downloads = slskdDownloads;
          incomplete = "${slskdDownloads}/incomplete";
        };
        shares = {
          directories = ["[Music]${cfg.storagePath}/media/music"];
          cache.retention = 60;
        };
        transfers = {
          download.speed_limit = 6103;
          upload.speed_limit = 2441;
        };
        web.ip_address = config.vpnNamespaces.wg.namespaceAddress;
      };
    };

    services.nginx.virtualHosts."slskd.nixflix".locations."/".proxyPass =
      lib.mkForce "http://${config.vpnNamespaces.wg.namespaceAddress}:5030";

    vpnNamespaces.wg.portMappings = [
      {
        from = 5030;
        to = 5030;
        protocol = "tcp";
      }
    ];

    virtualisation.oci-containers = {
      backend = "podman";
      containers.soularr = {
        image = "docker.io/mrusse08/soularr:v1.2.2@sha256:c4f97924fabfce4e0de539d821ea7d20519b95c4815a707bacfc9d7212597f20";
        user = "${lidarrUid}:${mediaGid}";
        environment = {
          SCRIPT_INTERVAL = "300";
          TZ = "Etc/UTC";
          WEBUI_ENABLED = "false";
        };
        volumes = [
          "${slskdDownloads}:/downloads"
          "${cfg.stateDir}/soularr:/data"
          "${config.sops.templates."soularr/config.ini".path}:/data/config.ini:ro"
        ];
        extraOptions = ["--network=host"];
      };
    };

    systemd.tmpfiles.rules = [
      "d ${slskdDownloads} 2775 slskd media -"
      "d ${slskdDownloads}/incomplete 2775 slskd media -"
      "d ${cfg.stateDir}/soularr 0750 ${lidarrUid} ${mediaGid} -"
    ];

    nixflix = {
      enable = true;
      mediaDir = "${cfg.storagePath}/media";
      downloadsDir = "${cfg.storagePath}/downloads";
      stateDir = cfg.stateDir;

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

      navidrome = {
        enable = true;
        environmentFile = config.sops.templates."navidrome.env".path;
        users.dan = {
          userName = "dan";
          isAdmin = true;
          mutable = false;
          password._secret = config.sops.secrets."jellyfin/dan_password".path;
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
          allowAv1Encoding = false;
          allowHevcEncoding = true;
          enableHardwareEncoding = true;
          hardwareAccelerationType = "nvenc";
          enableTonemapping = true;
        };
        system.trickplayOptions.enableHwEncoding = true;
        system.pluginRepositories = {
          "Jellyfin Stable Plugin Repo".enabled = lib.mkForce false;

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
        openVPNPorts = [
          {
            port = 50300;
            protocol = "tcp";
          }
        ];
      };
    };

    systemd.services =
      lib.genAttrs [
        "sonarr-downloadclients"
        "sonarr-anime-downloadclients"
        "radarr-downloadclients"
        "lidarr-downloadclients"
        "prowlarr-downloadclients"
      ] (_: {
        serviceConfig.ExecStartPre = lib.mkAfter [waitForQbittorrent];
      })
      // {
        wg = {
          unitConfig.Upholds = "qbittorrent.service";
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = "30s";
          };
        };
        qbittorrent.serviceConfig = {
          Restart = "always";
          RestartSec = "5s";
        };
        lidarr.serviceConfig.ExecStartPre = lib.mkBefore [
          "+${pkgs.coreutils}/bin/chgrp -R media ${cfg.storagePath}/media/music"
          "+${pkgs.coreutils}/bin/chmod -R g+rwX ${cfg.storagePath}/media/music"
        ];
        slskd = {
          vpnConfinement = {
            enable = true;
            vpnNamespace = "wg";
          };
          serviceConfig.UMask = "0002";
        };
        podman-soularr = {
          after = ["lidarr.service" "slskd.service"];
          requires = ["lidarr.service" "slskd.service"];
        };
      };
  };
}
