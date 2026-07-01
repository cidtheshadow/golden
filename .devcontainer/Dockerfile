FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8

# Install base dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-17-jdk \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 (LTS) for Firebase CLI and Functions
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Firebase CLI
RUN npm install -g firebase-tools

# Create a non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update && apt-get install -y sudo \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME

# Set Flutter environment variables
ENV FLUTTER_HOME=/home/$USERNAME/flutter
ENV PATH=$PATH:$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:/home/$USERNAME/.pub-cache/bin

# Install Flutter (stable channel)
RUN git clone https://github.com/flutter/flutter.git -b stable --depth 1 $FLUTTER_HOME

# Pre-cache Flutter artifacts for web and linux targets
RUN flutter precache --web --linux --no-android --no-ios

# Accept Android licenses & pre-download tooling (skipped here; handled at container start)
RUN flutter config --no-analytics

WORKDIR /workspaces/GoldenCare_App
