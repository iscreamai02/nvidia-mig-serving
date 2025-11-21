#!/bin/bash

# H100 MIG Setup Script - Split 2x H100 80GB into 40GB partitions
# Based on NVIDIA MIG User Guide for Hopper architecture

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

# Check for H100 GPUs
log_info "Checking for H100 GPUs..."
gpu_count=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | grep -c "H100" || true)

if [[ $gpu_count -ne 2 ]]; then
    log_error "Expected 2 H100 GPUs, found $gpu_count"
    exit 1
fi

log_info "Found 2 H100 GPUs"

# Display current GPU status
log_info "Current GPU status:"
nvidia-smi --query-gpu=index,name,memory.total,mig.mode.current --format=csv

# Function to enable MIG mode on a GPU
enable_mig_mode() {
    local gpu_id=$1
    log_info "Enabling MIG mode on GPU $gpu_id..."

    # Check current MIG mode
    current_mode=$(nvidia-smi -i $gpu_id --query-gpu=mig.mode.current --format=csv,noheader,nounits)

    if [[ "$current_mode" == "Enabled" ]]; then
        log_info "MIG mode already enabled on GPU $gpu_id"
        return 0
    fi

    # Enable MIG mode
    nvidia-smi -i $gpu_id -mig 1

    # For Hopper GPUs, no reset is required, but let's verify the mode change
    sleep 2
    new_mode=$(nvidia-smi -i $gpu_id --query-gpu=mig.mode.current --format=csv,noheader,nounits)

    if [[ "$new_mode" == "Enabled" ]]; then
        log_info "MIG mode successfully enabled on GPU $gpu_id"
    else
        log_error "Failed to enable MIG mode on GPU $gpu_id"
        return 1
    fi
}

# Function to create 40GB MIG instances
create_mig_instances() {
    local gpu_id=$1
    log_info "Creating MIG instances on GPU $gpu_id..."

    # List available profiles
    log_info "Available MIG profiles for GPU $gpu_id:"
    nvidia-smi mig -i $gpu_id -lgip

    # For H100 80GB, we want to create 2x 40GB instances
    # Profile ID 9 is typically "MIG 3g.40gb" which gives ~40GB memory
    log_info "Creating 2x 40GB MIG instances on GPU $gpu_id..."

    # Create two 3g.40gb instances with compute instances
    nvidia-smi mig -i $gpu_id -cgi 9,9 -C

    if [[ $? -eq 0 ]]; then
        log_info "Successfully created MIG instances on GPU $gpu_id"
    else
        log_error "Failed to create MIG instances on GPU $gpu_id"
        return 1
    fi
}

# Function to verify MIG configuration
verify_mig_config() {
    local gpu_id=$1
    log_info "Verifying MIG configuration for GPU $gpu_id..."

    # List GPU instances
    nvidia-smi mig -i $gpu_id -lgi

    # Show MIG devices
    nvidia-smi -i $gpu_id
}

# Function to destroy all MIG instances
destroy_mig_instances() {
    local gpu_id=$1
    log_info "Destroying all MIG instances on GPU $gpu_id..."

    # Destroy all compute instances and GPU instances
    nvidia-smi mig -i $gpu_id -dci
    nvidia-smi mig -i $gpu_id -dgi

    if [[ $? -eq 0 ]]; then
        log_info "Successfully destroyed MIG instances on GPU $gpu_id"
    else
        log_warn "Failed to destroy MIG instances on GPU $gpu_id (may not exist)"
    fi
}

# Function to disable MIG mode on a GPU
disable_mig_mode() {
    local gpu_id=$1
    log_info "Disabling MIG mode on GPU $gpu_id..."

    # Check current MIG mode
    current_mode=$(nvidia-smi -i $gpu_id --query-gpu=mig.mode.current --format=csv,noheader,nounits)

    if [[ "$current_mode" == "Disabled" ]]; then
        log_info "MIG mode already disabled on GPU $gpu_id"
        return 0
    fi

    # First destroy all MIG instances
    destroy_mig_instances $gpu_id

    # Disable MIG mode
    nvidia-smi -i $gpu_id -mig 0

    # Verify the mode change
    sleep 2
    new_mode=$(nvidia-smi -i $gpu_id --query-gpu=mig.mode.current --format=csv,noheader,nounits)

    if [[ "$new_mode" == "Disabled" ]]; then
        log_info "MIG mode successfully disabled on GPU $gpu_id"
    else
        log_error "Failed to disable MIG mode on GPU $gpu_id"
        return 1
    fi
}

# Main execution for enabling MIG
enable_mig() {
    log_info "Starting H100 MIG setup..."

    # Enable MIG mode on both GPUs
    for gpu_id in 0 1; do
        enable_mig_mode $gpu_id
    done

    log_info "Waiting for MIG mode to stabilize..."
    sleep 3

    # Create MIG instances on both GPUs
    for gpu_id in 0 1; do
        create_mig_instances $gpu_id
    done

    log_info "MIG setup complete! Final configuration:"

    # Show final status
    nvidia-smi

    log_info "MIG device UUIDs:"
    nvidia-smi -L

    # Save MIG UUIDs to file for easy reference
    nvidia-smi -L | grep "MIG" > /tmp/mig_devices.txt
    log_info "MIG device UUIDs saved to /tmp/mig_devices.txt"

    log_info "Setup completed successfully!"
    log_info "You now have 4 MIG devices total (2x 40GB per GPU)"
    log_info "Use CUDA_VISIBLE_DEVICES=<MIG-UUID> to target specific MIG devices"
}

# Main execution for disabling MIG
disable_mig() {
    log_info "Starting H100 MIG teardown..."

    # Disable MIG mode on both GPUs
    for gpu_id in 0 1; do
        disable_mig_mode $gpu_id
    done

    log_info "MIG teardown complete! Final configuration:"

    # Show final status
    nvidia-smi

    log_info "Teardown completed successfully!"
    log_info "GPUs are now in regular (non-MIG) mode"
}

# Usage information
usage() {
    echo "Usage: $0 {enable|disable}"
    echo ""
    echo "  enable  - Enable MIG mode and create 2x 40GB instances per GPU"
    echo "  disable - Disable MIG mode and return to regular GPU mode"
    exit 1
}

# Cleanup function for script interruption
cleanup() {
    log_warn "Script interrupted. MIG configuration may be incomplete."
    exit 1
}

trap cleanup SIGINT SIGTERM

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    usage
fi

case "$1" in
    enable)
        enable_mig
        ;;
    disable)
        disable_mig
        ;;
    *)
        usage
        ;;
esac

log_info "Script execution finished."

