{
  config,
  lib,
  pkgs,
  utils,
  ...
}:

let

  bootFs = lib.filterAttrs (
    n: fs: (fs.fsType == "bcachefs") && (utils.fsNeededForBoot fs)
  ) config.fileSystems;

  commonFunctions = ''
    prompt() {
        local name="$1"
        printf "enter passphrase for $name: "
    }

    tryUnlock() {
        local name="$1"
        local path="$2"
        local success=false
        local target
        local uuid=$(echo -n $path | sed -e 's,UUID=\(.*\),\1,g')

        printf "waiting for device to appear $path"
        for try in $(seq 10); do
          if [ -e $path ]; then
              target=$(readlink -f $path)
              success=true
              break
          else
              target=$(blkid --uuid $uuid)
              if [ $? == 0 ]; then
                 success=true
                 break
              fi
          fi
          echo -n "."
          sleep 1
        done
        printf "\n"
        if [ $success == true ]; then
            path=$target
        fi

        if bcachefs unlock -c $path > /dev/null 2> /dev/null; then    # test for encryption
            prompt $name
            until bcachefs unlock $path 2> /dev/null; do              # repeat until successfully unlocked
                printf "unlocking failed!\n"
                prompt $name
            done
            printf "unlocking successful.\n"
        else
            echo "Cannot unlock device $uuid with path $path" >&2
        fi
    }
  '';

  # we need only unlock one device manually, and cannot pass multiple at once
  # remove this adaptation when bcachefs implements mounting by filesystem uuid
  # also, implement automatic waiting for the constituent devices when that happens
  # bcachefs does not support mounting devices with colons in the path, ergo we don't (see #49671)
  firstDevice = fs: lib.head (lib.splitString ":" fs.device);

  useClevis =
    fs:
    config.boot.initrd.clevis.enable
    && (lib.hasAttr (firstDevice fs) config.boot.initrd.clevis.devices);

  openCommand =
    name: fs:
    if useClevis fs then
      ''
        if clevis decrypt < /etc/clevis/${firstDevice fs}.jwe | bcachefs unlock ${firstDevice fs}
        then
          printf "unlocked ${name} using clevis\n"
        else
          printf "falling back to interactive unlocking...\n"
          tryUnlock ${name} ${firstDevice fs}
        fi
      ''
    else
      ''
        tryUnlock ${name} ${firstDevice fs}
      '';

  mkUnits =
    prefix: name: fs:
    let
      mountUnit = "${utils.escapeSystemdPath (prefix + (lib.removeSuffix "/" fs.mountPoint))}.mount";
      device = firstDevice fs;
      deviceUnit = "${utils.escapeSystemdPath device}.device";
    in
    {
      name = "unlock-bcachefs-${utils.escapeSystemdPath fs.mountPoint}";
      value = {
        description = "Unlock bcachefs for ${fs.mountPoint}";
        requiredBy = [ mountUnit ];
        after = [ deviceUnit ];
        before = [
          mountUnit
          "shutdown.target"
        ];
        bindsTo = [ deviceUnit ];
        conflicts = [ "shutdown.target" ];
        unitConfig.DefaultDependencies = false;
        serviceConfig = {
          Type = "oneshot";
          ExecCondition = "${pkgs.bcachefs-tools}/bin/bcachefs unlock -c \"${device}\"";
          Restart = "on-failure";
          RestartMode = "direct";
          # Ideally, this service would lock the key on stop.
          # As is, RemainAfterExit doesn't accomplish anything.
          RemainAfterExit = true;
        };
        script =
          let
            unlock = ''${pkgs.bcachefs-tools}/bin/bcachefs unlock "${device}"'';
            unlockInteractively = ''${config.boot.initrd.systemd.package}/bin/systemd-ask-password --timeout=0 "enter passphrase for ${name}" | exec ${unlock}'';
          in
          if useClevis fs then
            ''
              if ${config.boot.initrd.clevis.package}/bin/clevis decrypt < "/etc/clevis/${device}.jwe" | ${unlock}
              then
                printf "unlocked ${name} using clevis\n"
              else
                printf "falling back to interactive unlocking...\n"
                ${unlockInteractively}
              fi
            ''
          else
            ''
              ${unlockInteractively}
            '';
      };
    };

  assertions = [
    {
      assertion =
        let
          kernel = config.boot.kernelPackages.kernel;
        in
        (
          kernel.kernelAtLeast "6.7"
          || (lib.elem (kernel.structuredExtraConfig.BCACHEFS_FS or null) [
            lib.kernel.module
            lib.kernel.yes
            (lib.kernel.option lib.kernel.yes)
          ])
        );

      message = "Linux 6.7-rc1 at minimum or a custom linux kernel with bcachefs support is required";
    }
  ];
in

{
  config = lib.mkIf (config.boot.supportedFilesystems.bcachefs or false) (
    lib.mkMerge [
      {
        inherit assertions;
        # needed for systemd-remount-fs
        system.fsPackages = [ pkgs.bcachefs-tools ];
        # FIXME: Remove this line when the LTS (default) kernel is at least version 6.7
        boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
        services.udev.packages = [ pkgs.bcachefs-tools ];

        systemd = {
          packages = [ pkgs.bcachefs-tools ];
          services = lib.mapAttrs' (mkUnits "") (
            lib.filterAttrs (n: fs: (fs.fsType == "bcachefs") && (!utils.fsNeededForBoot fs)) config.fileSystems
          );
        };
      }

      (lib.mkIf ((config.boot.initrd.supportedFilesystems.bcachefs or false) || (bootFs != { })) {
        inherit assertions;
        boot.initrd.availableKernelModules =
          [
            "bcachefs"
            "sha256"
          ]
          ++ lib.optionals (config.boot.kernelPackages.kernel.kernelOlder "6.15") [
            # chacha20 and poly1305 are required only for decryption attempts
            # kernel 6.15 uses kernel api libraries for poly1305/chacha20: 4bf4b5046de0ef7f9dc50f3a9ef8a6dcda178a6d
            # kernel 6.16 removes poly1305: ceef731b0e22df80a13d67773ae9afd55a971f9e
            "poly1305"
            "chacha20"
          ];
        boot.initrd.systemd.extraBin = {
          # do we need this? boot/systemd.nix:566 & boot/systemd/initrd.nix:357
          "bcachefs" = "${pkgs.bcachefs-tools}/bin/bcachefs";
          "mount.bcachefs" = "${pkgs.bcachefs-tools}/bin/mount.bcachefs";
        };
        boot.initrd.extraUtilsCommands = lib.mkIf (!config.boot.initrd.systemd.enable) ''
          copy_bin_and_libs ${pkgs.bcachefs-tools}/bin/bcachefs
          copy_bin_and_libs ${pkgs.bcachefs-tools}/bin/mount.bcachefs
        '';
        boot.initrd.extraUtilsCommandsTest = lib.mkIf (!config.boot.initrd.systemd.enable) ''
          $out/bin/bcachefs version
        '';

        boot.initrd.postDeviceCommands = lib.mkIf (!config.boot.initrd.systemd.enable) (
          commonFunctions + lib.concatStrings (lib.mapAttrsToList openCommand bootFs)
        );

        boot.initrd.systemd.services = lib.mapAttrs' (mkUnits "/sysroot") bootFs;
      })
    ]
  );
}
