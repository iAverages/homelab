{
  config,
  pkgs,
  ...
}: let
  publicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAUqxOzmjOS0TmJkoV9SQtzo2iOt1JzFJsg84KhPshGb me@danielraybone.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHMR9EAOYgfjDJ6knl8kepEdIMyYOpX5bQhaXDiybX9W kirsi-wsl@danielraybone.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDjFLBWuH4DV86tNNmGP2ADurDLrLPtO3bCX5U6YElxs izanami@danielraybone.com"
  ];
in {
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  users.users.root.openssh.authorizedKeys.keys = publicKeys;

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets = {
      danPassword = {};
      danPasswordNoHash = {};
      tailscaleAuthKey = {};
      tailscaleClientId = {};
      tailscaleClientSecret = {};
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

  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets.tailscaleAuthKey.path;
  };

  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  users.users.dan = {
    isNormalUser = true;
    description = "dan";
    extraGroups = ["networkmanager" "wheel"];
    hashedPasswordFile = config.sops.secrets.danPassword.path;
    openssh.authorizedKeys.keys = publicKeys;
  };

  homelab = {
    enable = true;
    domain = "kirsi.dev";
    glance.enable = true;
    # glance.domain = "glance.kirsi.dev";
    tailscale = {
      enable = true;
      oauth = {
        clientId = config.sops.placeholder.tailscaleClientId;
        clientSecret = config.sops.placeholder.tailscaleClientSecret;
      };
    };
    traefik = {
      ip = "46.224.203.151";
      tls = {
        crt = config.sops.placeholder.tlsCrt;
        key = config.sops.placeholder.tlsKey;
      };
    };
  };

  networking = {
    hostName = "eu02";
    firewall = {
      allowedTCPPorts = [22 443 6443];
    };
    # hostId = "b1ba14e8";
    useDHCP = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
  };

  system.stateVersion = "23.11";
}
