# rebuild counter 1  # just a counter to increase when we want a new image
ARG BASE_IMAGE=gridtools_jl_spack_deps_image
FROM $BASE_IMAGE as builder
ARG PROJECT_NAME

WORKDIR /opt/${PROJECT_NAME}_env

COPY ./docker/base_deps/setup-env.sh ./setup-env.sh
RUN sed -i "s/%PROJECT_NAME%/$PROJECT_NAME/g" setup-env.sh

WORKDIR /opt/
RUN . /opt/${PROJECT_NAME}_env/setup-env.sh; ./install_gt4py.sh
RUN . /opt/${PROJECT_NAME}_env/setup-env.sh; pip cache purge

WORKDIR /opt/gridtools_jl_deps
COPY ./Project.toml ./Project.toml
COPY ./Manifest.toml ./Manifest.toml
RUN . /opt/${PROJECT_NAME}_env/setup-env.sh; julia --project=. -e "using Pkg; Pkg.instantiate(); Pkg.build()"
RUN rm -rf /opt/gridtools_jl_deps

# flatten image
FROM scratch
COPY --from=builder / /
