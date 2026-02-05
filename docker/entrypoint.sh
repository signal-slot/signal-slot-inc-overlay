#!/bin/bash
set -euo pipefail

cmake -S /src -B /build -G Ninja -DQT_BUILD_TESTS=1
cmake --build /build --parallel
QT_QPA_PLATFORM=offscreen ctest --test-dir /build --output-on-failure "$@"
