{config, ...}: {
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAUqxOzmjOS0TmJkoV9SQtzo2iOt1JzFJsg84KhPshGb me@danielraybone.com"
  ];

  sops.secrets = {
    "pihole/password" = {};
  };

  homelab = {
    enable = true;
    domain = "dan.local";
    metallb.addresses = ["192.168.1.11-192.168.1.149"];
    pihole = {
      dnsIp = "192.168.1.11";
      domain = "pihole.dan.local";
      passwordFile = config.sops.secrets."pihole/password".path;
    };
  };

  networking.hostName = "kurumi";
  networking.firewall = {
    allowedTCPPorts = [22 443 50];
  };

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";
  nixpkgs.hostPlatform = "x86_64-linux";

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        devices = ["nodev"];
      };
    };
  };

  system.stateVersion = "23.11";
}
