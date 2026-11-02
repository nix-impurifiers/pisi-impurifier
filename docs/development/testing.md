# Testing

QEMU runs actual PiSi from the release used by the upstream package definition. Pinned historical dependencies include real piksemel, plyvel, pyliblzma and COMAR client code. Parser tests run with fixed interpreter paths. VM native checks stay enabled; COMAR is explicitly disabled through its supported flag. Test version gates before unpack, dependency solving, offline recovery, native edited/unedited config, batching, services/accounts/admin intent, driver updates, foreign roots, removal and GC. Outer init is NixOS. This does not establish COMAR daemon or Mudur boot integration.
