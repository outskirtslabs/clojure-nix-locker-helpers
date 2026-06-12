# How locking works

## The clojure-nix-locker model

Unlike clj-nix or clj2nix, clojure-nix-locker does not reimplement
tools.deps resolution. Instead:

1. At lock time, it runs real commands (`clojure -P`, `clojure -T:build
   uber`, ...) in a scratch HOME with network access, letting Clojure
   populate `~/.m2/repository` and `~/.gitlibs` as usual.
2. It crawls those caches and writes every maven artifact (URL + sha256) and
   git dependency (url + rev + sha256) into `deps-lock.json`.
3. At build time, it recreates the caches from the lockfile as a Nix
   derivation (`homeDirectory`) and points `HOME` / `user.home` at it. Your
   build then runs fully offline.

The upside: aliases, `:deps prep`, git deps, and anything else tools.deps can
do "just works", because the real tooling did the resolution. The downside:
the lockfile only covers what your lock command actually exercised.

## What the helpers add

`mkCljBin` / `mkCljLib` / `mkCljApp` derive the lock command from the same
arguments that drive the build, so the two cannot drift:

```
export HOME="$tmp/home"            # scratch home provided by the locker
export GITLIBS="$HOME/.gitlibs"
unset CLJ_CACHE CLJ_CONFIG XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME
export GIT_REV="lockfile-generation"

clojure -Srepro -X:deps prep :aliases '[...]'   # prepAliases
clojure -Srepro -P -M:dev:test                  # one per prefetchAliases entry
bb prepare                                      # if bb.edn exists
clojure -Srepro -T:build uber                   # buildCommand, run for real
```

The build command is run for real (not just `-P`) because tools.build
resolves its own dependencies and compilation can pull in more than a
prefetch sees.

The derived locker is exposed as `passthru.locker`, so a flake exposes it as:

```nix
packages.locker = pkgs: self.packages.${pkgs.system}.default.locker;
```

## Generating and updating the lockfile

From the project root (network required):

```bash
nix run .#locker
git add deps-lock.json
```

Regenerate whenever:

- `deps.edn`, `bb.edn`, or any alias used by the build/check changes
- the `prepAliases` / `prefetchAliases` / `buildCommand` / `checkCommand`
  arguments change in a way that needs new dependencies
- you bump the JDK in a way that changes resolved artifacts

If the lockfile is missing, evaluation still works (the dependency home is
just empty) so that the locker itself can always be built; the actual
package build will fail until you generate it.

## Covering check-time dependencies

`checkCommand` runs inside the offline build, so its dependencies must be in
the lockfile too. Cover them with `prefetchAliases`: if your check is
`clojure -Srepro -M:dev:kaocha`, add `prefetchAliases = [ "dev:kaocha" ]`.

## When the derived command is not enough

Some projects need more, e.g. forcing prep of a particular git dependency or
warming nested builds (see busker for an extreme example). Two options:

- `lockCommand`: replace the derived command entirely; you are responsible
  for covering prep, prefetch, Babashka deps, and build.
- Drop down to `mkLockfile` / `mkLocker` and write the package by hand.
