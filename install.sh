#!/bin/sh
# Forgejo iOS Installer Lifecycle Manager
# Production-quality installer supporting install, update, verify, diagnostics, repair, uninstall
# Compatible with: curl -fsSL https://raw.githubusercontent.com/<repo>/ios/install.sh | sudo sh

set -eu

# Configuration
FORGEJO_BASE_DIR="${FORGEJO_BASE_DIR:-/var/lib/forgejo-ios}"
FORGEJO_BIN_DIR="${FORGEJO_BASE_DIR}/bin"
FORGEJO_DATA_DIR="${FORGEJO_BASE_DIR}/data"
FORGEJO_REPO_DIR="${FORGEJO_BASE_DIR}/repositories"
FORGEJO_LOG_DIR="${FORGEJO_BASE_DIR}/logs"
FORGEJO_BACKUP_DIR="${FORGEJO_BASE_DIR}/backup"
FORGEJO_CUSTOM_DIR="${FORGEJO_BASE_DIR}/custom"
FORGEJO_STATE_FILE="${FORGEJO_BASE_DIR}/install-state"
FORGEJO_BINARY="${FORGEJO_BIN_DIR}/forgejo"

# Release repository
FORGEJO_REPO="forgejo/forgejo"
FORGEJO_RELEASES_API="https://api.github.com/repos/${FORGEJO_REPO}/releases"

# Temporary directory for staging
TEMP_DIR=""

# Color output
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_NC='\033[0m'

# Utility functions
info() {
    printf "${COLOR_BLUE}[INFO]${COLOR_NC} %s\n" "$1"
}

success() {
    printf "${COLOR_GREEN}[✓]${COLOR_NC} %s\n" "$1"
}

warn() {
    printf "${COLOR_YELLOW}[WARN]${COLOR_NC} %s\n" "$1"
}

error() {
    printf "${COLOR_RED}[ERROR]${COLOR_NC} %s\n" "$1"
}

cleanup() {
    if [ -n "${TEMP_DIR}" ] && [ -d "${TEMP_DIR}" ]; then
        rm -rf "${TEMP_DIR}"
    fi
}

trap cleanup EXIT INT TERM

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."

    # Check if running as root
    if [ "$(id -u)" != "0" ]; then
        error "This script must be run as root"
        exit 1
    fi

    # Check architecture
    ARCH=$(uname -m)
    case "${ARCH}" in
        arm64|aarch64)
            info "Architecture: ARM64 (iOS)"
            ;;
        armv7l|armv7)
            info "Architecture: ARMv7 (iOS 32-bit)"
            ;;
        *)
            error "Unsupported architecture: ${ARCH}"
            exit 1
            ;;
    esac

    # Check required tools
    for cmd in curl sha256sum tar gzip; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            error "Required tool not found: ${cmd}"
            exit 1
        fi
    done

    # Check if ldid is available (for binary signing on iOS)
    if ! command -v ldid >/dev/null 2>&1; then
        warn "ldid not found - binary signing may not work on jailbroken device"
    fi

    success "Prerequisites check passed"
}

# Load state file
load_state() {
    if [ -f "${FORGEJO_STATE_FILE}" ]; then
        # Source state file in a subshell to avoid polluting environment
        (
            . "${FORGEJO_STATE_FILE}"
            echo "VERSION=${VERSION}"
            echo "RELEASE=${RELEASE}"
            echo "INSTALL_TIME=${INSTALL_TIME}"
            echo "BINARY_SHA256=${BINARY_SHA256}"
        ) | while IFS='=' read -r key value; do
            eval "${key}='${value}'"
        done
    fi
}

# Save state file
save_state() {
    local version=$1
    local release=$2
    local sha256=$3

    mkdir -p "$(dirname "${FORGEJO_STATE_FILE}")"
    cat > "${FORGEJO_STATE_FILE}" << EOF
VERSION=${version}
RELEASE=${release}
INSTALL_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BINARY_SHA256=${sha256}
EOF
    chmod 600 "${FORGEJO_STATE_FILE}"
}

# Detect latest release
get_latest_release() {
    info "Fetching latest Forgejo release..."

    local response
    response=$(curl -fsSL "${FORGEJO_RELEASES_API}/latest" 2>/dev/null || echo "")

    if [ -z "${response}" ]; then
        error "Failed to fetch releases from GitHub API"
        return 1
    fi

    # Extract version and download URL for current architecture
    local version
    version=$(echo "${response}" | grep -o '"tag_name": "[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "${version}" ]; then
        error "Could not determine latest version"
        return 1
    fi

    echo "${version}"
}

# Download release artifact
download_release() {
    local version=$1
    local arch=$2

    info "Downloading Forgejo ${version} for ${arch}..."

    local base_url="https://github.com/${FORGEJO_REPO}/releases/download/${version}"
    local binary_name="forgejo-${version}-linux-${arch}"
    local checksum_file="SHA256SUMS"

    # Create temp directory
    TEMP_DIR=$(mktemp -d)
    cd "${TEMP_DIR}"

    # Download checksum file
    if ! curl -fsSL -o "${checksum_file}" "${base_url}/${checksum_file}"; then
        error "Failed to download SHA256SUMS"
        return 1
    fi

    # Download binary
    if ! curl -fsSL -o "${binary_name}" "${base_url}/${binary_name}"; then
        error "Failed to download Forgejo binary"
        return 1
    fi

    # Verify checksum
    if ! sha256sum -c "${checksum_file}" 2>/dev/null | grep -q "${binary_name}"; then
        error "Checksum verification failed"
        return 1
    fi

    success "Download and checksum verification passed"
    echo "${TEMP_DIR}/${binary_name}"
}

# Preserve existing data
preserve_data() {
    info "Preserving existing data..."

    mkdir -p "${FORGEJO_BACKUP_DIR}"

    # Backup current binary if it exists
    if [ -f "${FORGEJO_BINARY}" ]; then
        cp -p "${FORGEJO_BINARY}" "${FORGEJO_BACKUP_DIR}/forgejo-$(date +%s).bak"
        success "Backed up current binary"
    fi

    # Create directories if they don't exist
    mkdir -p "${FORGEJO_DATA_DIR}"
    mkdir -p "${FORGEJO_REPO_DIR}"
    mkdir -p "${FORGEJO_CUSTOM_DIR}/conf"
    mkdir -p "${FORGEJO_LOG_DIR}"
}

# Install Forgejo
install_forgejo() {
    info "Installing Forgejo..."

    check_prerequisites

    local version
    version=$(get_latest_release) || return 1

    local arch
    case "$(uname -m)" in
        arm64|aarch64)
            arch="arm64"
            ;;
        armv7l|armv7)
            arch="armv7"
            ;;
    esac

    local binary_path
    binary_path=$(download_release "${version}" "${arch}") || return 1

    preserve_data

    # Create bin directory
    mkdir -p "${FORGEJO_BIN_DIR}"

    # Atomic move
    mv "${binary_path}" "${FORGEJO_BINARY}"
    chmod 755 "${FORGEJO_BINARY}"

    # Get binary SHA256
    local binary_sha256
    binary_sha256=$(sha256sum "${FORGEJO_BINARY}" | cut -d' ' -f1)

    # Save state
    save_state "${version}" "$(date -u +%s)" "${binary_sha256}"

    success "Forgejo ${version} installed successfully"
    echo ""
    echo "Installation directory: ${FORGEJO_BASE_DIR}"
    echo "Binary location: ${FORGEJO_BINARY}"
}

# Update Forgejo
update_forgejo() {
    info "Checking for Forgejo updates..."

    check_prerequisites

    if [ ! -f "${FORGEJO_BINARY}" ]; then
        error "Forgejo not installed. Please run install first."
        return 1
    fi

    local current_version
    current_version=$("${FORGEJO_BINARY}" --version 2>/dev/null | head -1 | cut -d' ' -f3) || ""

    local latest_version
    latest_version=$(get_latest_release) || return 1

    if [ "${current_version}" = "${latest_version}" ]; then
        success "Already running the latest version: ${latest_version}"
        return 0
    fi

    info "Updating from ${current_version} to ${latest_version}..."

    local arch
    case "$(uname -m)" in
        arm64|aarch64)
            arch="arm64"
            ;;
        armv7l|armv7)
            arch="armv7"
            ;;
    esac

    local new_binary
    new_binary=$(download_release "${latest_version}" "${arch}") || return 1

    # Backup current binary
    local backup_path="${FORGEJO_BACKUP_DIR}/forgejo-${current_version}.bak"
    cp -p "${FORGEJO_BINARY}" "${backup_path}"

    # Atomic replace
    mv "${new_binary}" "${FORGEJO_BINARY}"
    chmod 755 "${FORGEJO_BINARY}"

    # Get new binary SHA256
    local binary_sha256
    binary_sha256=$(sha256sum "${FORGEJO_BINARY}" | cut -d' ' -f1)

    # Update state
    save_state "${latest_version}" "$(date -u +%s)" "${binary_sha256}"

    success "Forgejo updated to ${latest_version}"
}

# Verify installation
verify_installation() {
    info "Verifying Forgejo installation..."

    local status=0

    # Check binary
    if [ ! -f "${FORGEJO_BINARY}" ]; then
        error "Forgejo binary not found at ${FORGEJO_BINARY}"
        status=1
    else
        success "Forgejo binary found"
    fi

    # Check binary is executable
    if [ ! -x "${FORGEJO_BINARY}" ]; then
        error "Forgejo binary is not executable"
        status=1
    else
        success "Forgejo binary is executable"
    fi

    # Check state file
    if [ ! -f "${FORGEJO_STATE_FILE}" ]; then
        warn "Install state file not found"
    else
        success "Install state file found"
    fi

    # Check directories
    for dir in "${FORGEJO_DATA_DIR}" "${FORGEJO_REPO_DIR}" "${FORGEJO_CUSTOM_DIR}" "${FORGEJO_LOG_DIR}"; do
        if [ ! -d "${dir}" ]; then
            error "Required directory missing: ${dir}"
            status=1
        else
            success "Directory OK: ${dir}"
        fi
    done

    return ${status}
}

# Diagnostics
show_diagnostics() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           Forgejo iOS Diagnostics Report                   ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Device information
    echo "Device:"
    echo "  Architecture:    $(uname -m)"
    echo "  OS:              $(uname -s)"
    echo "  Kernel:          $(uname -r)"
    echo ""

    # Binary information
    if [ -f "${FORGEJO_BINARY}" ]; then
        echo "Binary:"
        echo "  Path:            ${FORGEJO_BINARY}"
        echo "  Size:            $(du -h "${FORGEJO_BINARY}" | cut -f1)"
        echo "  Executable:      $([ -x "${FORGEJO_BINARY}" ] && echo 'Yes' || echo 'No')"
        echo "  SHA256:          $(sha256sum "${FORGEJO_BINARY}" | cut -d' ' -f1)"

        if "${FORGEJO_BINARY}" --version >/dev/null 2>&1; then
            echo "  Version:         $("${FORGEJO_BINARY}" --version 2>/dev/null | head -1 | cut -d' ' -f3)"
        fi
    else
        echo "Binary:           NOT INSTALLED"
    fi
    echo ""

    # State file
    if [ -f "${FORGEJO_STATE_FILE}" ]; then
        echo "Installation State:"
        sed 's/^/  /' "${FORGEJO_STATE_FILE}"
    fi
    echo ""

    # Storage information
    echo "Storage:"
    if [ -d "${FORGEJO_DATA_DIR}" ]; then
        echo "  Data:            $(du -sh "${FORGEJO_DATA_DIR}" 2>/dev/null | cut -f1)"
    fi
    if [ -d "${FORGEJO_REPO_DIR}" ]; then
        echo "  Repositories:    $(du -sh "${FORGEJO_REPO_DIR}" 2>/dev/null | cut -f1)"
    fi
    if [ -d "${FORGEJO_BACKUP_DIR}" ]; then
        echo "  Backups:         $(du -sh "${FORGEJO_BACKUP_DIR}" 2>/dev/null | cut -f1)"
    fi

    local available_space
    available_space=$(df "${FORGEJO_BASE_DIR}" 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -n "${available_space}" ]; then
        echo "  Free space:      $(numfmt --to=iec "${available_space}" 2>/dev/null || echo "${available_space} KB")"
    fi
    echo ""
}

# Repair installation
repair_installation() {
    info "Repairing Forgejo installation..."

    local repaired=0

    # Recreate missing directories
    for dir in "${FORGEJO_DATA_DIR}" "${FORGEJO_REPO_DIR}" "${FORGEJO_CUSTOM_DIR}/conf" "${FORGEJO_LOG_DIR}"; do
        if [ ! -d "${dir}" ]; then
            mkdir -p "${dir}"
            success "Recreated directory: ${dir}"
            repaired=$((repaired + 1))
        fi
    done

    # Fix permissions
    if [ -f "${FORGEJO_BINARY}" ]; then
        if [ ! -x "${FORGEJO_BINARY}" ]; then
            chmod 755 "${FORGEJO_BINARY}"
            success "Fixed permissions on Forgejo binary"
            repaired=$((repaired + 1))
        fi
    fi

    # Fix directory permissions
    chmod 755 "${FORGEJO_BASE_DIR}"
    chmod 755 "${FORGEJO_BIN_DIR}"
    chmod 750 "${FORGEJO_DATA_DIR}"
    chmod 750 "${FORGEJO_REPO_DIR}"

    if [ ${repaired} -eq 0 ]; then
        success "Installation appears healthy"
    else
        success "Repaired ${repaired} issues"
    fi
}

# Uninstall Forgejo
uninstall_forgejo() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║              Forgejo iOS Uninstall                         ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "This will remove:"
    echo "  • Forgejo binary"
    echo "  • Launcher and service files"
    echo "  • Installation state"
    echo "  • Log files"
    echo ""
    echo "This will PRESERVE:"
    echo "  • Your data and repositories"
    echo "  • Configuration files"
    echo ""

    # Interactive confirmation
    printf "Type 'DELETE FORGEJO DATA' to remove everything including data: "
    read -r confirmation < /dev/tty

    if [ "${confirmation}" = "DELETE FORGEJO DATA" ]; then
        info "Removing all Forgejo data..."
        rm -rf "${FORGEJO_BASE_DIR}"
        success "Forgejo iOS completely removed"
    else
        info "Keeping data directories (${FORGEJO_DATA_DIR}, ${FORGEJO_REPO_DIR})"

        # Remove only binary, state, logs
        rm -f "${FORGEJO_BINARY}"
        rm -f "${FORGEJO_STATE_FILE}"
        rm -rf "${FORGEJO_LOG_DIR}"

        success "Forgejo iOS uninstalled (data preserved)"
    fi
}

# Main menu
show_menu() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║        Forgejo iOS Installer Lifecycle Manager             ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "1. Install Forgejo"
    echo "2. Update Forgejo"
    echo "3. Verify installation"
    echo "4. Show diagnostics"
    echo "5. Repair installation"
    echo "6. Uninstall Forgejo"
    echo "7. Exit"
    echo ""
}

# Main entry point
main() {
    # If stdin is not a terminal and no arguments, we're being piped
    if [ ! -t 0 ] && [ $# -eq 0 ]; then
        # Default to install when piped
        install_forgejo
        exit $?
    fi

    # Interactive menu
    while true; do
        show_menu
        printf "Select an option (1-7): "
        read -r choice < /dev/tty

        case "${choice}" in
            1)
                install_forgejo
                ;;
            2)
                update_forgejo
                ;;
            3)
                verify_installation
                ;;
            4)
                show_diagnostics
                ;;
            5)
                repair_installation
                ;;
            6)
                uninstall_forgejo
                ;;
            7)
                echo "Exiting..."
                exit 0
                ;;
            *)
                error "Invalid option. Please select 1-7."
                ;;
        esac

        printf "\nPress Enter to continue..."
        read -r _ < /dev/tty
    done
}

main "$@"
