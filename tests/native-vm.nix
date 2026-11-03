# SPDX-License-Identifier: MIT
{
  pkgs,
  impurifier,
  nativeTools,
}:
let
  client = nativeTools.package;
  app =
    version:
    impurifier.makeNativePackage {
      name = "native-proof";
      inherit version;
      payload = pkgs.runCommand "native-proof-tree-${version}" { } ''
        mkdir -p $out/usr/bin $out/etc
        cp ${pkgs.pkgsStatic.busybox}/bin/busybox $out/usr/bin/busybox
        echo ${version} > $out/etc/native-proof-version
      '';
    };
in
pkgs.testers.runNixOSTest {
  name = "pisi-native-payload";
  requiredFeatures.kvm = false;
  requiredFeatures.devnet = false;
  nodes.machine = { lib, ... }: {
    virtualisation.qemu.package = lib.mkForce pkgs.qemu;
    virtualisation.qemu.forceAccel = false;
    environment.etc."pisi/pisi.conf".text = ''
      [general]
      distribution = ImpurifierVM
      distribution_release = 1
      architecture = x86_64
    '';
    environment.systemPackages = [ client ];
  };
  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("mkdir -p /srv/native/var/lib/pisi /srv/native/var/cache/pisi")
    machine.succeed("pisi install -y --ignore-comar --destdir=/srv/native ${app "1"}/*.pisi")
    machine.succeed("chroot /srv/native /usr/bin/busybox echo native-execution | grep native-execution")
    machine.succeed("test ! -e /srv/native/nix; grep '^1$' /srv/native/etc/native-proof-version")
    machine.succeed("pisi install -y --ignore-comar --destdir=/srv/native ${app "2"}/*.pisi")
    machine.succeed("grep '^2$' /srv/native/etc/native-proof-version")
    machine.succeed("pisi remove -y --ignore-comar --destdir=/srv/native native-proof")
    machine.succeed("test ! -e /srv/native/usr/bin/busybox; test ! -e /srv/native/etc/native-proof-version; test ! -e /srv/native/nix")
  '';
}
