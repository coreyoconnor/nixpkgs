{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  electron,
  alsa-lib,
  gtk3,
  libxshmfence,
  mesa,
  nss,
}:

stdenv.mkDerivation rec {
  pname = "thedesk";
  version = "24.2.1";

  src = fetchurl {
    url = "https://github.com/cutls/TheDesk/releases/download/v${version}/${pname}_${version}_amd64.deb";
    sha256 = "sha256-AdjygNnQ3qQB03cGcQ5EB0cY3XXWLrzfCqw/U8tq1Yo=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    gtk3
    libxshmfence
    mesa
    nss
  ];

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    dpkg-deb -x ${src} ./
  '';

  installPhase = ''
    runHook preInstall

    mv usr $out
    mv opt $out

    # binary is not used and probably vulnerable to CVE(s)
    rm $out/opt/TheDesk/thedesk

    substituteInPlace $out/share/applications/thedesk.desktop \
      --replace '/opt/TheDesk' $out/bin

    makeWrapper ${electron}/bin/electron $out/bin/thedesk \
      --add-flags $out/opt/TheDesk/resources/app.asar

    runHook postInstall
  '';

  meta = with lib; {
    description = "Mastodon/Misskey Client for PC";
    homepage = "https://thedesk.top";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.gpl3Only;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "thedesk";
  };
}
