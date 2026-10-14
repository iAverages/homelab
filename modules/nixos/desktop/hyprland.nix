{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.hyprland;
  system = pkgs.stdenv.hostPlatform.system;
  hypr-pkgs = inputs.hyprland.inputs.nixpkgs.legacyPackages.${system};
  sddm-theme = inputs.silentSDDM.packages.${system}.default.override {
    theme = "rei";
  };
in {
  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      package = inputs.hyprland.packages.${system}.hyprland;
      portalPackage = inputs.hyprland.packages.${system}.xdg-desktop-portal-hyprland;
      xwayland.enable = true;
    };

    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-gnome];
      config.Hyprland.default = ["hyprland" "gtk"];
    };

    nix.settings = {
      substituters = ["https://hyprland.cachix.org"];
      trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
    };

    hardware.graphics = {
      package = hypr-pkgs.mesa;
      enable32Bit = true;
      package32 = hypr-pkgs.pkgsi686Linux.mesa;
    };

    # open keyring on login
    security.pam.services.login.enableGnomeKeyring = true;
    services.gnome.gnome-keyring.enable = true;

    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    environment.systemPackages = [
      pkgs.wl-clipboard
      sddm-theme
      sddm-theme.test
    ];

    # xwayland
    services.xserver = {
      enable = true;
      excludePackages = [pkgs.xterm];
      xkb = {
        layout = "gb";
        variant = "";
      };
    };

    qt.enable = true;
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      enableHidpi = true;
      theme = sddm-theme.pname;
      package = pkgs.kdePackages.sddm;
      extraPackages = sddm-theme.propagatedBuildInputs;
      settings = {
        Wayland.EnableHiDPI = true;
        General = {
          GreeterEnvironment = "QML2_IMPORT_PATH=${sddm-theme}/share/sddm/themes/${sddm-theme.pname}/components/,QT_IM_MODULE=qtvirtualkeyboard";
          InputMethod = "qtvirtualkeyboard";
        };
      };
    };
  };
}
