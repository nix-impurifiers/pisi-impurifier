# SPDX-License-Identifier: MIT
# Historical native tools are confined to this compatibility fixture.
{
  legacySrc,
  system ? "x86_64-linux",
}:
let
  pkgs = import legacySrc {
    inherit system;
    config.permittedInsecurePackages = [ "python-2.7.18" ];
  };
  python = pkgs.python27;
  py = python.pkgs;
  piksemel = py.buildPythonPackage {
    pname = "piksemel";
    version = "1.3.1";
    src = pkgs.fetchurl {
      url = "https://downloads.sourceforge.net/project/pisilinux/source/piksemel-1.3.1.tar.gz";
      sha256 = "fwYP6wWG0DviZ9sw1WdN45hUoM4NWPbSBpVNqg8RmYk=";
    };
    postPatch = "patchShebangs tests";
    meta.license = pkgs.lib.licenses.gpl2Plus;
    postInstall = ''
      install -Dm644 ${../LICENSES/GPL-2.0-or-later.txt} $out/share/licenses/piksemel/COPYING
      head -n 11 setup.py > $out/share/licenses/piksemel/NOTICE
    '';
    pythonImportsCheck = [ "piksemel" ];
  };
  pyliblzma = py.buildPythonPackage {
    pname = "pyliblzma";
    version = "0.5.3";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/17/48/5292ade507dafe573360560ba53783395587dc42eb32b347feb2ac70fc6b/pyliblzma-0.5.3.tar.bz2";
      sha256 = "CNdi821eWfubsOIuAAwwCyH5fjW3EzIe5QTPtEJmeVc=";
    };
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.xz ];
    meta.license = pkgs.lib.licenses.lgpl3Plus;
    postInstall = ''
      install -Dm644 COPYING $out/share/licenses/pyliblzma/COPYING
      install -Dm644 ${../LICENSES/GPL-3.0-or-later.txt} $out/share/licenses/pyliblzma/GPL-3.0
      head -n 23 setup.py > $out/share/licenses/pyliblzma/NOTICE
    '';
    pythonImportsCheck = [ "lzma" ];
  };
  comarApi = py.buildPythonPackage {
    pname = "comar-api";
    version = "2.4.9";
    src = pkgs.fetchurl {
      url = "https://github.com/PisiLinuxNew/comar-api/archive/e24d6bd9f76b396cee602ca2d8b0387398214b4b.tar.gz";
      sha256 = "A3fHg61mVfcDPyE3sn166VP8Ppsil2xbPP7xG3Rm64Y=";
    };
    propagatedBuildInputs = [ py.dbus-python ];
    meta.license = pkgs.lib.licenses.gpl2Plus;
    format = "other";
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/${python.sitePackages}
      cp -r comar $out/${python.sitePackages}/
      install -Dm644 ${../LICENSES/GPL-2.0-or-later.txt} $out/share/licenses/comar-api/COPYING
      runHook postInstall
    '';
    postInstall = ''export PYTHONPATH="$out/${python.sitePackages}:$PYTHONPATH"'';
    pythonImportsCheck = [ "comar" ];
  };
  package = py.buildPythonPackage {
    pname = "pisi";
    version = "2.7.2";
    src = pkgs.fetchurl {
      url = "https://github.com/PisiLinuxNew/pisi/archive/596157238c17e71ac9a17426e5e76901cfb482dc.tar.gz";
      sha256 = "U/Ue0A+BgtXgB/IOJBlnHFX6ls+9PG8tiud4kCKKalc=";
    };
    propagatedBuildInputs = [
      piksemel
      pyliblzma
      comarApi
      py.dbus-python
      py.plyvel
      py.psutil
      py.urlgrabber
      py.python_magic
    ];
    meta.license = pkgs.lib.licenses.gpl2Plus;
    format = "other";
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/${python.sitePackages} $out/bin
      cp -r pisi $out/${python.sitePackages}/
      install -m755 pisi-cli $out/bin/pisi
      patchShebangs $out/bin/pisi
      install -Dm644 COPYING $out/share/licenses/pisi/COPYING
      runHook postInstall
    '';
    postInstall = ''export PYTHONPATH="$out/${python.sitePackages}:$PYTHONPATH"'';
    pythonImportsCheck = [ "pisi.package" ];
  };
in
{
  inherit package;
  python = python.withPackages (_: [ package ]);
}
