{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.framework-16-7040-amd
    ./hardware-configuration.nix
  ];

  networking.hostName = "izanami";

  sops = {
    defaultSopsFile = ../../secrets/personal.yaml;
    age = {
      sshKeyPaths = ["/home/dan/.ssh/izanami_ed25519"];
      keyFile = "/home/dan/.config/sops/age/keys.txt";
    };
    secrets.danPassword.neededForUsers = true;
  };

  nix.package = pkgs.lixPackageSets.stable.lix;

  boot = {
    initrd.systemd.enable = true;
    plymouth.enable = true;
    loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 15;
      efi.canTouchEfiVariables = true;
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # 16GB
    }
  ];

  hardware = {
    bluetooth.enable = true;
  };

  locale.gb.enable = true;
  security.sudo-rs.enable = true;
  security.pki.certificateFiles = [../../secrets/dan-lan-ca.crt];

  networking.cloudflare-dns.enable = true;

  environment.variables.NH_FLAKE = "/home/dan/homelab";

  users.users.dan.shell = pkgs.zsh;

  programs = {
    zsh.enable = true;
    dconf.enable = true;
    hyprland.enable = true;
    thunar.enable = true;
    nix-ld.enable = true;
    gnupg.agent.enable = true;
    steam.enable = true;
  };

  services = {
    tailscale.enable = true;
    mullvad-vpn.enable = true;
    userborn.enable = true;
    pipewire.enable = true;
    kanata.enable = true;
    printing.enable = true;
    fprintd.enable = true;

    dbus = {
      implementation = lib.mkForce "broker";
      packages = [pkgs.dconf];
    };
  };

  virtualisation = {
    docker.enable = true;
    waydroid.enable = true;
  };

  services.udev.packages = [pkgs.via];
  environment.systemPackages = with pkgs; [
    via
    vial
    wine
    # todo: what the fuck
    ((import inputs.nixpkgs-stable {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      }).lutris.override {
        extraLibraries = pkgs: [
          pkgs.gtk4
          pkgs.libadwaita
        ];
      })
  ];
}
