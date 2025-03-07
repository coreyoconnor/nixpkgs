{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  pythonOlder,
  poetry-core,
  textfsm,
  invoke,
  pytestCheckHook,
  ruamel-yaml,
  toml,
  yamllint,
}:

buildPythonPackage rec {
  pname = "ntc-templates";
  version = "6.0.0";
  format = "pyproject";

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "networktocode";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-E8n4ZcCH8xxU5XXVxQUl8844RnRpnbHy/LnjHlz7Eeg=";
  };

  nativeBuildInputs = [ poetry-core ];

  propagatedBuildInputs = [ textfsm ];

  nativeCheckInputs = [
    invoke
    pytestCheckHook
    ruamel-yaml
    toml
    yamllint
  ];

  # https://github.com/networktocode/ntc-templates/issues/743
  disabledTests = [
    "test_raw_data_against_mock"
    "test_verify_parsed_and_reference_data_exists"
  ];

  meta = with lib; {
    description = "TextFSM templates for parsing show commands of network devices";
    homepage = "https://github.com/networktocode/ntc-templates";
    changelog = "https://github.com/networktocode/ntc-templates/releases/tag/v${version}";
    license = licenses.asl20;
    maintainers = [ ];
  };
}
