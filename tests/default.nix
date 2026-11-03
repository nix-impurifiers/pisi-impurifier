# SPDX-License-Identifier: MIT
{
  pkgs,
  impurifier,
  coreSrc,
  nativeTools,
}:
{
  native-vm = import ./native-vm.nix { inherit pkgs impurifier nativeTools; };
  bundled-vm = import ./vm.nix {
    inherit pkgs nativeTools;
    bundled = true;
    impurifier = impurifier // {
      runtimePackage = impurifier.makeRuntimePackage {
        bundledNixStore = "${import (coreSrc + "/tests/static-nix.nix") { inherit pkgs; }}/bin/nix-store";
        bundledNixNotices = [ "${pkgs.nix.src}/COPYING" ];
      };
    };
    hardwareFixture = import (coreSrc + "/tests/hardware-fixture.nix") { inherit pkgs; };
  };
  unit = impurifier.unit;
  vm = import ./vm.nix {
    inherit pkgs impurifier nativeTools;
    hardwareFixture = import (coreSrc + "/tests/hardware-fixture.nix") { inherit pkgs; };
  };
}
