# clojure-nix-locker-helpers

High-level Nix builders for Clojure projects, in the style of
[clj-nix], powered by [clojure-nix-locker].

This flake provides:

| Helper       | Purpose                                                                |
|--------------|------------------------------------------------------------------------|
| `mkCljBin`   | Build an application: uberjar plus a `bin/<name>` wrapper script        |
| `mkCljLib`   | Build a library jar                                                     |
| `mkCljApp`   | Module-based wrapper around `mkCljBin` + `customJdk` / `mkGraalBin`     |
| `customJdk`  | Minimized JDK runtime via `jlink`, optionally bundling your app         |
| `mkGraalBin` | Native binary via GraalVM `native-image`                                |
| `mkCljCli`   | Command list for running a `customJdk` app (systemd `ExecStart`, etc.)  |

plus the low-level escape hatches `mkLockfile` / `mkLocker` (thin wrappers
over clojure-nix-locker) and utilities `cleanCljSource` and `gitRev`.

## Why

clj-nix has lovely high-level builders, but its lock-time dependency
resolution reimplements tools.deps and tends to fight Clojure tooling.
clojure-nix-locker takes the opposite approach: at lock time it runs your
real commands (`clojure -P`, `clojure -T:build uber`, ...) and crawls the
resulting `~/.m2` and `~/.gitlibs` caches into a lockfile; at build time it
recreates those caches and your build runs offline as if nothing happened.
Aliases, git deps, and prep steps "just work".

What was missing was the high-level layer: without it, every project flake
carries a hundred lines of `mkDerivation` and locker boilerplate. This repo
is that layer. You describe your project's dependency surface once (aliases,
build command, check command) and get both the package and a matching
lockfile-updater script from the same declaration.

## Quick start

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    clj-helpers.url = "github:outskirtslabs/clojure-nix-locker-helpers";
    clj-helpers.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, clj-helpers }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      packages.x86_64-linux = rec {
        default = clj-helpers.lib.mkCljBin {
          inherit pkgs;
          name = "my-app";
          version = "0.1.0";
          src = ./.;
          prepAliases = [ "dev" "test" ];
          prefetchAliases = [ "dev:test" ];
          checkCommand = "clojure -Srepro -M:dev:test";
          gitRev = clj-helpers.lib.gitRev self;
        };

        # regenerates ./deps-lock.json; run from the project root
        locker = default.locker;
      };
    };
}
```

Then:

```bash
nix run .#locker   # generate/refresh deps-lock.json (needs network)
nix build          # build the app offline
./result/bin/my-app
```

The project is expected to provide a tools.build `:build` alias; the default
build command is `clojure -Srepro -T:build uber` for `mkCljBin` and
`clojure -Srepro -T:build jar` for `mkCljLib`. Override with `buildCommand`.

## The one-declaration contract

Everything the build needs from the network must be in the lockfile, so the
locker has to run the same commands as the build. The helpers guarantee this
by deriving the locker script from the same arguments as the derivation:

1. `clojure -X:deps prep :aliases '[...]'` for `prepAliases`
2. `clojure -P -M:<alias>` for each entry in `prefetchAliases`
3. `bb prepare` when the source root contains `bb.edn`
4. `buildCommand`, executed for real

If you override `lockCommand`, you take this guarantee into your own hands.

## Documentation

- [docs/api.md](docs/api.md) — every function and option
- [docs/locking.md](docs/locking.md) — how locking works, when to regenerate
- [docs/migration.md](docs/migration.md) — migrating hand-written flakes and clj-nix projects

## License

EPL-2.0. Parts of this code base are adapted from [clj-nix]
(EPL-2.0). [clojure-nix-locker] (GPL-3.0) is consumed as a flake input and
not redistributed here.

[clj-nix]: https://github.com/jlesquembre/clj-nix
[clojure-nix-locker]: https://github.com/bevuta/clojure-nix-locker
