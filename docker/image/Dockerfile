# rebuild counter 1  # just a counter to increase when we want a new image
ARG BASE_IMAGE=gridtools_jl_spack_deps_image
FROM $BASE_IMAGE as builder
ARG PROJECT_NAME

COPY ./ /opt/GridTools

WORKDIR /opt/GridTools
RUN . /opt/${PROJECT_NAME}_env/setup-env.sh; julia --project=. -e "using Pkg; Pkg.instantiate(); Pkg.build()"

# flatten image
FROM scratch
COPY --from=builder / /