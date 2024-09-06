# just a counter to trigger rebuilds: 2
FROM ubuntu:23.04 as builder
ARG INSTALL_CUDA_DRIVER=false
ARG CUDA_DRIVER_VERSION
ARG CPU_ARCH

SHELL ["/bin/bash", "-c"]

RUN apt-get update \
  && env DEBIAN_FRONTEND=noninteractive TZ=Europe/Zurich apt-get -yqq install --no-install-recommends build-essential ca-certificates coreutils curl environment-modules file gfortran git git-lfs gpg gpg-agent lsb-release openssh-client python3 python3-distutils python3-venv unzip zip

RUN apt-get clean

WORKDIR /opt/gridtools_jl_env

COPY ./docker/base/install_cuda_driver.sh ./install_cuda_driver.sh
RUN if [ "x$INSTALL_CUDA_DRIVER" == "xtrue" ]; then ./install_cuda_driver.sh $CUDA_DRIVER_VERSION; fi

RUN git clone --depth 1 -c feature.manyFiles=true https://github.com/spack/spack.git

# In case the driver is not installed this fixes missing `-lcuda` errors when installing cupy.
#RUN git remote add origin_tehrengruber https://github.com/tehrengruber/spack.git
#RUN git fetch origin_tehrengruber
#RUN git checkout --track origin_tehrengruber/fix_libcuda_not_found

WORKDIR ./spack/bin

# avoid issues with proxy in CSCS CI
RUN ./spack config add packages:all:target:[$CPU_ARCH]

RUN ./spack install gcc@11

# cleanup
RUN ./spack clean --all
RUN ./spack gc -y

# strip all the binaries
RUN find -L /opt/gridtools_jl_env/spack/opt -type f -exec readlink -f '{}' \; | \
    xargs file -i | \
    grep 'charset=binary' | \
    grep 'x-executable\|x-archive\|x-sharedlib' | \
    awk -F: '{print $1}' | xargs strip -x || true

WORKDIR /

# flatten image
FROM scratch
COPY --from=builder / /
