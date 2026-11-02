# Commands

```sh
nix flake check -L
nix fmt
nix build ".#adapter"
```

Use the library with explicit target distribution/release to emit real native packages. Demonstration flake packages use the VM target. Publish core, converge pins and verify published inputs before landing.
