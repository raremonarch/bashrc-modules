#!/usr/bin/env bash
# Version: 0.1.0
# Description: a script for extracting crt and key.pem from pfx file

# Function to extract certificate and private key from a .pfx file using OpenSSL
# Usage: extract_pfx <pfx_file>
# Example: extract_pfx mycert.pfx
extract_pfx() {
    local pfx_file="$1"

    # Check if a file argument was provided
    if [[ -z "$pfx_file" ]]; then
        echo "Usage: extract_pfx <pfx_file>"
        echo "Error: No .pfx file provided"
        return 1
    fi

    # Check if the file exists
    if [[ ! -f "$pfx_file" ]]; then
        echo "Error: File not found: $pfx_file"
        return 1
    fi

    # Check if OpenSSL exists
    if ! command -v openssl &> /dev/null; then
        echo "Error: OpenSSL is not installed or not in PATH"
        return 1
    fi

    # Check OpenSSL version
    local openssl_version
    openssl_version=$(openssl version | awk '{print $2}')
    local required_version="3.2.4"

    # Helper function to compare version numbers (using sort -V)
    version_greater_equal() {
        [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]]
    }

    if ! version_greater_equal "$openssl_version" "$required_version"; then
        echo "Error: OpenSSL version $openssl_version is less than required version $required_version"
        echo "Please upgrade OpenSSL to version $required_version or higher"
        return 1
    fi

    echo "OpenSSL version $openssl_version detected (required: $required_version)"

    # Extract the basename without extension
    local basename
    basename=$(basename "${pfx_file}" .pfx)

    echo "Extracting CRT from PFX..."
    openssl pkcs12 -in "${pfx_file}" -legacy -clcerts -nokeys -out "${basename}.crt"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to extract certificate"
        return 1
    fi

    echo "Extracting private KEY from PFX..."
    openssl pkcs12 -in "${pfx_file}" -legacy -nocerts -out "${basename}.key.pem" -nodes
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to extract private key"
        return 1
    fi

    # Get the full path to the output files
    local cert_file key_file
    cert_file=$(readlink -f "${basename}.crt" 2>/dev/null || realpath "${basename}.crt" 2>/dev/null || echo "${basename}.crt")
    key_file=$(readlink -f "${basename}.key.pem" 2>/dev/null || realpath "${basename}.key.pem" 2>/dev/null || echo "${basename}.key.pem")

    # Echo the output paths
    echo ""
    echo "Extraction complete. Files created:"
    echo "Certificate: $cert_file"
    echo "Private key: $key_file"
}
