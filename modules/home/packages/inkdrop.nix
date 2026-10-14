{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  cups,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libsecret,
  libxkbcommon,
  nss,
  systemd,
  xorg,
}:
stdenv.mkDerivation rec {
  pname = "inkdrop";
  version = "6.1.5";

  src = fetchurl {
    url = "https://dist.inkdrop.app/releases/inkdrop-${version}-amd64-linux.deb";
    hash = "sha256-iI5NVLqem2JFsi8cGXgNjaq7Yq3GIP5wObC6xo7INxk=";
  };

  nativeBuildInputs = [dpkg autoPatchelfHook makeWrapper wrapGAppsHook3];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    cups
    gtk3
    libdrm
    libgbm
    libsecret
    libxkbcommon
    nss
    xorg.libXdamage
    xorg.libXrandr
    xorg.libxkbfile
  ];

  autoPatchelfIgnoreMissingDeps = ["libc.musl-x86_64.so.1"];
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib $out/share
    cp -r opt/Inkdrop $out/lib/inkdrop
    cp -r usr/share/applications usr/share/icons $out/share/
    substituteInPlace $out/share/applications/inkdrop.desktop \
      --replace-fail "Exec=/opt/Inkdrop/inkdrop" "Exec=$out/bin/inkdrop"
    makeShellWrapper $out/lib/inkdrop/inkdrop $out/bin/inkdrop \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [libGL systemd]} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland}}"
    runHook postInstall
  '';

  meta = {
    description = "Markdown note-taking app";
    homepage = "https://www.inkdrop.app";
    license = lib.licenses.unfree;
    mainProgram = "inkdrop";
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
  };
}
