{
  buildGoModule,
  fetchFromGitHub,
  lib,
  stdenv,
  gawk,
}:

buildGoModule rec {
  pname = "goawk";
  version = "1.28.0";

  src = fetchFromGitHub {
    owner = "benhoyt";
    repo = "goawk";
    rev = "v${version}";
    hash = "sha256-3i8czhGFk8XqYaenKTmsvXt2kRSss++rS6amLxfM2DE=";
  };

  vendorHash = null;

  nativeCheckInputs = [ gawk ];

  postPatch = ''
    substituteInPlace goawk_test.go \
      --replace "TestCommandLine" "SkipCommandLine" \
      --replace "TestDevStdout" "SkipDevStdout" \
      --replace "TestFILENAME" "SkipFILENAME" \
      --replace "TestWildcards" "SkipWildcards"

    substituteInPlace interp/interp_test.go \
      --replace "TestShellCommand" "SkipShellCommand"
  '';

  checkFlags = [
    "-awk"
    "${gawk}/bin/gawk"
  ];

  doCheck = (stdenv.system != "aarch64-darwin");

  meta = with lib; {
    description = "POSIX-compliant AWK interpreter written in Go";
    homepage = "https://benhoyt.com/writings/goawk/";
    license = licenses.mit;
    mainProgram = "goawk";
    maintainers = with maintainers; [ abbe ];
  };
}
