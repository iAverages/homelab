{lib, ...}: {
  imports = [./prometheus-stack.nix];

  services.k3s.manifests = let
    dashboardDir = ./dashboards;
    dashboards =
      builtins.readDir dashboardDir
      |> builtins.attrNames
      |> builtins.filter (name: lib.hasSuffix ".json" name);

    formatName = name: lib.removeSuffix ".json" name;
  in
    lib.genAttrs dashboards (
      fileName: let
        fullPath = "${dashboardDir}/${fileName}";
        fileContent = builtins.readFile fullPath;
        jsonContent = builtins.fromJSON fileContent;
        dashboardName = formatName fileName;
      in {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          name = "grafana-${dashboardName}-dashboard";
          namespace = "monitoring";
          labels = {
            grafana_dashboard = "1";
          };
        };
        data = {
          "${fileName}" = jsonContent;
        };
      }
    );
}
