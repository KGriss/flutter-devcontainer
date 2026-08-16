FROM mcr.microsoft.com/devcontainers/base:debian-13

ARG ANDROID_CMDLINE_TOOLS_VERSION=11076708
ARG FLUTTER_CHANNEL=stable

ENV DEBIAN_FRONTEND=noninteractive \
    FLUTTER_HOME=/opt/flutter \
    ANDROID_HOME=/opt/android-sdk \
    JAVA_HOME=/usr/lib/jvm/default-java \
    PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/android-sdk/emulator:${PATH}"

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git wget unzip xz-utils zip sudo \
    default-jdk-headless \
    libgl1 libglu1-mesa libgbm1 libnss3 libpulse0 libsdl2-2.0-0 \
    libx11-6 libx11-xcb1 libxcb1 libxext6 libxi6 libxkbcommon0 \
    libxrender1 libxtst6 \
    usbutils \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -f kvm || true \
    && usermod -aG sudo,plugdev,kvm vscode \
    && echo 'vscode ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/vscode \
    && chmod 0440 /etc/sudoers.d/vscode

RUN mkdir -p /opt/flutter ${ANDROID_HOME}/cmdline-tools /home/vscode/.android/avd \
    && chown -R vscode:vscode /opt/flutter ${ANDROID_HOME} /home/vscode

RUN cd /tmp \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip -O cmdline-tools.zip \
    && unzip -q cmdline-tools.zip -d /tmp/cmdline-tools \
    && mkdir -p ${ANDROID_HOME}/cmdline-tools/latest \
    && mv /tmp/cmdline-tools/cmdline-tools/* ${ANDROID_HOME}/cmdline-tools/latest/ \
    && rm -rf cmdline-tools.zip /tmp/cmdline-tools \
    && chown -R vscode:vscode ${ANDROID_HOME}

USER vscode

RUN yes | sdkmanager --licenses > /dev/null || true
RUN sdkmanager "platform-tools" "platforms;android-34" "platforms;android-35" "build-tools;34.0.0" "emulator"

RUN git clone --depth 1 --branch ${FLUTTER_CHANNEL} https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && git config --global --add safe.directory ${FLUTTER_HOME}

RUN flutter config --no-analytics || true
RUN yes | flutter doctor --android-licenses > /dev/null || true
RUN flutter precache --android || true

ENV DEBIAN_FRONTEND=dialog
