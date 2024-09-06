# rebuild counter 2  # just a counter to increase when we want a new image
ARG BASE_IMAGE=gridtools_jl_spack_deps_image
FROM $BASE_IMAGE as builder
ARG PROJECT_NAME

WORKDIR /opt/${PROJECT_NAME}_env

COPY ./docker/base_deps/setup-env.sh ./setup-env.sh
RUN sed -i "s/%PROJECT_NAME%/$PROJECT_NAME/g" setup-env.sh

WORKDIR /opt/
COPY ./docker/base_deps/install_gt4py.sh ./install_gt4py.sh
RUN . /opt/${PROJECT_NAME}_env/setup-env.sh; ./install_gt4py.sh
RUN . /opt/${PROJECT_NAME}_env/setup-env.sh; pip cache purge

WORKDIR /opt/gridtools_jl_deps
COPY ./Project.toml ./Project.toml
RUN mkdir src
RUN touch src/GridTools.jl
RUN . /opt/${PROJECT_NAME}_env/setup-env.sh; julia --project=. -e "using Pkg; Pkg.instantiate(); Pkg.build()"
RUN rm -rf /opt/gridtools_jl_deps

# flatten image
FROM scratch
COPY --from=builder / /
