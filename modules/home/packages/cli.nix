{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.packages.cli;
in {
  options.packages.cli.enable = lib.mkEnableOption "cli and development packages";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      jq
      ripgrep
      fd
      killall
      fzf
      stow
      unzip
      inotify-tools
      uutils-coreutils-noprefix
      wget
      eza
      dust
      bat
      btop
      tmux
      tig
      delta
      tokei
      hyperfine
      neovim
      tree-sitter

      # development
      bun
      pnpm
      nodejs_26
      python3
      go
      gcc
      pkg-config
      lua
      luarocks
      openssl
      mariadb
      cargo-info
      stripe-cli
      graphite-cli
      attic-client

      # nix
      nil
      nixd
      alejandra

      # lsp
      vscode-langservers-extracted
      yaml-language-server
      bash-language-server
      lua-language-server
      statix
      ghalint
      stylua

      # kube
      kubectl
      k9s
      kubectx
      tilt
    ];
  };
}
