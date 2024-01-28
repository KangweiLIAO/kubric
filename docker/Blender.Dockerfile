# This Dockerfile is based on the original Dockerfile from the Kubric project
# Original Source: https://github.com/google-research/kubric/tree/main

# Modifications made:
# - Update to Ubuntu 22.04 (Jammy)
# - Update to Python 3.10
# - Update to Blender 3.6 with its bpy module

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0


FROM nvidia/cuda:12.3.1-base-ubuntu22.04

# Set environment variables for language and locale
ENV TERM linux
ENV LANGUAGE C.UTF-8
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# Set non-interactive frontend for apt
ARG DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update --yes --fix-missing \
    && apt-get install --yes --quiet --no-install-recommends \
    python3-dev python3-pip python3-distutils \
    bison autoconf automake libtool yasm nasm tcl libasound2-dev \
	libsndio-dev portaudio19-dev libportaudio2 pulseaudio libpulse-dev \
	curl apt-utils software-properties-common build-essential \
	git subversion cmake libx11-dev libxxf86vm-dev libxcursor-dev \
	libxi-dev libxrandr-dev libxinerama-dev libglew-dev sudo \
    # for GIF creation
    imagemagick \
    # OpenEXR
    libopenexr-dev \
    curl ca-certificates git libffi-dev libssl-dev libx11-dev \
    libxxf86vm-dev libxcursor-dev libxi-dev libxrandr-dev  \
    libxinerama-dev libglew-dev zlib1g-dev \
    # further (optional) python build dependencies
    libbz2-dev libgdbm-dev liblzma-dev libncursesw5-dev  \
    libreadline-dev libsqlite3-dev uuid-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone the Blender repository
RUN mkdir -p /blender-git
WORKDIR /blender-git
RUN git clone --recursive --branch blender-v3.6-release https://projects.blender.org/blender/blender.git

# Install basic building environment
RUN /blender-git/blender/build_files/build_environment/install_linux_packages.py

# Download precompiled libs
RUN mkdir -p /blender-git/lib
WORKDIR /blender-git/lib
RUN svn checkout https://svn.blender.org/svnroot/bf-blender/tags/blender-3.6-release/lib/linux_x86_64_glibc_228

# Set the working directory to the Blender runtime directory
WORKDIR /blender-git/blender

# Enable CUDA support: https://github.com/google-research/kubric/issues/224
COPY ./docker/enable_cuda_patch.txt /blender-git/blender
RUN patch -p1 < /blender-git/blender/enable_cuda_patch.txt

# Compile Blender python module
RUN make update && make -j8 bpy

# Set python3 as default python
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 10

# Set PYTHONPATH environment variable
ENV PYTHONPATH="${PYTHONPATH}:/blender-git/build_linux_bpy/bin:/blender-git/lib/linux_x86_64_glibc_228/python/lib/python3.10/site-packages"
