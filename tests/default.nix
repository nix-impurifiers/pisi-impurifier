# SPDX-License-Identifier: MIT
{
  pkgs,
  impurifier,
  coreSrc,
  nativeTools,
}:
{
  unit = impurifier.unit;
  vm = import ./vm.nix {
    inherit pkgs impurifier nativeTools;
    hardwareFixture = import (coreSrc + "/tests/hardware-fixture.nix") { inherit pkgs; };
  };
}
