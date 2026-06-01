{config, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.supportedFilesystems = ["zfs"];
  boot.initrd.supportedFilesystems = ["zfs"];
  boot.zfs.requestEncryptionCredentials = true;

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets = {
      danPassword = {};
      danPasswordNoHash = {};
      tailscaleAuthKey = {};
      tailscaleClientId = {};
      tailscaleClientSecret = {};
      "spqtify/b2_bucket_id" = {};
      "spqtify/b2_application_key_id" = {};
      "spqtify/b2_application_key" = {};
      tlsCrt = {
        format = "binary";
        sopsFile = ./secrets/ssl/origin-cert.pem;
      };
      tlsKey = {
        format = "binary";
        sopsFile = ./secrets/ssl/private-key.pem;
      };
    };
    age.sshKeyPaths = ["/root/.ssh/id_ed25519"];
  };

  dan = true;

  homelab = {
    enable = false;
    domain = "kirsi.dev";
    settings.disableServicelb = false;
    glance.enable = true;
    # glance.domain = "glance.kirsi.dev";
    spqtify = {
      enable = true;
      domain = "dev.spqtify.com";
      b2 = {
        b2_bucket_id = config.sops.placeholder."spqtify/b2_bucket_id";
        b2_application_key_id = config.sops.placeholder."spqtify/b2_application_key_id";
        b2_application_key = config.sops.placeholder."spqtify/b2_application_key";
      };
    };
    tailscale = {
      enable = true;
      oauth = {
        clientId = config.sops.placeholder.tailscaleClientId;
        clientSecret = config.sops.placeholder.tailscaleClientSecret;
      };
    };
    traefik = {
      tls = {
        crt = config.sops.placeholder.tlsCrt;
        key = config.sops.placeholder.tlsKey;
      };
    };
  };

  networking = {
    hostId = "c2ecfdd9";
    hostName = "takina";
    useDHCP = false;
    useNetworkd = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [443];
    };
  };

  systemd.network = {
    enable = true;

    networks."10-wan" = {
      matchConfig.MACAddress = "AA:BB:CC:DD:EE:FF";
      address = [
        "88.99.214.224/32"
      ];
      routes = [
        {
          Gateway = "172.31.1.1";
          GatewayOnLink = true;
        }
      ];
    };
  };

  services = {
    config-git-deploy.enable = true;

    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };

    tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets.tailscaleAuthKey.path;
    };
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  boot.loader = {
    efi.canTouchEfiVariables = true;
    systemd-boot.enable = true;
  };

  system.stateVersion = "23.11";
}
