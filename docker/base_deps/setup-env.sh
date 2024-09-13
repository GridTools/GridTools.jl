#!/bin/bash
# note: occurrences of %PROJECT_NAME% in this file are replaced when copied into the container
export HOME=/root

. /opt/%PROJECT_NAME%_env/spack/share/spack/setup-env.sh

# gcc is installed outside the env so load it before. In case gcc is not loaded we might run
# into strange errors where partially the spack version and partially the system installed version
# is used.
spack load gcc

spack env activate %PROJECT_NAME%_env

# use this complicated way to load packages in case multiple version are installed
#  this was needed as two version of py-pip are installed (one is only a build
#  dependency). Since we now run `spack gc -y` this is superfluous (build only
#  dependencies are removed before we land here), but we keep it for now.
#PACKAGES_TO_LOAD=("python" "py-pip" "gcc")
#for PKG_NAME in ${PACKAGES_TO_LOAD[@]}; do
#  SHORT_SPEC=$(spack find --explicit --format "{short_spec}" $PKG_NAME)
#  SHORT_SPEC=${SHORT_SPEC%/*}  # remove hash after `/` character
#  spack load $SHORT_SPEC
#done
spack load python py-pip boost julia
