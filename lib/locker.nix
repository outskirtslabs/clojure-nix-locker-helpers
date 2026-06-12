# Thin wrappers around clojure-nix-locker's lockfile API. These are the
# low-level escape hatches; the mkClj* builders in this repo derive their
# locking setup from these.
{ clojure-nix-locker }:
let
  defaultMavenRepos = [
    "https://repo1.maven.org/maven2/"
    "https://repo.clojars.org/"
  ];
in
rec {
  inherit defaultMavenRepos;

  # A pkgs set whose `clojure` is pinned to the given JDK, as expected by
  # clojure-nix-locker.
  mkLockerPkgs =
    {
      pkgs,
      jdk ? pkgs.jdk25,
    }:
    pkgs
    // {
      clojure = pkgs.clojure.override { inherit jdk; };
    };

  # Returns clojure-nix-locker's lockfile attrset, plus helper wrappers:
  # { commandLocker, homeDirectory, shellEnv, wrapClojure, wrapPrograms, wrapBabashka }
  mkLockfile =
    {
      pkgs,
      jdk ? pkgs.jdk25,
      src ? null,
      lockfile,
      mavenRepos ? defaultMavenRepos,
      extraPrepInputs ? [ pkgs.git ],
    }:
    let
      locked =
        (import "${clojure-nix-locker}/default.nix" {
          pkgs = mkLockerPkgs { inherit pkgs jdk; };
        }).lockfile
          {
            inherit
              src
              lockfile
              mavenRepos
              extraPrepInputs
              ;
          };
    in
    locked
    // {
      wrapBabashka =
        locked.wrapBabashka or (babashka: locked.wrapPrograms "locked-babashka" [ "${babashka}/bin/bb" ]);
    };

  # Like mkLockfile, but also builds the locker script from a command.
  mkLocker =
    {
      pkgs,
      jdk ? pkgs.jdk25,
      src ? null,
      lockfile,
      command,
      mavenRepos ? defaultMavenRepos,
      extraPrepInputs ? [ pkgs.git ],
    }:
    let
      locked = mkLockfile {
        inherit
          pkgs
          jdk
          src
          lockfile
          mavenRepos
          extraPrepInputs
          ;
      };
    in
    {
      locker = locked.commandLocker command;
      inherit (locked)
        homeDirectory
        shellEnv
        wrapBabashka
        wrapClojure
        wrapPrograms
        ;
    };
}
