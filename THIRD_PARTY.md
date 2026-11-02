# Upstream native test tools

Original impurifier code is MIT licensed. The compatibility fixture fetches
unchanged upstream source and preserves its copyright headers and licenses:

- PiSi: PisiLinuxNew release v2.7.2, GPL-2.0-or-later.
- COMAR API 2.4.9 and piksemel 1.3.1: GPL-2.0-or-later. Their archives omit
  standalone license text, so the fixture supplies the complete GPL v2 text
  alongside the original notices.
- pyliblzma 0.5.3: LGPL-3.0-or-later; its original COPYING and full GPL v3 text
  are installed with its notice.
- Other native dependencies retain their nixpkgs package licenses.

The immutable source URLs and hashes are in `tests/tools.nix`; the historical
nixpkgs source is separately locked as `legacy-nixpkgs`. This toolchain exists
for real native-client compatibility checks. It does not replace or relicense
the client's implementation and is not a new Python 2 installer.
