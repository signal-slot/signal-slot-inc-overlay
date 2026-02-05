FROM ubuntu:24.04

ARG QT_VERSION=6.10.2

ENV DEBIAN_FRONTEND=noninteractive

# Build tools and Qt runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake ninja-build git \
        nodejs npm \
        python3 python3-pip python3-venv \
        libgl1-mesa-dev libglib2.0-dev libxkbcommon-dev \
        libfontconfig1-dev libfreetype-dev libdbus-1-dev \
        ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Install aqtinstall and Qt
RUN python3 -m venv /opt/aqt-venv \
    && /opt/aqt-venv/bin/pip install aqtinstall \
    && /opt/aqt-venv/bin/aqt install-qt linux desktop ${QT_VERSION} linux_gcc_64 \
        -m qtlanguageserver qthttpserver \
        --outputdir /opt/qt \
    && rm -rf /opt/aqt-venv

# Pin MCP test server globally
RUN npm install -g @modelcontextprotocol/server-everything

# Qt environment
ENV QT_DIR=/opt/qt/${QT_VERSION}/gcc_64
ENV CMAKE_PREFIX_PATH=${QT_DIR}
ENV PATH=${QT_DIR}/bin:${PATH}
ENV LD_LIBRARY_PATH=${QT_DIR}/lib

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir -p /build && chmod 777 /build
WORKDIR /build
ENTRYPOINT ["/entrypoint.sh"]
