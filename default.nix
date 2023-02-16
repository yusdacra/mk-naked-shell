# Parts of this file are taken from https://github.com/numtide/devshell/blob/main/modules/devshell.nix
# devshell license:
# MIT License
# Copyright (c) 2021 Numtide and contributors
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
{
  bashInteractive,
  writeText,
  writeScript,
  buildEnv,
  callPackage,
  ...
}: {
  name,
  packages,
  shellHook ? "",
  interactiveShellHook ? "",
  meta ? {},
  passthru ? {},
  bashPackage ? bashInteractive,
}: let
  bashBin = "${bashPackage}/bin";
  bashPath = "${bashPackage}/bin/bash";

  mkNakedShell = callPackage ./mkNakedShell.nix {};

  # Write a bash profile to load
  envBash = writeText "devshell-env.bash" ''
    if [[ -n ''${IN_NIX_SHELL:-} || ''${DIRENV_IN_ENVRC:-} = 1 ]]; then
      # We know that PWD is always the current directory in these contexts
      export PRJ_ROOT=$PWD
    elif [[ -z ''${PRJ_ROOT:-} ]]; then
      echo "ERROR: please set the PRJ_ROOT env var to point to the project root" >&2
      return 1
    fi
    # Expose the folder that contains the assembled environment.
    export DEVSHELL_DIR=@DEVSHELL_DIR@
    # Prepend the PATH with the devshell dir and bash
    PATH=''${PATH%:/path-not-set}
    PATH=''${PATH#${bashBin}:}
    export PATH=$DEVSHELL_DIR/bin:${bashBin}:$PATH
    ${shellHook}
    # Interactive sessions
    if [[ $- == *i* ]]; then
      ${interactiveShellHook}
    fi
    # Interactive session
  '';

  # This is our entrypoint script.
  entrypoint = writeScript "${name}-entrypoint" ''
    #!${bashPath}
    # Script that sets-up the environment. Can be both sourced or invoked.
    export DEVSHELL_DIR=@DEVSHELL_DIR@
    # If the file is sourced, skip all of the rest and just source the env
    # script.
    if [[ $0 != "''${BASH_SOURCE[0]}" ]]; then
      source "$DEVSHELL_DIR/env.bash"
      return
    fi
    # Be strict!
    set -euo pipefail
    if [[ $# = 0 ]]; then
      # Start an interactive shell
      exec "${bashPath}" --rcfile "$DEVSHELL_DIR/env.bash" --noprofile
    elif [[ $1 == "-h" || $1 == "--help" ]]; then
      cat <<USAGE
    Usage: ${name}
      $0 -h | --help          # show this help
      $0 [--pure]             # start a bash sub-shell
      $0 [--pure] <cmd> [...] # run a command in the environment
    Options:
      * --pure : execute the script in a clean environment
    USAGE
      exit
    elif [[ $1 == "--pure" ]]; then
      # re-execute the script in a clean environment
      shift
      exec /usr/bin/env -i -- "HOME=$HOME" "PRJ_ROOT=$PRJ_ROOT" "$0" "$@"
    else
      # Start a script
      source "$DEVSHELL_DIR/env.bash"
      exec -- "$@"
    fi
  '';

  # Builds the DEVSHELL_DIR with all the dependencies
  devshell_dir = buildEnv {
    name = "devshell-dir";
    paths = packages;
    postBuild = ''
      substitute ${envBash} $out/env.bash --subst-var-by DEVSHELL_DIR $out
      substitute ${entrypoint} $out/entrypoint --subst-var-by DEVSHELL_DIR $out
      chmod +x $out/entrypoint
    '';
  };
in
  mkNakedShell {
    inherit name meta passthru;
    profile = devshell_dir;
  }
