# SPDX-License-Identifier: MIT
{
  pkgs,
  coreSrc,
  distribution,
  distributionRelease,
}:
let
  inherit (pkgs) lib;
  core = import (coreSrc + "/nix") {
    inherit pkgs;
    sourceInfo = coreSrc;
    namespace = "pisi-impurifier";
  };
  defaultDistribution = distribution;
  defaultDistributionRelease = distributionRelease;
  defaultArchitecture =
    if pkgs.stdenv.hostPlatform.isx86_64 then
      "x86_64"
    else if pkgs.stdenv.hostPlatform.isAarch64 then
      "aarch64"
    else
      throw "unsupported pisi architecture";
  adapter = pkgs.writeScriptBin "pisi-impurifier" (
    builtins.replaceStrings [ "#!/usr/bin/python3" ] [ "#!${pkgs.python3}/bin/python3" ] (
      builtins.readFile ../src/adapter.py
    )
  );
  buildPackage =
    {
      name,
      version,
      payload,
      release ? "1",
      architecture ? defaultArchitecture,
      description ? "Impurified Nix application",
      license ? "LicenseRef-Unknown",
      distribution ? defaultDistribution,
      distributionRelease ? defaultDistributionRelease,
      dependencies ? [ ],
      configPaths ? [ ],
    }:
    assert lib.assertMsg (
      builtins.match "[a-z0-9][a-z0-9+_.-]*" name != null
      && builtins.match "[A-Za-z0-9_.+]+" version != null
      && builtins.match "[1-9][0-9]*" release != null
      && builtins.match "[A-Za-z0-9_]+" architecture != null
    ) "invalid pisi package metadata";
    assert lib.assertMsg (lib.all (
      dep:
      let
        value = if builtins.isString dep then { name = dep; } else dep;
      in
      builtins.match "[a-z0-9][a-z0-9+_.-]*" value.name != null
      && lib.all (
        key:
        lib.elem key [
          "name"
          "version"
          "versionFrom"
          "versionTo"
          "release"
          "releaseFrom"
          "releaseTo"
        ]
      ) (builtins.attrNames value)
    ) dependencies) "invalid pisi dependency";
    pkgs.runCommand "${name}-${version}-${release}-pisi-package"
      {
        __structuredAttrs = true;
        unsafeDiscardReferences.out = true;
        passthru.filename = "${name}-${version}-${release}-${architecture}.pisi";
      }
      ''
        mkdir -p root $out
        cp -r ${payload}/. root/
        chmod -R u+w root
        ${pkgs.buildPackages.python3}/bin/python3 ${../src/build-package.py} ${
          pkgs.writeText "pisi-spec.json" (
            builtins.toJSON {
              inherit
                name
                version
                release
                description
                license
                distribution
                distributionRelease
                dependencies
                configPaths
                ;
              inherit architecture;
            }
          )
        } root $out/${name}-${version}-${release}-${architecture}.pisi
      '';
  makePackage =
    args@{
      pkg,
      release ? "1",
      hostDependencies ? [ ],
      distribution ? defaultDistribution,
      distributionRelease ? defaultDistributionRelease,
      license ? null,
      ...
    }:
    let
      payload = core.makePayload (
        builtins.removeAttrs args [
          "release"
          "hostDependencies"
          "distribution"
          "distributionRelease"
          "license"
        ]
      );
      nativeLicense =
        if license != null then
          license
        else
          lib.concatMapStringsSep " AND " (value: value.spdxId or "LicenseRef-Unknown") (
            lib.toList (pkg.meta.license or [ ])
          );
    in
    buildPackage {
      name = payload.name;
      inherit (payload) version description configPaths;
      inherit
        payload
        release
        distribution
        distributionRelease
        ;
      license = if nativeLicense == "" then "LicenseRef-Unknown" else nativeLicense;
      dependencies = [
        {
          name = "pisi-impurifier";
          versionFrom = core.runtimeVersion;
        }
      ]
      ++ hostDependencies;
    };
  makeRuntimePackage =
    {
      nixDependency ? "nix",
      pythonDependency ? "python3",
      pisiDependency ? "pisi",
      distribution ? defaultDistribution,
      distributionRelease ? defaultDistributionRelease,
    }:
    buildPackage {
      name = "pisi-impurifier";
      version = core.runtimeVersion;
      license = "MIT";
      inherit distribution distributionRelease;
      dependencies = [
        nixDependency
        pythonDependency
        pisiDependency
      ];
      payload = pkgs.runCommand "pisi-impurifier-runtime-payload" { } ''
        mkdir -p $out
        cp -r ${core.makeRuntimeTree { }}/. $out/
        chmod -R u+w $out
        install -Dm755 ${../src/adapter.py} $out/usr/sbin/pisi-impurifier
      '';
    };
in
{
  inherit (core)
    engine
    offlineCache
    unit
    runtimeVersion
    ;
  inherit
    adapter
    buildPackage
    makePackage
    makeRuntimePackage
    ;
  runtimePackage = makeRuntimePackage { };
  makeNetPackage = args: makePackage (args // { offline = false; });
  makeOfflinePackage = args: makePackage (args // { offline = true; });
}
