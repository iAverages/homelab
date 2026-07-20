{
  config,
  lib,
  ...
}: let
  cfg = config.homelab.flux;
in {
  options.homelab.flux.enable = lib.mkEnableOption "Flux controllers";

  config.services.k3s.autoDeployCharts.flux-operator = lib.mkIf cfg.enable {
    name = "flux-operator";
    repo = "oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator";
    version = "0.55.0";
    hash = "sha256-NRZDB16X7BpNaP+LCh+50X/1SGt72/h37C27yv45JaI=";
    targetNamespace = "flux-system";
    createNamespace = true;

    extraDeploy = [
      {
        apiVersion = "fluxcd.controlplane.io/v1";
        kind = "FluxInstance";
        metadata = {
          name = "flux";
          namespace = "flux-system";
        };
        spec = {
          distribution = {
            version = "2.8.x";
            registry = "ghcr.io/fluxcd";
          };
          components = [
            "source-controller"
            "kustomize-controller"
            "helm-controller"
            "notification-controller"
          ];
          cluster = {
            type = "kubernetes";
            multitenant = false;
            networkPolicy = true;
            domain = "cluster.local";
          };
        };
      }
    ];
  };
}
