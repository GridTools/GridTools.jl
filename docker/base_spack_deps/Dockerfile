# rebuild counter 2  # just a counter to increase when we want a new image
ARG BASE_IMAGE=gridtools_jl_base_image
FROM $BASE_IMAGE as builder
ARG PROJECT_NAME=gridtools_jl
ARG SPACK_ENV_FILE=spack-daint-p100.yaml

# TODO(tehrengruber): Copy spack environment to clean image. Then we don't need to run `spack gc`
#  and `spack clean` anymore. See https://spack.readthedocs.io/en/latest/containers.html for
#  more information.

WORKDIR /opt/${PROJECT_NAME}_env/spack/bin

COPY ./docker/base_spack_deps/${SPACK_ENV_FILE} ./spack_env_${PROJECT_NAME}.yaml
RUN ./spack env create ${PROJECT_NAME}_env spack_env_${PROJECT_NAME}.yaml
# remove all compilers such that everything is built with the compiler we installed
RUN ./spack compiler remove -a gcc
RUN ./spack -e ${PROJECT_NAME}_env compiler find $(./spack location --install-dir gcc@11)
# using --fresh ensures the concretization does not care about the build cache (untested and not
#  used right now as we don't use a build cache yet)
RUN ./spack -e ${PROJECT_NAME}_env concretize --fresh
COPY ./docker/base_spack_deps/run_until_succeed.sh ./run_until_succeed.sh
RUN ./run_until_succeed.sh ./spack -e ${PROJECT_NAME}_env install

# cleanup
RUN ./spack -e ${PROJECT_NAME}_env clean --all
RUN ./spack -e ${PROJECT_NAME}_env gc -y

# strip all the binaries
RUN find -L /opt/${PROJECT_NAME}_env/spack/opt -type f -exec readlink -f '{}' \; | \
    xargs file -i | \
    grep 'charset=binary' | \
    grep 'x-executable\|x-archive\|x-sharedlib' | \
    awk -F: '{print $1}' | xargs strip -x || true

WORKDIR /

# flatten image
FROM scratch
COPY --from=builder / /
