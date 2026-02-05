#!/bin/bash
# scripts/qt-version-update.sh
#
# Batch update Qt module versions: build, test, tag, push, and update overlay ebuilds.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Module definitions
# format: submodule_dir:portage_dir:branch:github_repo_name
MODULES=(
    "modules/qtmcp:dev-qt/qtmcp:main:qtmcp"
    "modules/qtvncclient:dev-qt/qtvncclient:main:QtVncClient"
    "modules/qtpsd:dev-qt/qtpsd:main:qtpsd"
)

# Defaults
QT_VERSION=""
SELECTED_MODULES=()
DRY_RUN=false
NO_PUSH=false
NO_OVERLAY=false
NO_DOCKER=false
CONTAINER_ENGINE=""

# Result tracking
declare -A MODULE_STATUS

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Batch update Qt module versions, build, test, tag, push, and update overlay ebuilds.

Options:
  --qt-version VERSION   Target Qt version (default: auto-detect from qmake6)
  --module NAME          Process only named module (can be specified multiple times)
  --dry-run              Show what would be done without making changes
  --no-push              Skip pushing to remote repositories
  --no-overlay           Skip overlay ebuild/Manifest updates
  --no-docker            Build/test on host instead of Docker container
  --help                 Show this help message

Examples:
  $(basename "$0")                          # Auto-detect Qt version, process all
  $(basename "$0") --qt-version 6.10.2      # Specific version
  $(basename "$0") --module qtmcp --dry-run  # Dry run for qtmcp only
  $(basename "$0") --no-docker --module qtvncclient  # Build on host
EOF
    exit 0
}

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

warn() {
    echo "[$(date '+%H:%M:%S')] WARNING: $*" >&2
}

error() {
    echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2
}

detect_qt_version() {
    if command -v qmake6 >/dev/null; then
        qmake6 -query QT_VERSION
    else
        error "qmake6 not found. Please specify --qt-version."
        exit 1
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --qt-version)
                QT_VERSION="$2"
                shift 2
                ;;
            --module)
                SELECTED_MODULES+=("$2")
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-push)
                NO_PUSH=true
                shift
                ;;
            --no-overlay)
                NO_OVERLAY=true
                shift
                ;;
            --no-docker)
                NO_DOCKER=true
                shift
                ;;
            --help)
                usage
                ;;
            *)
                error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

should_process_module() {
    local mod_name="$1"
    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then
        return 0
    fi
    for sel in "${SELECTED_MODULES[@]}"; do
        if [[ "$sel" == "$mod_name" ]]; then
            return 0
        fi
    done
    return 1
}

detect_container_engine() {
    if command -v docker >/dev/null; then
        CONTAINER_ENGINE=docker
    elif command -v podman >/dev/null; then
        CONTAINER_ENGINE=podman
    else
        error "Neither docker nor podman found. Use --no-docker to build on host."
        exit 1
    fi
    log "Container engine: ${CONTAINER_ENGINE}"
}

ensure_docker_image() {
    local image_tag="qt-module-builder:${QT_VERSION}"
    if ${CONTAINER_ENGINE} image inspect "${image_tag}" >/dev/null 2>&1; then
        log "Docker image ${image_tag} already exists."
        return 0
    fi
    log "Building Docker image ${image_tag}..."
    if [[ "$DRY_RUN" == true ]]; then
        log "[dry-run] Would build Docker image ${image_tag}"
        return 0
    fi
    ${CONTAINER_ENGINE} build \
        --build-arg "QT_VERSION=${QT_VERSION}" \
        -t "${image_tag}" \
        "${SCRIPT_DIR}/../docker/"
}

build_test_in_docker() {
    local mod_dir="$1"
    local image_tag="qt-module-builder:${QT_VERSION}"

    log "Running build/test in Docker for ${mod_dir}..."
    if [[ "$DRY_RUN" == true ]]; then
        log "[dry-run] Would run: ${CONTAINER_ENGINE} run --rm -v ${mod_dir}:/src:ro ${image_tag}"
        return 0
    fi
    ${CONTAINER_ENGINE} run --rm \
        --user "$(id -u):$(id -g)" \
        -v "${mod_dir}:/src:ro" \
        "${image_tag}"
}

# Phase 1: Build, test, version update for a single module
process_module() {
    local submodule_dir="$1"
    local portage_dir="$2"
    local branch="$3"
    local github_repo="$4"
    local mod_dir="${OVERLAY_DIR}/${submodule_dir}"
    local mod_name
    mod_name="$(basename "$submodule_dir")"

    log "=== Processing ${mod_name} ==="

    if [[ ! -d "${mod_dir}" ]]; then
        error "${mod_dir} does not exist"
        MODULE_STATUS["${mod_name}"]="error: submodule not found"
        return 1
    fi

    cd "${mod_dir}"

    # Step 1: Checkout branch and pull latest
    log "Checking out ${branch} and pulling latest..."
    if [[ "$DRY_RUN" == true ]]; then
        log "[dry-run] Would run: git checkout ${branch} && git pull && git submodule update --init --recursive"
    else
        git checkout "${branch}"
        git pull
        git submodule update --init --recursive
    fi

    # Step 2: Read current version from .cmake.conf
    local current_version
    current_version=$(sed -n 's/^set(QT_REPO_MODULE_VERSION "\(.*\)")/\1/p' .cmake.conf)
    log "Current version: ${current_version}, Target version: ${QT_VERSION}"

    # Step 3: Check if tag already exists
    if git tag -l "v${QT_VERSION}" | grep -q "v${QT_VERSION}"; then
        log "Tag v${QT_VERSION} already exists for ${mod_name}. Skipping."
        MODULE_STATUS["${mod_name}"]="skipped (tag exists)"
        return 0
    fi

    # If version already matches but tag doesn't exist, we still need to build/test/tag
    if [[ "${current_version}" == "${QT_VERSION}" ]]; then
        log "Version already at ${QT_VERSION} but tag missing. Will build, test, and tag."
    fi

    # Step 4: Update .cmake.conf
    if [[ "${current_version}" != "${QT_VERSION}" ]]; then
        log "Updating .cmake.conf to version ${QT_VERSION}..."
        if [[ "$DRY_RUN" == true ]]; then
            log "[dry-run] Would update QT_REPO_MODULE_VERSION to ${QT_VERSION}"
        else
            sed -i "s/^set(QT_REPO_MODULE_VERSION \".*\")/set(QT_REPO_MODULE_VERSION \"${QT_VERSION}\")/" .cmake.conf
        fi
    fi

    # Step 5 & 6: Build and test
    if [[ "$NO_DOCKER" == true ]]; then
        # Host-native build/test
        if [[ "$DRY_RUN" == true ]]; then
            log "[dry-run] Would run: cmake -S . -B build -G Ninja -DQT_BUILD_TESTS=1"
            log "[dry-run] Would run: cmake --build build --parallel"
            log "[dry-run] Would run: QT_QPA_PLATFORM=offscreen ctest --test-dir build --output-on-failure"
        else
            rm -rf build

            log "Configuring ${mod_name}..."
            if ! cmake -S . -B build -G Ninja -DQT_BUILD_TESTS=1; then
                error "CMake configure failed for ${mod_name}"
                git checkout .cmake.conf
                MODULE_STATUS["${mod_name}"]="configure_failed"
                return 1
            fi

            log "Building ${mod_name}..."
            if ! cmake --build build --parallel; then
                error "Build failed for ${mod_name}"
                git checkout .cmake.conf
                rm -rf build
                MODULE_STATUS["${mod_name}"]="build_failed"
                return 1
            fi

            log "Testing ${mod_name}..."
            if ! QT_QPA_PLATFORM=offscreen ctest --test-dir build --output-on-failure; then
                error "Tests failed for ${mod_name}"
                git checkout .cmake.conf
                rm -rf build
                MODULE_STATUS["${mod_name}"]="test_failed"
                return 1
            fi

            rm -rf build
        fi
    else
        # Docker-based build/test
        if ! build_test_in_docker "${mod_dir}"; then
            error "Docker build/test failed for ${mod_name}"
            git checkout .cmake.conf
            MODULE_STATUS["${mod_name}"]="docker_build_test_failed"
            return 1
        fi
    fi

    # Step 8: Update CI yml
    local ci_yml=".github/workflows/ci.yml"
    if [[ -f "${ci_yml}" ]]; then
        log "Updating ${ci_yml}..."
        if [[ "$DRY_RUN" == true ]]; then
            log "[dry-run] Would update qt version matrix in ${ci_yml}"
        else
            sed -i "s/qt: \['[^']*'\]/qt: ['${QT_VERSION}']/" "${ci_yml}"
        fi
    fi

    # Step 9: Commit
    log "Committing changes..."
    if [[ "$DRY_RUN" == true ]]; then
        log "[dry-run] Would commit: Bump version to ${QT_VERSION}"
    else
        git add .cmake.conf
        if [[ -f "${ci_yml}" ]]; then
            git add "${ci_yml}"
        fi
        git commit -m "Bump version to ${QT_VERSION}"
    fi

    # Step 10: Tag
    log "Tagging v${QT_VERSION}..."
    if [[ "$DRY_RUN" == true ]]; then
        log "[dry-run] Would tag: v${QT_VERSION}"
    else
        git tag "v${QT_VERSION}"
    fi

    # Step 11: Push
    if [[ "$NO_PUSH" == true ]]; then
        log "Skipping push (--no-push)"
    elif [[ "$DRY_RUN" == true ]]; then
        log "[dry-run] Would push: origin ${branch} and tag v${QT_VERSION}"
    else
        log "Pushing to origin..."
        git push origin "${branch}"
        git push origin "v${QT_VERSION}"
    fi

    MODULE_STATUS["${mod_name}"]="success"
    log "${mod_name} completed successfully."
    return 0
}

# Phase 2: Update overlay ebuilds and Manifests for a single module
update_overlay() {
    local portage_dir="$1"
    local github_repo="$2"
    local mod_name
    mod_name="$(basename "$portage_dir")"
    local pkg_dir="${OVERLAY_DIR}/${portage_dir}"

    log "=== Updating overlay for ${mod_name} ==="

    # Find the latest existing versioned ebuild to use as template (exclude 9999 live ebuild)
    local latest_ebuild
    latest_ebuild=$(ls "${pkg_dir}"/${mod_name}-[0-9]*.ebuild 2>/dev/null | grep -v '\-9999\.ebuild$' | sort -V | tail -1)
    if [[ -z "${latest_ebuild}" ]]; then
        error "No versioned ebuild found in ${pkg_dir}"
        return 1
    fi

    local new_ebuild="${pkg_dir}/${mod_name}-${QT_VERSION}.ebuild"
    if [[ -f "${new_ebuild}" ]]; then
        log "Ebuild ${mod_name}-${QT_VERSION}.ebuild already exists. Skipping copy."
    elif [[ "$DRY_RUN" == true ]]; then
        log "[dry-run] Would copy $(basename "${latest_ebuild}") -> ${mod_name}-${QT_VERSION}.ebuild"
    else
        log "Creating ${mod_name}-${QT_VERSION}.ebuild from $(basename "${latest_ebuild}")"
        cp "${latest_ebuild}" "${new_ebuild}"
    fi

    # Download tarball and compute checksums
    local tarball_url="https://github.com/signal-slot/${github_repo}/archive/refs/tags/v${QT_VERSION}.tar.gz"
    local tarball_name="${mod_name}-${QT_VERSION}.tar.gz"

    # Check if DIST entry already exists
    if grep -q "^DIST ${tarball_name} " "${pkg_dir}/Manifest" 2>/dev/null; then
        log "DIST entry for ${tarball_name} already exists in Manifest. Skipping."
        return 0
    fi

    local tmp_tarball
    tmp_tarball="$(mktemp)"

    log "Downloading tarball from ${tarball_url}..."
    local download_ok=false
    for attempt in 1 2; do
        if [[ "$DRY_RUN" == true ]]; then
            log "[dry-run] Would download ${tarball_url}"
            download_ok=true
            break
        fi
        if curl -fsSL -o "${tmp_tarball}" "${tarball_url}"; then
            download_ok=true
            break
        fi
        if [[ "${attempt}" -eq 1 ]]; then
            log "Download failed, retrying (GitHub archive generation may need time)..."
            sleep 5
        fi
    done

    if [[ "$download_ok" == false ]]; then
        error "Failed to download tarball for ${mod_name}"
        rm -f "${tmp_tarball}" "${new_ebuild}"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log "[dry-run] Would compute BLAKE2B and SHA512 checksums"
        log "[dry-run] Would add DIST line to ${portage_dir}/Manifest"
        rm -f "${tmp_tarball}"
        return 0
    fi

    local filesize
    filesize=$(stat -c%s "${tmp_tarball}")
    local blake2b
    blake2b=$(b2sum "${tmp_tarball}" | awk '{print $1}')
    local sha512
    sha512=$(sha512sum "${tmp_tarball}" | awk '{print $1}')

    rm -f "${tmp_tarball}"

    local dist_line="DIST ${tarball_name} ${filesize} BLAKE2B ${blake2b} SHA512 ${sha512}"
    log "Adding DIST entry to Manifest"
    echo "${dist_line}" >> "${pkg_dir}/Manifest"

    log "Overlay update for ${mod_name} complete."
    return 0
}

main() {
    parse_args "$@"

    # Detect Qt version if not specified
    if [[ -z "${QT_VERSION}" ]]; then
        QT_VERSION=$(detect_qt_version)
    fi

    log "Target Qt version: ${QT_VERSION}"
    log "Dry run: ${DRY_RUN}"
    log "No push: ${NO_PUSH}"
    log "No overlay: ${NO_OVERLAY}"
    log "No docker: ${NO_DOCKER}"
    echo ""

    # Set up Docker if needed
    if [[ "$NO_DOCKER" == false ]]; then
        detect_container_engine
        ensure_docker_image
    fi

    # Phase 1: Process each module
    local failed=false
    for module_def in "${MODULES[@]}"; do
        IFS=':' read -r submodule_dir portage_dir branch github_repo <<< "${module_def}"
        local mod_name
        mod_name="$(basename "$submodule_dir")"

        if ! should_process_module "${mod_name}"; then
            log "Skipping ${mod_name} (not selected)"
            continue
        fi

        if ! process_module "${submodule_dir}" "${portage_dir}" "${branch}" "${github_repo}"; then
            failed=true
        fi
    done

    echo ""

    # Phase 2: Update overlay ebuilds (only for successful modules)
    if [[ "$NO_OVERLAY" == false ]]; then
        for module_def in "${MODULES[@]}"; do
            IFS=':' read -r submodule_dir portage_dir branch github_repo <<< "${module_def}"
            local mod_name
            mod_name="$(basename "$submodule_dir")"

            if ! should_process_module "${mod_name}"; then
                continue
            fi

            if [[ "${MODULE_STATUS["${mod_name}"]:-}" == "success" ]]; then
                if ! update_overlay "${portage_dir}" "${github_repo}"; then
                    MODULE_STATUS["${mod_name}"]="overlay_failed"
                    failed=true
                fi
            fi
        done

        # Phase 3: Commit overlay changes
        cd "${OVERLAY_DIR}"
        if [[ "$DRY_RUN" == true ]]; then
            log "[dry-run] Would commit overlay changes"
        else
            # Stage any changed overlay files
            local has_changes=false
            for module_def in "${MODULES[@]}"; do
                IFS=':' read -r submodule_dir portage_dir branch github_repo <<< "${module_def}"
                local mod_name
                mod_name="$(basename "$submodule_dir")"
                if [[ "${MODULE_STATUS["${mod_name}"]:-}" == "success" ]]; then
                    git add "${portage_dir}/" "${submodule_dir}"
                    has_changes=true
                fi
            done

            if [[ "$has_changes" == true ]] && ! git diff --cached --quiet; then
                git commit -m "Add Qt module ebuilds for ${QT_VERSION}"
            else
                log "No overlay changes to commit."
            fi
        fi
    fi

    echo ""

    # Phase 4: Result report
    log "=== Results ==="
    printf "%-20s | %s\n" "Module" "Status"
    printf "%-20s-+-%s\n" "--------------------" "--------------------"
    for module_def in "${MODULES[@]}"; do
        IFS=':' read -r submodule_dir portage_dir branch github_repo <<< "${module_def}"
        local mod_name
        mod_name="$(basename "$submodule_dir")"

        if ! should_process_module "${mod_name}"; then
            continue
        fi

        printf "%-20s | %s\n" "${mod_name}" "${MODULE_STATUS["${mod_name}"]:-not processed}"
    done
    echo ""

    if [[ "$failed" == true ]]; then
        error "One or more modules failed."
        exit 1
    fi

    log "All modules completed successfully."
    exit 0
}

main "$@"
