{
  stdenv,
  lib,
  fetchurl,
  appimageTools,
  makeWrapper,
  electron,
  nixosTests,
}:

stdenv.mkDerivation rec {
  pname = "freetube";
  version = "0.21.3";

  src = fetchurl {
    url = "https://github.com/FreeTubeApp/FreeTube/releases/download/v${version}-beta/freetube_${version}_amd64.AppImage";
    hash = "sha256-sg/ycFo4roOJ2sW4naRCE6dwGXVQFzF8uwAZQkS2EY4=";
  };

  passthru.tests = nixosTests.freetube;

  appimageContents = appimageTools.extractType2 {
    name = "${pname}-${version}";
    inherit src;
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/${pname} $out/share/applications $out/share/icons/hicolor/scalable/apps

    cp -a ${appimageContents}/{locales,resources} $out/share/${pname}
    cp -a ${appimageContents}/freetube.desktop $out/share/applications/${pname}.desktop
    cp -a ${appimageContents}/usr/share/icons/hicolor/scalable/freetube.svg $out/share/icons/hicolor/scalable/apps

    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace 'Exec=AppRun' 'Exec=${pname}'

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper ${electron}/bin/electron $out/bin/${pname} \
      --add-flags $out/share/${pname}/resources/app.asar \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--enable-features=UseOzonePlatform --ozone-platform=wayland}}"
  '';

  meta = {
    description = "Open Source YouTube app for privacy";
    homepage = "https://freetubeapp.io/";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [
      ryneeverett
      alyaeanyx
    ];
    inherit (electron.meta) platforms;
    mainProgram = "freetube";
  };
}
