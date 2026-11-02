# Architecture

The modern emitter writes metadata.xml, files.xml and install.tar.xz in PiSi format 1.2. Native client transactions validate the format independently of eopkg. Versioned runtime dependencies precede unpack. Explicit reinstall switches flavor while preserving native identity. A Python 3 adapter reconciles after the actual native transaction and rejects foreign destdir activation. Native config ownership and partial-failure behavior remain authoritative. Historical Python 2 tooling is isolated to the compatibility fixture; the engine remains Python 3.
