# Migration

## From a hand-written clojure-nix-locker flake

The typical pre-helpers flake had a ~60 line `default` package and a ~25 line
`locker` package duplicating the alias and build information. That maps to:

Before (abridged):

```nix
default = pkgs:
  let
    jdkPackage = pkgs.jdk25;
    clojure = pkgs.clojure.override { jdk = jdkPackage; };
    gitRev = if self ? rev then self.rev else if self ? dirtyRev then self.dirtyRev else "dirty";
    projectSrc = pkgs.lib.cleanSourceWith { src = ./.; filter = ...20 lines... };
    clojureLocker = devenv.clojure.mkLockfile { inherit pkgs; jdk = jdkPackage; src = ./.; lockfile = "./deps-lock.json"; };
  in
  pkgs.stdenv.mkDerivation {
    pname = "sfv";
    version = "0.1.0";
    src = projectSrc;
    nativeBuildInputs = [ clojure pkgs.coreutils pkgs.findutils pkgs.git jdkPackage ];
    buildPhase = ''
      source ${clojureLocker.shellEnv}
      export JAVA_HOME=... JAVA_CMD=... GITLIBS=...
      clojure -Srepro -X:deps prep :aliases '[:kaocha :build]'
      clojure -Srepro -M:kaocha
      clojure -Srepro -T:build jar
    '';
    installPhase = '' cp target/*.jar $out/ ... '';
  };

locker = pkgs: ...same lets again... clojureLocker.commandLocker ''
  export HOME="$tmp/home" ...
  clojure -Srepro -X:deps prep :aliases "[:kaocha :build]"
  clojure -Srepro -P -M:kaocha
  clojure -Srepro -T:build jar
'';
```

After:

```nix
packages = {
  default = pkgs: clj-helpers.lib.mkCljLib {
    inherit pkgs;
    name = "sfv";
    version = "0.1.0";
    src = ./.;
    prepAliases = [ "kaocha" "build" ];
    prefetchAliases = [ "kaocha" ];
    checkCommand = "clojure -Srepro -M:kaocha";
    gitRev = clj-helpers.lib.gitRev self;
  };
  locker = pkgs: self.packages.${pkgs.system}.default.locker;
};
```

Mapping notes:

- The source filter is built in (`cleanCljSource`); add project-specific
  exclusions with `extraSrcExcludes = [ "bench/results" "test-data" ]`.
- Tests move from the buildPhase into `checkCommand` (a proper checkPhase;
  disable ad hoc with `doCheck = false`).
- Anything else you set on the derivation (env vars, `LD_LIBRARY_PATH`,
  extra `nativeBuildInputs`) passes straight through.
- The lockfile format is unchanged; you normally do not need to regenerate
  `deps-lock.json` when migrating, as long as the aliases you cover are the
  same.

For an application (uberjar + launcher binary) use `mkCljBin` instead of
`mkCljLib`; instead of a hand-rolled `makeWrapper` install phase you get
`$out/bin/<name>` for free.

## From clj-nix

API differences to be aware of:

- No `main-ns` / `compileCljOpts` / `javacOpts` / `uberOpts`: building is
  delegated to your project's tools.build `:build` alias (you need one; its
  `uber` task decides the main class). Override `buildCommand` if your alias
  or task names differ.
- No `withLeiningen`.
- `projectSrc` is called `src`.
- The lockfile is clojure-nix-locker's format, not clj-nix's; generate it
  with `nix run .#locker` instead of the clj-nix deps-lock app.
- `customJdk`, `mkGraalBin`, `mkCljCli`, and `mkCljApp` keep clj-nix's
  shape (and `mkCljApp`'s `customJdk` / `nativeImage` options work the same).
- Helpers take `pkgs` as an argument; there is no required overlay.
