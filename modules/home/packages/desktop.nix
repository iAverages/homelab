{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.packages.desktop;
  system = pkgs.stdenv.hostPlatform.system;
in {
  options.packages.desktop.enable = lib.mkEnableOption "desktop applications";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      spotify
      libreoffice
      obs-studio
      blueman
      bruno
      gparted
      lens
      feishin
      anki
      obsidian
      jetbrains.datagrip
      jetbrains.webstorm
      sleek
      yaak
      qview
      mpv
      # for fastfetch image preview
      kitty
      playerctl
      libnotify
      networkmanager-openvpn
      networkmanagerapplet
      prismlauncher
      (callPackage ./inkdrop.nix {})
      inputs.visual-diff.packages.${system}.default
      inputs.llm-agents.packages.${system}.chatgpt
      inputs.llm-agents.packages.${system}.claude-desktop
      inputs.llm-agents.packages.${system}.t3code-desktop

      # refused to open on wa

      # refused to open on wayland, use x11 for now
      (protonmail-desktop.overrideAttrs (oldAttrs: {
        postInstall =
          (oldAttrs.postInstall or "")
          + ''
            sed -i \
              's|^Exec=proton-mail %U$|Exec=env XDG_SESSION_TYPE=x11 proton-mail %U|' \
              usr/share/applications/proton-mail.desktop
          '';
      }))
    ];
  };
}
