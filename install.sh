#!/bin/bash
#=============================================================================
# MPID OpenMM Plugin Installation Script
# This script builds and installs the MPID OpenMM plugin with CUDA support
#=============================================================================

set -e  # Exit on error

# Configuration
CONDA_PREFIX=${CONDA_PREFIX:-$HOME/miniconda3}
ENV_NAME=${ENV_NAME:-mpid-env}
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_TYPE=${BUILD_TYPE:-Release}
OPENMM_VERSION=${OPENMM_VERSION:-8.4}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running in a conda environment
check_conda() {
    if ! command -v conda &> /dev/null; then
        log_error "Conda not found. Please install Miniconda first."
        exit 1
    fi
    log_info "Conda found: $(which conda)"
}

# Check CUDA version
check_cuda() {
    if command -v nvidia-smi &> /dev/null; then
        local cuda_driver_version=$(nvidia-smi --query-gpu=driver_version --id=0 2>/dev/null | head -1)
        log_info "NVIDIA driver version: $cuda_driver_version"
    fi

    if command -v nvcc &> /dev/null; then
        local cuda_version=$(nvcc --version 2>/dev/null | grep "release" | sed -n 's/.*release \([0-9.]*\).*/\1/p')
        log_info "CUDA toolkit version: $cuda_version"
    else
        log_warn "nvcc not found in PATH"
    fi
}

# Check CMake version
check_cmake() {
    if ! command -v cmake &> /dev/null; then
        log_error "CMake not found. Installing via conda..."
        conda install -y cmake
    fi
    local cmake_version=$(cmake --version 2>/dev/null | head -1)
    log_info "CMake version: $cmake_version"
}

# Check SWIG
check_swig() {
    if ! command -v swig &> /dev/null; then
        log_warn "SWIG not found. Will try to install."
        conda install -y swig || pip install swig
    fi
    log_info "SWIG version: $(swig -version 2>/dev/null | head -1 || echo 'not found')"
}

# Create conda environment
create_environment() {
    log_info "Creating conda environment: $ENV_NAME"

    if ! conda info --envs | grep -q "^$ENV_NAME "; then
        log_info "Creating new environment: $ENV_NAME"
        conda create -n "$ENV_NAME" python=3.12 -y
    else
        log_info "Environment $ENV_NAME already exists, updating..."
        conda install -n "$ENV_NAME" -y python=3.12
    fi

    # Activate environment
    eval "$(conda shell.bash hook)"
    conda activate "$ENV_NAME"

    # Install build tools and OpenMM
    log_info "Installing build tools and OpenMM $OPENMM_VERSION..."
    conda install -y cmake ninja swig gcc_linux-64 gxx_linux-64 libcufft-dev
    conda install -y -c conda-forge openmm=$OPENMM_VERSION "cuda-nvcc=12.6" "cuda-cudart-dev=12.6"

    check_cuda

    log_info "Environment ready: $ENV_NAME"
}

# Build the plugin
build_plugin() {
    log_info "Building MPID plugin..."

    eval "$(conda shell.bash hook)"
    conda activate "$ENV_NAME"

    cd "$PLUGIN_DIR"

    # Create build directory
    mkdir -p build
    cd build

    # Configure with CMake
    log_info "Configuring CMake..."
    cmake \
        -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
        -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" \
        -DOPENMM_DIR="$CONDA_PREFIX" \
        -DMPID_BUILD_CUDA_LIB=ON \
        -DMPID_BUILD_PYTHON_WRAPPERS=ON \
        ..

    # Build
    log_info "Building..."
    make -j$(nproc)

    # Build Python wrappers
    log_info "Building Python wrappers..."
    cd python
    swig -python -c++ -o MPIDPluginWrapper.cpp -I"$CONDA_PREFIX/include" "${PLUGIN_DIR}/python/mpidplugin.i"
    python setup.py build_ext --inplace

    # Go back to build directory
    cd "$PLUGIN_DIR/build"

    # Install Python module directly to site-packages
    log_info "Installing Python module..."
    cp python/_mpidplugin*.so python/mpidplugin.py "$CONDA_PREFIX/lib/python3.12/site-packages/"

    # Install libraries
    log_info "Installing libraries..."
    mkdir -p "$CONDA_PREFIX/lib/plugins"
    cp libMPIDPlugin.so "$CONDA_PREFIX/lib/"
    [ -f platforms/cuda/libMPIDPluginCUDA.so ] && cp platforms/cuda/libMPIDPluginCUDA.so "$CONDA_PREFIX/lib/plugins/"
    [ -f platforms/reference/libOpenMMMPIDReference.so ] && cp platforms/reference/libOpenMMMPIDReference.so "$CONDA_PREFIX/lib/plugins/"

    log_info "Build and installation complete!"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."

    eval "$(conda shell.bash hook)"
    conda activate "$ENV_NAME"

    # Check libraries
    local lib_files=(
        "$CONDA_PREFIX/lib/libMPIDPlugin.so"
        "$CONDA_PREFIX/lib/plugins/libMPIDPluginCUDA.so"
        "$CONDA_PREFIX/lib/plugins/libOpenMMMPIDReference.so"
    )

    for lib in "${lib_files[@]}"; do
        if [ -f "$lib" ]; then
            log_info "Found: $lib"
        else
            log_warn "Missing: $lib"
        fi
    done

    # Check Python module
    if python -c "import mpidplugin; print('mpidplugin imported successfully')" 2>/dev/null; then
        log_info "Python module import: OK"
    else
        log_error "Python module import failed"
        return 1
    fi

    log_info "Installation verified successfully!"
    return 0
}

# Print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --env-name NAME       Conda environment name (default: mpid-env)"
    echo "  --openmm-version VER  OpenMM version to install (default: 8.4)"
    echo "  --build-type TYPE     CMake build type: Release or Debug (default: Release)"
    echo "  --skip-create         Skip environment creation"
    echo "  --skip-cuda-check     Skip CUDA checks"
    echo "  --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Default installation"
    echo "  $0 --env-name myenv --openmm-version 8.4"
    echo "  $0 --skip-create                      # Use existing environment"
}

# Parse arguments
SKIP_CREATE=false
SKIP_CUDA_CHECK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --env-name)
            ENV_NAME="$2"
            shift 2
            ;;
        --openmm-version)
            OPENMM_VERSION="$2"
            shift 2
            ;;
        --build-type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        --skip-create)
            SKIP_CREATE=true
            shift
            ;;
        --skip-cuda-check)
            SKIP_CUDA_CHECK=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main
main() {
    log_info "============================================"
    log_info "MPID OpenMM Plugin Installation"
    log_info "============================================"
    log_info "Plugin directory: $PLUGIN_DIR"
    log_info "Conda prefix: $CONDA_PREFIX"
    log_info "Environment name: $ENV_NAME"
    log_info "OpenMM version: $OPENMM_VERSION"
    log_info "============================================"

    check_conda

    if [ "$SKIP_CUDA_CHECK" = false ]; then
        check_cuda
    fi

    check_cmake
    check_swig

    if [ "$SKIP_CREATE" = false ]; then
        create_environment
    fi

    build_plugin
    verify_installation

    log_info "============================================"
    log_info "Installation complete!"
    log_info "============================================"
    log_info "To use the plugin:"
    log_info "  conda activate $ENV_NAME"
    log_info "  cd $PLUGIN_DIR/examples/waterbox"
    log_info "  python run.py"
}

main "$@"
