{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab.flux;
  manifest = pkgs.runCommand "flux-install-${pkgs.fluxcd.version}.yaml" {} ''
    ${pkgs.fluxcd}/bin/flux install --export > "$out"
  '';
in {
  options.homelab.flux.enable = lib.mkEnableOption "Flux controllers";

  config.services.k3s.manifests.flux = lib.mkIf cfg.enable {
    target = "flux.yaml";
    source = manifest;
  };
}
