# Wrapper script template for jar-based binaries.
pkgs:
pkgs.writeText "clj-binary-template" ''
  #!${pkgs.runtimeShell}

  exec "@jdk@/bin/java" @javaOpts@ \
      -jar "@jar@" "$@"
''
