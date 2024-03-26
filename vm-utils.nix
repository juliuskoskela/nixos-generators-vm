{
  pkgs,
  nixos-generators,
  nuenv,
}: let
  mkImage = {
    system,
    inputs,
    config,
    format ? "raw",
  }:
    nixos-generators.nixosGenerate {
      inherit system format;

      specialArgs = inputs;
      modules = [config];
    };

  mkQemuVm = {
    name,
    arch ? "x86_64",
    inputs,
    config,
    memorySize ? 512,
    cpus ? 1,
    command,
  }: let
    format = "qcow";

    image = mkImage {
      inherit inputs config format;

      system = arch + "-linux";
    };

    vmPath = "/var/vms/${name}";

    vmImage = "${vmPath}/nixos.qcow2";

    syncImage = ''
      ${pkgs.coreutils}/bin/mkdir -p ${vmPath}
      ${pkgs.rsync}/bin/rsync \
        --checksum \
        --ignore-existing \
        -a ${image}/nixos.qcow2 ${vmImage}
      ${pkgs.coreutils}/bin/chmod +rw ${vmImage}
    '';

    parseCommandList = pkgs.lib.mapList (cmd: " ${cmd}") command;

    qemuCommand = ''
      ${pkgs.qemu}/bin/qemu-system-${arch} ${parseCommandList}
           '';

    fullCommand = ''
      ${syncImage}
      ${qemuCommand}
    '';
  in pkgs.writeShellScriptBin name fullCommand;

  mkQemuAppVm = {
    name,
    arch ? "x86_64",
    inputs,
    config,
    memorySize ? 512,
    cpus ? 1,
  }: let
    format = "qcow";

    image = mkImage {
      inherit inputs config format;

      system = arch + "-linux";
    };

    vmPath = "/var/vms/${name}";

    vmImage = "${vmPath}/nixos.qcow2";

    qemuCommand = ''
      ${pkgs.coreutils}/bin/mkdir -p ${vmPath}
      ${pkgs.rsync}/bin/rsync \
        --checksum \
        --ignore-existing \
        -a ${image}/nixos.qcow2 ${vmImage}
      ${pkgs.coreutils}/bin/chmod +rw ${vmImage}
      ${pkgs.qemu}/bin/qemu-system-${arch} \
        -m ${toString memorySize} \
        -smp ${toString cpus} \
        -drive file=${vmImage},format=qcow2 \
        -nographic
    '';
  in
    pkgs.writeShellScriptBin name qemuCommand;

  mkCrosvmAppVm = {
    name,
    arch ? "x86_64",
    inputs,
    config,
    memorySize ? 512,
    cpus ? 1,
  }: let
    format = "raw";

    image = mkImage {
      inherit inputs config format;

      system = arch + "-linux";
    };

    vmPath = "/var/vms/${name}";

    vmImage = "${vmPath}/nixos.img";

    crosvmCommand = ''
      ${pkgs.coreutils}/bin/mkdir -p ${vmPath}
      ${pkgs.rsync}/bin/rsync \
        --checksum \
        --ignore-existing \
        -a ${image}/nixos.img ${vmImage}
      ${pkgs.coreutils}/bin/chmod +rw ${vmImage}
      ${pkgs.crosvm}/bin/crosvm run \
        --cpus ${toString cpus} \
        --mem ${toString memorySize} \
        --rwdisk ${vmImage} \
        --params "root=/dev/sda console=ttyS0" \
        ""
    '';
  in
    pkgs.writeShellScriptBin name crosvmCommand;
in {
  inherit mkImage mkQemuAppVm mkCrosvmAppVm mkQemuVm;
}
