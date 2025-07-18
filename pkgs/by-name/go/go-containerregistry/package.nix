{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
}:

let
  bins = [
    "crane"
    "gcrane"
  ];
in

buildGoModule rec {
  pname = "go-containerregistry";
  version = "0.20.3";

  src = fetchFromGitHub {
    owner = "google";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-HiksVzVuY4uub7Lwfyh3GN8wpH2MgIjKSO4mQJZeNvs=";
  };
  vendorHash = null;

  nativeBuildInputs = [ installShellFiles ];

  subPackages = [
    "cmd/crane"
    "cmd/gcrane"
  ];

  outputs = [ "out" ] ++ bins;

  ldflags =
    let
      t = "github.com/google/go-containerregistry";
    in
    [
      "-s"
      "-w"
      "-X ${t}/cmd/crane/cmd.Version=v${version}"
      "-X ${t}/pkg/v1/remote/transport.Version=${version}"
    ];

  postInstall =
    lib.concatStringsSep "\n" (
      map (bin: ''
        mkdir -p ''$${bin}/bin &&
        mv $out/bin/${bin} ''$${bin}/bin/ &&
        ln -s ''$${bin}/bin/${bin} $out/bin/
      '') bins
    )
    + ''
      for cmd in crane gcrane; do
        installShellCompletion --cmd "$cmd" \
          --bash <($GOPATH/bin/$cmd completion bash) \
          --fish <($GOPATH/bin/$cmd completion fish) \
          --zsh <($GOPATH/bin/$cmd completion zsh)
      done
    '';

  # NOTE: no tests
  doCheck = false;

  meta = with lib; {
    description = "Tools for interacting with remote images and registries including crane and gcrane";
    homepage = "https://github.com/google/go-containerregistry";
    license = licenses.asl20;
    maintainers = with maintainers; [
      yurrriq
      ryan4yin
    ];
  };
}
