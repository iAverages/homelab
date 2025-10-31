{...}: {
  imports = [./hardware-configuration.nix];
  networking.hostName = "kirsi";
  networking.firewall = {
    allowedTCPPorts = [22];
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
