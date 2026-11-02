# SPDX-License-Identifier: MIT
{
  pkgs,
  impurifier,
  hardwareFixture,
  nativeTools,
}:
let
  tool =
    version:
    pkgs.runCommand "pisi-tool-${version}"
      {
        pname = "pisi-tool";
        inherit version;
      }
      ''
        mkdir -p $out/bin
        printf '#!${pkgs.busybox}/bin/sh\necho ${version}\n' > $out/bin/pisi-tool
        chmod +x $out/bin/pisi-tool
      '';
  app =
    offline: version:
    impurifier.makePackage {
      pkg = tool version;
      inherit offline;
      configFiles."/etc/pisi-tool.conf" = pkgs.writeText "pisi-config" "version=${version}\n";
    };
  daemon =
    version:
    pkgs.runCommand "pisi-service-${version}"
      {
        pname = "pisi-service";
        inherit version;
      }
      ''
        mkdir -p $out/bin
        cat > $out/bin/pisi-service <<'SCRIPT'
        #!${pkgs.busybox}/bin/sh
        echo ${version} > /var/lib/pisi-service/version
        exec ${pkgs.busybox}/bin/sleep infinity
        SCRIPT
        chmod +x $out/bin/pisi-service
      '';
  service =
    version:
    impurifier.makeOfflinePackage {
      pkg = daemon version;
      users.pisi-service = { };
      directories."/var/lib/pisi-service" = {
        owner = "pisi-service:pisi-service";
        mode = "0750";
      };
      lifecycle = {
        onInstall = ''
          /usr/bin/python3 -c "import pwd; pwd.getpwnam('pisi-service')"
          test -x /opt/nix/profile/bin/pisi-service
          echo initialized > /var/lib/pisi-service/initialized
        '';
        onUpgrade = "echo ${version} > /var/lib/pisi-service/migrated";
      };
      systemd.unit = pkgs.writeText "pisi-service.service" ''
        [Service]
        Type=exec
        User=pisi-service
        ExecStart=/opt/nix/profile/bin/pisi-service
        [Install]
        WantedBy=multi-user.target
      '';
    };
  provider =
    name:
    impurifier.buildPackage {
      inherit name;
      version = "1";
      payload = pkgs.runCommand "${name}-inventory" { } ''
        mkdir -p $out/usr/share/pisi-fixture
        echo preinstalled > $out/usr/share/pisi-fixture/${name}
      '';
    };
  hostDriver =
    version:
    impurifier.buildPackage {
      name = "impurifier-host-driver";
      inherit version;
      payload = hardwareFixture.driver version;

    };
  hardware = impurifier.makeOfflinePackage {
    hostDependencies = [ "impurifier-host-driver" ];
    pkg = hardwareFixture.tool;
    inherit (hardwareFixture) hardware;
  };
in
pkgs.testers.runNixOSTest {
  name = "pisi-impurifier";
  requiredFeatures = {
    kvm = false;
    devnet = false;
  };
  nodes.machine = { lib, ... }: {
    virtualisation.memorySize = 2048;
    virtualisation.useNixStoreImage = true;
    virtualisation.writableStore = true;
    virtualisation.qemu.package = lib.mkForce pkgs.qemu;
    virtualisation.qemu.forceAccel = false;
    environment.systemPackages = [
      nativeTools.package
      pkgs.nix
      pkgs.python3
    ];
    systemd.tmpfiles.rules = [
      "d /usr/bin 0755 root root -"
      "L+ /usr/bin/python3 - - - - ${pkgs.python3}/bin/python3"
      "L+ /usr/bin/nix-store - - - - ${pkgs.nix}/bin/nix-store"
      "L+ /usr/bin/systemctl - - - - ${pkgs.systemd}/bin/systemctl"
      "L+ /usr/bin/systemd-sysusers - - - - ${pkgs.systemd}/bin/systemd-sysusers"
      "L+ /usr/bin/systemd-tmpfiles - - - - ${pkgs.systemd}/bin/systemd-tmpfiles"
    ];
    environment.etc."pisi/pisi.conf".text = ''
      [general]
      distribution = ImpurifierVM
      distribution_release = 1
      architecture = x86_64
    '';
    nix.settings.substituters = lib.mkForce [ ];
  };
  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("mkdir -p /var/lib/pisi /var/cache/pisi /tmp/packages /run/lock/files.ldb /var/lib/pisi/info/files.ldb; touch /run/lock/files.ldb/LOCK; ln -s /run/lock/files.ldb/LOCK /var/lib/pisi/info/files.ldb/LOCK")
    machine.succeed("cp ${app false "1"}/*.pisi /tmp/packages/net1.pisi; cp ${app true "1"}/*.pisi /tmp/packages/offline1.pisi; cp ${app true "2"}/*.pisi /tmp/packages/offline2.pisi; cp ${service "1"}/*.pisi /tmp/packages/service1.pisi; cp ${service "2"}/*.pisi /tmp/packages/service2.pisi; cp ${hostDriver "1"}/*.pisi /tmp/packages/driver1.pisi; cp ${hostDriver "2"}/*.pisi /tmp/packages/driver2.pisi; cp ${hardware}/*.pisi /tmp/packages/hardware.pisi")
    machine.succeed("cp -rL /etc/systemd/system /tmp/systemd-system; chmod -R u+w /tmp/systemd-system; rm /etc/systemd/system; mv /tmp/systemd-system /etc/systemd/system; systemctl daemon-reload")
    machine.succeed("systemctl stop dhcpcd; ip link set eth0 down")
    install = "${impurifier.adapter}/bin/pisi-impurifier install --reinstall --ignore-comar -y "
    remove = "/usr/sbin/pisi-impurifier remove --ignore-comar -y "
    with subtest("native versioned dependency rejects a legacy runtime inventory marker"):
        machine.succeed(install + "${provider "nix"}/*.pisi ${provider "python3"}/*.pisi ${provider "pisi"}/*.pisi ${
          impurifier.buildPackage {
            name = "pisi-impurifier";
            version = "0.1";
            payload =
              pkgs.runCommand "legacy-pisi-runtime-marker" { }
                "mkdir -p $out/usr/share/pisi-fixture; echo legacy-inventory > $out/usr/share/pisi-fixture/legacy-runtime";
          }
        }/*.pisi")
        machine.succeed("pisi info pisi-impurifier | grep 0.1")
        code, output = machine.execute(install + "/tmp/packages/offline1.pisi 2>&1")
        assert code != 0 and "pisi-impurifier" in output, output
        machine.fail("test -d /var/lib/pisi/package/pisi-tool-1-1")
    machine.succeed(install + "${impurifier.runtimePackage}/*.pisi")
    machine.fail("test -e ${builtins.unsafeDiscardStringContext (toString (tool "1"))}")
    with subtest("adapter fetch failure preserves the previous profile"):
        before = machine.succeed("readlink /opt/nix/profile").strip()
        code, output = machine.execute(install + "/tmp/packages/net1.pisi 2>&1")
        assert code != 0 and "nix-profile-engine:" in output, output
        assert machine.succeed("readlink /opt/nix/profile").strip() == before
    with subtest("help remains read-only with unresolved native intent"):
        output = machine.succeed(install + "--help")
        assert "nix-profile-engine:" not in output, output
        assert machine.succeed("readlink /opt/nix/profile").strip() == before
    with subtest("offline reinstall recovers with no network"):
        machine.succeed(install + "/tmp/packages/offline1.pisi")
        machine.succeed("test $(/opt/nix/profile/bin/pisi-tool) = 1")
    with subtest("native checksums update unedited defaults"):
        machine.succeed("grep version=1 /etc/pisi-tool.conf")
        machine.succeed(install + "/tmp/packages/offline2.pisi")
        machine.succeed("grep version=2 /etc/pisi-tool.conf")
        machine.succeed(install + "/tmp/packages/offline1.pisi")
        machine.succeed("grep version=1 /etc/pisi-tool.conf")
    with subtest("native conffiles survive transport switches and upgrades"):
        machine.succeed("echo local > /etc/pisi-tool.conf")
        machine.succeed(install + "/tmp/packages/net1.pisi")
        machine.succeed("grep local /etc/pisi-tool.conf")
        machine.succeed(install + "/tmp/packages/offline2.pisi")
        machine.succeed("grep local /etc/pisi-tool.conf; test $(/opt/nix/profile/bin/pisi-tool) = 2")
    with subtest("adapter activation follows the complete native batch"):
        output = machine.succeed(install + "${
          impurifier.makeOfflinePackage {
            pkg = pkgs.hello;
            name = "batch-a";
            version = "1";
          }
        }/*.pisi ${
          impurifier.makeOfflinePackage {
            pkg = pkgs.hello;
            name = "batch-b";
            version = "1";
          }
        }/*.pisi")
        assert output.count("activated ") == 1, output
        machine.succeed("/opt/nix/profile/bin/hello | grep Hello")
        machine.succeed(remove + "batch-a batch-b")
    with subtest("native service ownership and lifecycle preserve administrator intent"):
        machine.succeed(install + "/tmp/packages/service1.pisi")
        machine.wait_for_unit("pisi-service.service")
        machine.wait_until_succeeds("grep '^1$' /var/lib/pisi-service/version")
        machine.succeed("grep initialized /var/lib/pisi-service/initialized; test $(stat -c %U /var/lib/pisi-service) = pisi-service")
        machine.succeed(install + "/tmp/packages/service2.pisi")
        machine.wait_until_succeeds("grep '^2$' /var/lib/pisi-service/version")
        machine.succeed("grep '^2$' /var/lib/pisi-service/migrated")
        machine.succeed("systemctl disable --now pisi-service.service")
        machine.succeed(install + "/tmp/packages/service1.pisi")
        machine.fail("systemctl is-active --quiet pisi-service.service")
        machine.fail("systemctl is-enabled --quiet pisi-service.service")
        machine.succeed("systemctl enable --now pisi-service.service")
        machine.succeed(remove + "pisi-service")
        machine.fail("systemctl is-active --quiet pisi-service.service")
        machine.fail("test -e /etc/systemd/system/pisi-service.service")
    with subtest("native driver transactions refresh snapshot bindings"):
        code, output = machine.execute(install + "/tmp/packages/hardware.pisi 2>&1")
        assert code != 0 and "impurifier-host-driver" in output, output
        machine.succeed(install + "/tmp/packages/driver1.pisi /tmp/packages/hardware.pisi")
        machine.succeed("/opt/nix/profile/bin/hardware-tool | grep '^1$'")
        machine.succeed(install + "/tmp/packages/driver2.pisi")
        machine.succeed("/opt/nix/profile/bin/hardware-tool | grep '^2$'")
        machine.succeed(remove + "hardware-tool")
        machine.succeed(remove + "impurifier-host-driver")
    with subtest("offline-root maintainer scripts cannot activate the host"):
        before = machine.succeed("readlink /opt/nix/profile").strip()
        code, output = machine.execute(install + "--destdir=/tmp/foreign-root /tmp/packages/offline1.pisi 2>&1")
        assert code != 0 and "foreign destdir cannot activate the host" in output, output
        assert machine.succeed("readlink /opt/nix/profile").strip() == before
    with subtest("GC and native removal release profile intent"):
        machine.succeed("nix-store --gc; test $(/opt/nix/profile/bin/pisi-tool) = 2")
        machine.succeed(remove + "pisi-tool")
        machine.fail("test -e /opt/nix/profile/bin/pisi-tool")
        machine.succeed("grep local /etc/pisi-tool.conf")
        machine.succeed("/usr/sbin/nix-profile-engine prune --keep 0; nix-store --gc; test -d /opt/nix/profile")
  '';
}
