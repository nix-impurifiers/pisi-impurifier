# pisi-impurifier

Native PiSi format 1.2 archives backed by atomic Nix profiles. Original code is
MIT licensed; [upstream fixture licenses](THIRD_PARTY.md) remain their own.
PiSi is tested independently of its eopkg fork.

```nix
let impurifier = inputs.pisi-impurifier.lib.pisi-impurifier {
  inherit pkgs;
  distribution = "your-distribution";
  distributionRelease = "your-native-release";
};
in impurifier.makeOfflinePackage { pkg = pkgs.hello; }
```

Match distribution metadata to `/etc/pisi/pisi.conf`. These constructor arguments
are required because PiSi checks native distribution release and architecture.
This keeps one backend per package manager rather than creating distro forks.
The flake's demonstration archives use ImpurifierVM/1 and belong to the test
fixture; build your real archives through the library with your target metadata.

Build the adapter and a `makeRuntimePackage` artifact. Native inventory providers
for Nix, Python 3 and PiSi must already exist; runtime arguments `nixDependency`,
`pythonDependency` and `pisiDependency` select their names. Providing Nix itself
is deferred. The native client may use Python 2; our installed engine and adapter
use Python 3 independently.

Install the runtime through the built adapter, then use
`/usr/sbin/pisi-impurifier install --reinstall -y /path/to/app/*.pisi` and
`/usr/sbin/pisi-impurifier remove -y app-name`. The adapter runs actual PiSi before
reconciling the Nix profile. Use it for managed applications and driver updates,
or run `/usr/sbin/nix-profile-engine reconcile` explicitly. Plain PiSi changes
native ownership without profile activation. Native COMAR behavior still runs
when configured; hosts that intentionally omit it use PiSi's `--ignore-comar`.

Install/it, upgrade/up and remove/rm accept native options. Dry-run and fetch-only
commands do not reconcile. Foreign destdir activation is rejected. Failed native
transactions may leave changed files; the adapter reconciles current intent and
returns failure. Engine failure keeps the prior profile published. Repair native
state and reconcile again; profile atomicity is not native filesystem rollback.

`makeNetPackage`, `makeOfflinePackage` and `makePackage` accept shared application
arguments plus numeric `release`, `hostDependencies`, `license` and optional
per-package distribution overrides. Dependencies are names or relation attributes
such as `{ name = "driver"; versionFrom = "2"; }`. Applications have a native
minimum-runtime dependency derived from the pinned core source timestamp. These
are artifact metadata, not SemVer releases.

Net/offline variants share native identity and use explicit native reinstall to
switch. Offline packages embed the complete closure. `/etc` files use native
configuration protection. Modified files remain on normal native removal;
purge remains an explicit native operation. `buildPackage` accepts a raw payload
and requires nonempty content or an inventory marker.

Shared accounts, directories, lifecycle hooks, explicit hardware bindings and
chosen systemd/OpenRC/runit protocols are supported. Consumers select an existing
supervisor and native host dependencies. This does not implement Mudur service
policy or claim full COMAR integration.

`nix flake check -L` boots QEMU and executes the actual PisiLinuxNew v2.7.2
release source (which reports 2.7.1), built with pinned Python 2 dependencies.
The modern emitter, runtime and applications use the main pinned nixpkgs.
Tests keep native version/distribution/architecture checks enabled and cover
runtime rejection before unpack, dependency solving, offline recovery, flavor
switches, edited and unedited config, batch activation, accounts/services/admin
intent, drivers, foreign roots, removal and rooted GC. The fixture uses native
`--ignore-comar`; COMAR daemon and full PisiLinux/Mudur boot remain separate
coverage. Preinstalled provider inventory markers are not installers.

## Native payloads and bundled Nix

`makeNativePackage { name; version; payload; dependencies?; configPaths?; ... }`
accepts a producer-prepared filesystem tree. It adds no engine intent or Nix
dependency; ordinary `pisi` owns and installs its files. Distribution metadata
and native dependency expressions remain consumer policy. The producer supplies
a working target layout; this does not relocate binaries. A native VM executes
a static payload in a target root without `/nix`, upgrades and removes it.

`makeRuntimePackage` accepts `bundledNixStore` and `bundledNixNotices` for a static
ELF client and its upstream notices. Bundling omits the default Nix dependency;
Python and the manager's Python API remain required. Compatible external clients
take precedence, explicit `IMPURIFIER_NIX_STORE` disables fallback, and failed
mutations are never retried through another client. A bundled-client VM repeats
the original lifecycle suite with an incompatible external candidate. The Nix
provider/installer remains deferred.
