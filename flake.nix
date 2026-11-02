# SPDX-License-Identifier: MIT
{
  description = "Native PiSi packages backed by transactional Nix profiles";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    legacy-nixpkgs = {
      url = "github:NixOS/nixpkgs/1c1f5649bb9c1b0d98637c8c365228f57126f361";
      flake = false;
    };
    impurifier = {
      url = "github:nix-impurifiers/impurifier";
      flake = false;
    };
    caisson.url = "github:nix-caisson/caisson";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };
  outputs =
    inputs@{ caisson, ... }:
    let
      lib = caisson.lib.caisson.mkLib {
        inherit (caisson.lib.caisson.pins.flake inputs) sources root;
        name = "pisi-impurifier";
        defaultEcosystemSrc = sources: { nixpkgs-lib = sources.nixpkgs; };
        systems = [ "x86_64-linux" ];
        projects = { inherit caisson; };
        configs = lib: lib.caisson.mkModules ./configs;
        pkgSets = lib: lib.caisson.nixpkgs.mkConfigurations { };
      };
    in
    lib.caisson.flake-parts.mkTopConfiguration { };
}
