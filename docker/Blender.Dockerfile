# This Dockerfile is based on the original Dockerfile from the Kubric project
# Original Source: https://github.com/google-research/kubric/tree/main

# Modifications made:
# - Update to Ubuntu 22.04 (Jammy)
# - Update to Python 3.10
# - Update to Blender 3.6 with its bpy module
# - Based on: https://github.com/google-research/kubric/issues/224

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

###############################################
# First stage for building Blender bpy module #
###############################################
FROM nvidia/cuda:11.8.0-devel-ubuntu22.04 as builder

# Set environment variables for language and locale
ENV TERM linux
ENV LANGUAGE C.UTF-8
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# Set non-interactive frontend for apt
ARG DEBIAN_FRONTEND=noninteractive

# Install basic dependencies
RUN apt-get update --yes --fix-missing && \
    apt-get install --yes --quiet --no-install-recommends \
    apt-utils sudo build-essential git git-lfs python3-dev python3-pip subversion cmake \
    libx11-dev libxxf86vm-dev libxcursor-dev libxi-dev libxrandr-dev libxinerama-dev libegl-dev \
    libwayland-dev wayland-protocols libxkbcommon-dev libdbus-1-dev linux-libc-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Clone the Blender repository
RUN mkdir -p /blender-git && cd blender-git && \
    git clone --depth 1 --recursive --branch blender-v3.6-release https://projects.blender.org/blender/blender.git

# Install basic building environment and download precompiled libs
WORKDIR /blender-git/blender
RUN ./build_files/build_environment/install_linux_packages.py
RUN ./build_files/utils/make_update.py --use-linux-libraries
RUN mkdir -p /blender-git/lib && cd /blender-git/lib && \
    svn checkout https://svn.blender.org/svnroot/bf-blender/tags/blender-3.6-release/lib/linux_x86_64_glibc_228

# Create a build directory for out-of-source build and compile Blender python module
RUN mkdir /blender-git/build && cd /blender-git/build && \
    cmake ../blender -DWITH_CYCLES_CUDA_BINARIES=ON -DWITH_COMPILER_ASAN=OFF

RUN make update && make -j8 bpy

###########################################
# Final stage for running the application #
###########################################
FROM nvidia/cuda:11.8.0-devel-ubuntu22.04

# Copy the built Blender python module from the builder stage
COPY --from=builder /blender-git/build_linux_bpy/bin /blender-bin
COPY --from=builder /blender-git/lib/linux_x86_64_glibc_228/python/lib/python3.10/site-packages /usr/local/lib/python3.10/dist-packages

# Set environment variables
ENV PYTHONPATH="${PYTHONPATH}:/blender-bin:/usr/local/lib/python3.10/dist-packages"

# Set non-interactive frontend for apt
ARG DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies if necessary
RUN apt-get update --yes --fix-missing && \
    apt-get install --yes --quiet --no-install-recommends \
    python3-dev python3-pip libx11-6 libxxf86vm1 libxcursor1 libxi6 libxrandr2 libxinerama1 \
    libegl1 libwayland-client0 libxkbcommon0 libdbus-1-3 libgomp1 libsm6 libgl1 libopenexr-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set python3 as default python
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 10

WORKDIR /blender-bin