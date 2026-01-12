_: [
  (final: prev: let
    hostsPath = ../../hosts;

    pubKeysByHostname =
      prev.lib.filesystem.listFilesRecursive hostsPath
      |> prev.lib.filter (file: prev.lib.hasSuffix "_ed25519.pub" (toString file))
      |> prev.lib.map (file: {
        name = prev.lib.strings.removeSuffix "_ed25519.pub" (baseNameOf (toString file));
        value = prev.lib.removeSuffix "\n" (builtins.readFile file);
      })
      |> prev.lib.listToAttrs;

    allPublicKeys =
      pubKeysByHostname
      |> builtins.attrValues;

    getPublicKey = hostname:
      builtins.getAttr hostname pubKeysByHostname;
  in {
    lib =
      prev.lib
      // {
        inherit getPublicKey allPublicKeys;
      };
  })
]
