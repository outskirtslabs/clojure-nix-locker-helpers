# Shared machinery for mkCljBin and mkCljLib: argument handling, the build
# environment preamble, and derivation of the locker command from the same
# dependency information used by the build.
{ clojure-nix-locker }:
let
  source = import ./source.nix;
  lockerLib = import ./locker.nix { inherit clojure-nix-locker; };
in
rec {
  inherit (lockerLib) defaultMavenRepos;

  gitRevOf =
    self:
    if self ? rev then
      self.rev
    else if self ? dirtyRev then
      self.dirtyRev
    else
      "dirty";

  # Arguments consumed by mkContext. Anything else the caller passes is
  # forwarded verbatim to mkDerivation.
  contextArgNames = [
    "pkgs"
    "name"
    "version"
    "src"
    "jdk"
    "cleanSrc"
    "extraSrcExcludes"
    "lockfile"
    "mavenRepos"
    "extraPrepInputs"
    "prepAliases"
    "prefetchAliases"
    "checkCommand"
    "buildCommand"
    "lockCommand"
    "gitRev"
    "java-opts"
    "nativeBuildInputs"
    "passthru"
    "meta"
  ];

  # Wrapper script template for jar-based binaries.
  binaryTemplate = import ./binary-template.nix;

  mkContext =
    {
      pkgs,
      name,
      version ? "DEV",
      src,
      jdk ? pkgs.jdk25,
      cleanSrc ? true,
      extraSrcExcludes ? [ ],
      lockfile ? "deps-lock.json",
      mavenRepos ? defaultMavenRepos,
      extraPrepInputs ? [ pkgs.git ],
      prepAliases ? [ ],
      prefetchAliases ? [ ],
      checkCommand ? null,
      buildCommand,
      lockCommand ? null,
      gitRev ? null,
      java-opts ? [ ],
      nativeBuildInputs ? [ ],
      ...
    }@args:
    let
      lib = pkgs.lib;
      clojure = pkgs.clojure.override { inherit jdk; };

      projectSrc =
        if cleanSrc then
          source.cleanCljSource {
            inherit pkgs src;
            extraExcludes = extraSrcExcludes;
          }
        else
          src;

      lockfileRel = lib.removePrefix "./" lockfile;

      locked = lockerLib.mkLockfile {
        inherit
          pkgs
          jdk
          mavenRepos
          extraPrepInputs
          ;
        src = projectSrc;
        lockfile = "./${lockfileRel}";
      };

      prepCommand = lib.optionalString (prepAliases != [ ]) ''
        clojure -Srepro -X:deps prep :aliases '[${lib.concatMapStringsSep " " (a: ":" + a) prepAliases}]'
      '';

      # Environment for build/check phases: locked dependency caches plus the
      # JAVA_* variables every project build ends up needing.
      buildEnvSetup = ''
        source ${locked.shellEnv}
        export GITLIBS="$HOME/.gitlibs"
        export JAVA_HOME="${jdk.home}"
        export JAVA_CMD="${jdk}/bin/java"
        export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -Djava.io.tmpdir=$TMPDIR"
      ''
      + lib.optionalString (gitRev != null) ''
        export GIT_REV="${gitRev}"
      '';

      # The locker runs the same prep and build commands as the nix build so
      # the resulting lockfile is guaranteed to cover them, plus explicit
      # prefetches for aliases that are only exercised at check time.
      defaultLockCommand = ''
        export HOME="$tmp/home"
        export GITLIBS="$HOME/.gitlibs"
        export JAVA_TOOL_OPTIONS="-Duser.home=$HOME"
        unset CLJ_CACHE CLJ_CONFIG XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME
        export JAVA_HOME="${jdk.home}"
        export JAVA_CMD="${jdk}/bin/java"
        export GIT_REV="lockfile-generation"
        export PATH="${clojure}/bin:${jdk}/bin:$PATH"

      ''
      + prepCommand
      + lib.concatMapStrings (a: ''
        clojure -Srepro -P -M:${a}
      '') prefetchAliases
      + buildCommand
      + "\n";

      locker = locked.commandLocker (if lockCommand != null then lockCommand else defaultLockCommand);

      buildPhase = ''
        runHook preBuild

        ${buildEnvSetup}
        ${prepCommand}
        ${buildCommand}

        runHook postBuild
      '';

      checkPhase = lib.optionalString (checkCommand != null) ''
        runHook preCheck

        ${buildEnvSetup}
        ${checkCommand}

        runHook postCheck
      '';

      baseNativeBuildInputs = [
        clojure
        jdk
        pkgs.coreutils
        pkgs.findutils
        pkgs.git
      ]
      ++ nativeBuildInputs;

      passthru = {
        inherit locker jdk;
        inherit (locked) shellEnv homeDirectory;
      }
      // (args.passthru or { });
    in
    {
      inherit
        pkgs
        lib
        clojure
        jdk
        name
        version
        projectSrc
        locked
        locker
        buildEnvSetup
        buildPhase
        checkPhase
        checkCommand
        baseNativeBuildInputs
        passthru
        java-opts
        ;
      extraAttrs = builtins.removeAttrs args contextArgNames;
      meta = args.meta or { };
    };
}
