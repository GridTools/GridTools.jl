# rebuild counter 1  # just a counter to increase when we want a new image
ARG BASE_IMAGE=gridtools_jl_spack_deps_image
FROM $BASE_IMAGE as builder
ARG PROJECT_NAME

WORKDIR /opt/${PROJECT_NAME}_env

COPY ./docker/image/setup-env.sh ./setup-env.sh
RUN sed -i "s/%PROJECT_NAME%/$PROJECT_NAME/g" setup-env.sh

# flatten image
FROM scratch
COPY --from=builder / /