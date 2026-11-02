# SPDX-License-Identifier: MIT
{ ... }:
{ lib, inputs, ... }:
{
  flake.lib = lib.mkForce {
    pisi-impurifier =
      {
        pkgs,
        distribution,
        distributionRelease,
      }:
      import ../../../nix {
        inherit pkgs distribution distributionRelease;
        coreSrc = inputs.impurifier;
      };
  };
  perSystem =
    { pkgs, ... }:
    let
      impurifier = import ../../../nix {
        inherit pkgs;
        distribution = "ImpurifierVM";
        distributionRelease = "1";
        coreSrc = inputs.impurifier;
      };
      nativeTools = import ../../../tests/tools.nix { legacySrc = inputs.legacy-nixpkgs; };
    in
    {
      packages = {
        default = impurifier.engine;
        engine = impurifier.engine;
        adapter = impurifier.adapter;
        native-pisi = nativeTools.package;
        runtime-package = impurifier.runtimePackage;
        hello-net = impurifier.makeNetPackage { pkg = pkgs.hello; };
        hello-offline = impurifier.makeOfflinePackage { pkg = pkgs.hello; };
      };
      formatter = pkgs.nixfmt-tree;
      checks = import ../../../tests {
        inherit pkgs impurifier nativeTools;
        coreSrc = inputs.impurifier;
      };
    };
}
