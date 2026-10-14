{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.nix-ld;
in {
  config = lib.mkIf cfg.enable {
    programs.nix-ld.libraries = with pkgs; [
      zlib
      zstd
      stdenv.cc.cc
      curl
      openssl
      attr
      libssh
      bzip2
      libxml2
      acl
      libsodium
      util-linux
      xz
      systemd
    ];
  };
}
