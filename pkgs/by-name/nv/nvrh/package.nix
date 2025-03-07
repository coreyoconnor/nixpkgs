{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
  nix-update-script,
}:

buildGoModule rec {
  pname = "nvrh";
  version = "0.1.14";

  src = fetchFromGitHub {
    owner = "mikew";
    repo = "nvrh";
    tag = "v${version}";
    hash = "sha256-ff+ZdUScgAaNHASYAASQ/lfkCyX600kNw2Rjpr3TbBc=";
  };

  postPatch = ''
    substituteInPlace go.mod \
      --replace-fail "go 1.23.1" "go 1.22.7"
  '';

  preBuild = ''
    cp manifest.json src/
  '';

  vendorHash = "sha256-BioDzQMZWtTiM08aBQTPT4IGxK4f2JNx7dzNbcCgELQ=";

  ldflags = [
    "-s"
    "-w"
  ];

  postInstall = ''
    mv $out/bin/src $out/bin/nvrh
  '';

  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  versionCheckProgramArg = [ "--version" ];
  doInstallCheck = true;

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Aims to be similar to VSCode Remote, but for Neovim";
    homepage = "https://github.com/mikew/nvrh";
    changelog = "https://github.com/mikew/nvrh/blob/${src.rev}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ GaetanLepage ];
    mainProgram = "nvrh";
  };
}
