# API

All functions live on the flake's `lib` output and take `pkgs` explicitly.

```nix
clj-helpers.lib.mkCljBin { pkgs = ...; ... }
```

## Shared arguments (mkCljBin and mkCljLib)

| Argument           | Default                       | Description |
|--------------------|-------------------------------|-------------|
| `pkgs`             | required                      | Nixpkgs package set |
| `name`             | required                      | Derivation pname; also the wrapper binary name for `mkCljBin` |
| `version`          | `"DEV"`                       | Derivation version |
| `src`              | required                      | Project source (path) |
| `jdk`              | `pkgs.jdk25`                  | JDK used to build and run; `clojure` is overridden to use it |
| `cleanSrc`         | `true`                        | Apply the default source filter (see `cleanCljSource`) |
| `extraSrcExcludes` | `[ ]`                         | Extra root-relative paths to exclude from the source |
| `lockfile`         | `"deps-lock.json"`            | Lockfile path relative to the project root |
| `mavenRepos`       | maven central + clojars       | Repositories locked maven deps are fetched from |
| `extraPrepInputs`  | `[ pkgs.git ]`                | Extra inputs for clojure-nix-locker's prep of git deps |
| `prepAliases`      | `[ ]`                         | Run `clojure -Srepro -X:deps prep :aliases '[:a :b]'` before building and locking |
| `prefetchAliases`  | `[ ]`                         | Each entry `a` adds `clojure -Srepro -P -M:a` to the locker (cover your test/dev aliases here) |
| `checkCommand`     | `null`                        | Command for the checkPhase; when null, no checks run |
| `buildCommand`     | `-T:build uber` / `-T:build jar` | Build command (mkCljBin / mkCljLib defaults) |
| `lockCommand`      | `null`                        | Replace the entire derived locker command |
| `gitRev`           | `null`                        | Exported as `GIT_REV` in build/check phases (use `gitRev self`) |
| `java-opts`        | `[ ]`                         | JVM options baked into the wrapper script (mkCljBin only) |
| `nativeBuildInputs`| `[ ]`                         | Extra build inputs; clojure, the jdk, coreutils, findutils, and git are always present |

Any other attribute is forwarded to `mkDerivation` (`LD_LIBRARY_PATH`,
`postInstall`, env vars, ...). `passthru` and `meta` are merged with the
helper-provided values.

Build phases get this environment automatically: the locked dependency caches
(`HOME`, `JAVA_TOOL_OPTIONS=-Duser.home=...`), `GITLIBS`, `JAVA_HOME`,
`JAVA_CMD`, `-Djava.io.tmpdir=$TMPDIR`, and optionally `GIT_REV`.

When `src` contains a root `bb.edn`, the derived locker also runs `bb prepare`
so Babashka deps enter the same lockfile.

## mkCljBin

Builds an uberjar with the project's `:build` alias and installs:

- `$out/bin/<name>`: wrapper script (`exec java <java-opts> -jar <jar>`)
- `$out/nix-support/jar-path`: text file containing the jar's store path
- `$lib/<original-name>.jar` and a stable `$lib/uber.jar` symlink

The jar is located with `find target -name '*standalone.jar'` falling back to
any `*.jar`; set `jarPath` in a `preInstall` hook to override.

passthru: `locker`, `shellEnv`, `homeDirectory`, `jdk`.

## mkCljLib

Builds a library jar with the project's `:build` alias and installs it into
`$out/`, recording its path in `$out/nix-support/jar-path`.
Same passthru as `mkCljBin`.

## customJdk

```nix
clj-helpers.lib.customJdk {
  inherit pkgs;
  cljDrv = myApp;             # from mkCljBin (optional)
  jdkBase = pkgs.jdk25_headless;
  jdkModules = null;          # null = derive with jdeps from the uberjar
  extraJdkModules = [ ];
  locales = null;
  java-opts = [ ];
}
```

Creates a jlink-minimized JDK. With `cljDrv` set, the result has outputs
`out` (wrapper binary + app) and `jdk` (the trimmed runtime), and passthru
`jarPath` and `locker`. Without `cljDrv` it builds just a minimal JDK
(modules from `jdkModules`, default `java.base`).

`jdkBase` must be at least the JDK major version the app was compiled with.

## mkGraalBin

```nix
clj-helpers.lib.mkGraalBin {
  inherit pkgs;
  cljDrv = myApp;             # from mkCljBin
  graalvm = pkgs.graalvmPackages.graalvm-ce;
  extraNativeImageBuildArgs = [ ];
  graalvmXmx = "";            # empty = buildGraalvmNativeImage default
}
```

Compiles the uberjar to a native binary using nixpkgs'
`buildGraalvmNativeImage`, with clj-easy's graal-build-time feature on the
classpath so Clojure classes initialize at build time.

## mkCljApp

Module-based all-in-one, mirroring clj-nix:

```nix
clj-helpers.lib.mkCljApp {
  inherit pkgs;
  modules = [
    {
      name = "my-app";
      version = "1.0.0";
      src = ./.;
      prepAliases = [ "dev" ];
      prefetchAliases = [ "dev:test" ];
      checkCommand = "clojure -Srepro -M:dev:test";

      # pick at most one:
      customJdk.enable = true;
      # nativeImage.enable = true;
      # nativeImage.static = true;   # musl static binary
    }
  ];
}
```

Options are the shared arguments above plus `customJdk.{enable, jdkModules,
extraJdkModules, locales}` and `nativeImage.{enable, graalvm,
extraNativeImageBuildArgs, graalvmXmx, static}`. The result is the mkCljBin
derivation, wrapped by customJdk or mkGraalBin when enabled, with
`passthru.locker` preserved.

## mkCljCli

```nix
clj-helpers.lib.mkCljCli {
  jdkDrv = myCustomJdk;       # result of customJdk with cljDrv
  java-opts = [ "-Xmx512m" ];
  extra-args = [ ];
}
```

Returns a list of strings: `[ ".../bin/java" "-Xmx512m" "-jar" ".../uber.jar" ]`,
handy for a NixOS module's `ExecStart`.

## Low-level: mkLockfile and mkLocker

Thin wrappers over clojure-nix-locker for cases the builders don't cover
(multi-artifact builds, exotic prep steps — see docs/migration.md):

```nix
locked = clj-helpers.lib.mkLockfile {
  inherit pkgs;
  jdk = pkgs.jdk25;
  src = ./.;
  lockfile = "./deps-lock.json";
};
# locked.commandLocker, locked.shellEnv, locked.homeDirectory,
# locked.wrapClojure, locked.wrapPrograms, locked.wrapBabashka
withLocker = clj-helpers.lib.mkLocker {
  inherit pkgs;
  src = ./.;
  lockfile = "./deps-lock.json";
  command = '' ... arbitrary commands that populate ~/.m2 and ~/.gitlibs ... '';
};
# withLocker.locker etc.
```

## Utilities

- `cleanCljSource { pkgs, src, extraExcludes ? [ ] }`: `cleanSourceWith`
  filter excluding `.git` anywhere plus these root-relative paths: `target`,
  `.cpcache`, `.clj-kondo/.cache`, `.clojure-mcp`, `.direnv`,
  `.envrc`, `.github`, `.lsp`, `.nrepl-port`, `.tmuxb_session`,
  `extra`, `node_modules`, `result`.
- `gitRev self`: `self.rev`, else `self.dirtyRev`, else `"dirty"`.
- `defaultMavenRepos`: maven central and clojars.
