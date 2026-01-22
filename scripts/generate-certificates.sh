#!/bin/bash

################################################################################
# TIBCO Platform - SSL Certificate Generation Script
# 
# This script generates self-signed SSL certificates for TIBCO Platform
# Control Plane domains (MY and TUNNEL)
#
# ⚠️  WARNING: Self-signed certificates are for DEVELOPMENT/TESTING ONLY!
# For production, use certificates from a trusted Certificate Authority.
#
# Usage:
#   ./generate-certificates.sh
#
# Prerequisites:
#   - openssl installed
#   - Environment variables set (source aks-env-variables.sh first)
#
# Last Updated: January 22, 2026
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

################################################################################
# Functions
################################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if openssl is installed
    if ! command -v openssl &> /dev/null; then
        log_error "openssl is not installed. Please install openssl first."
        exit 1
    fi
    
    # Check if required environment variables are set
    if [ -z "$CP_MY_DNS_DOMAIN" ] || [ -z "$CP_TUNNEL_DNS_DOMAIN" ]; then
        log_error "Required environment variables not set."
        log_error "Please source aks-env-variables.sh first: source scripts/aks-env-variables.sh"
        exit 1
    fi
    
    log_info "Prerequisites check passed!"
}

create_cert_directory() {
    CERT_DIR="$(pwd)/certs"
    
    if [ -d "$CERT_DIR" ]; then
        log_warn "Certificate directory already exists: $CERT_DIR"
        read -p "Do you want to overwrite existing certificates? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Certificate generation cancelled."
            exit 0
        fi
    fi
    
    mkdir -p "$CERT_DIR"
    log_info "Certificate directory created: $CERT_DIR"
}

generate_certificate() {
    local domain=$1
    local cert_name=$2
    local output_dir=$3
    
    log_info "Generating certificate for: $domain"
    
    # Certificate file paths
    local key_file="${output_dir}/${cert_name}-key.pem"
    local cert_file="${output_dir}/${cert_name}-cert.pem"
    local csr_file="${output_dir}/${cert_name}-csr.pem"
    
    # Generate private key
    openssl genrsa -out "$key_file" 2048 2>/dev/null
    log_info "  ✓ Private key generated: $key_file"
    
    # Create OpenSSL config for SAN
    cat > "${output_dir}/${cert_name}-openssl.cnf" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=US
ST=California
L=San Francisco
O=TIBCO Platform
OU=IT Department
CN=*.${domain}

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.${domain}
DNS.2 = ${domain}
EOF

    # Generate CSR
    openssl req -new -key "$key_file" -out "$csr_file" \
        -config "${output_dir}/${cert_name}-openssl.cnf" 2>/dev/null
    log_info "  ✓ Certificate Signing Request generated: $csr_file"
    
    # Generate self-signed certificate (valid for 365 days)
    openssl x509 -req -days 365 -in "$csr_file" -signkey "$key_file" \
        -out "$cert_file" -extensions v3_req \
        -extfile "${output_dir}/${cert_name}-openssl.cnf" 2>/dev/null
    log_info "  ✓ Certificate generated: $cert_file"
    
    # Verify certificate
    log_info "  ✓ Certificate details:"
    openssl x509 -in "$cert_file" -noout -subject -dates -ext subjectAltName 2>/dev/null | sed 's/^/    /'
    
    # Clean up temporary files
    rm -f "$csr_file" "${output_dir}/${cert_name}-openssl.cnf"
}

create_kubernetes_secrets() {
    local cert_dir=$1
    
    log_info ""
    log_info "════════════════════════════════════════════════════════════════"
    log_info "Kubernetes Secret Creation Commands"
    log_info "════════════════════════════════════════════════════════════════"
    log_info ""
    log_info "After creating the ${CP_NAMESPACE} namespace, run these commands to create TLS secrets:"
    log_info ""
    
    echo -e "${GREEN}# Create namespace (if not exists)${NC}"
    echo "kubectl create namespace ${CP_NAMESPACE}"
    echo ""
    
    echo -e "${GREEN}# Create TLS secret for MY domain${NC}"
    echo "kubectl create secret tls tp-certificate-my \\"
    echo "  --cert=${cert_dir}/cp-my-cert.pem \\"
    echo "  --key=${cert_dir}/cp-my-key.pem \\"
    echo "  -n ${CP_NAMESPACE}"
    echo ""
    
    echo -e "${GREEN}# Create TLS secret for TUNNEL domain${NC}"
    echo "kubectl create secret tls tp-certificate-tunnel \\"
    echo "  --cert=${cert_dir}/cp-tunnel-cert.pem \\"
    echo "  --key=${cert_dir}/cp-tunnel-key.pem \\"
    echo "  -n ${CP_NAMESPACE}"
    echo ""
    
    log_info "════════════════════════════════════════════════════════════════"
}

display_summary() {
    local cert_dir=$1
    
    log_info ""
    log_info "════════════════════════════════════════════════════════════════"
    log_info "Certificate Generation Complete!"
    log_info "════════════════════════════════════════════════════════════════"
    log_info ""
    log_info "Generated Certificates:"
    log_info "  MY Domain (${CP_MY_DNS_DOMAIN}):"
    log_info "    Certificate: ${cert_dir}/cp-my-cert.pem"
    log_info "    Private Key: ${cert_dir}/cp-my-key.pem"
    log_info ""
    log_info "  TUNNEL Domain (${CP_TUNNEL_DNS_DOMAIN}):"
    log_info "    Certificate: ${cert_dir}/cp-tunnel-cert.pem"
    log_info "    Private Key: ${cert_dir}/cp-tunnel-key.pem"
    log_info ""
    log_warn "⚠️  IMPORTANT SECURITY NOTICE:"
    log_warn "  These are SELF-SIGNED certificates for DEVELOPMENT/TESTING only!"
    log_warn "  For PRODUCTION deployments:"
    log_warn "    1. Obtain certificates from a trusted Certificate Authority (CA)"
    log_warn "    2. Or use Azure Key Vault with managed certificates"
    log_warn "    3. Or use cert-manager with Let's Encrypt"
    log_info ""
    log_info "Next Steps:"
    log_info "  1. Create Kubernetes namespace: kubectl create namespace ${CP_NAMESPACE}"
    log_info "  2. Create TLS secrets using the commands shown above"
    log_info "  3. Update DNS records to point to your AKS Load Balancer IP"
    log_info "  4. Deploy TIBCO Control Plane"
    log_info ""
    log_info "════════════════════════════════════════════════════════════════"
}

################################################################################
# Main Script
################################################################################

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  TIBCO Platform - SSL Certificate Generator                   ║"
    echo "║  Version: 1.0 for AKS                                          ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Create certificate directory
    create_cert_directory
    CERT_DIR="$(pwd)/certs"
    
    echo ""
    log_info "Configuration:"
    log_info "  MY Domain:     *.${CP_MY_DNS_DOMAIN}"
    log_info "  TUNNEL Domain: *.${CP_TUNNEL_DNS_DOMAIN}"
    log_info "  Output Dir:    ${CERT_DIR}"
    echo ""
    
    # Generate certificates
    log_info "Generating certificates..."
    echo ""
    
    generate_certificate "$CP_MY_DNS_DOMAIN" "cp-my" "$CERT_DIR"
    echo ""
    
    generate_certificate "$CP_TUNNEL_DNS_DOMAIN" "cp-tunnel" "$CERT_DIR"
    echo ""
    
    # Display Kubernetes secret creation commands
    create_kubernetes_secrets "$CERT_DIR"
    
    # Display summary
    display_summary "$CERT_DIR"
    
    # Update environment variables
    log_info "Updating environment variables..."
    export TP_TLS_CERT_MY="${CERT_DIR}/cp-my-cert.pem"
    export TP_TLS_KEY_MY="${CERT_DIR}/cp-my-key.pem"
    export TP_TLS_CERT_TUNNEL="${CERT_DIR}/cp-tunnel-cert.pem"
    export TP_TLS_KEY_TUNNEL="${CERT_DIR}/cp-tunnel-key.pem"
    
    log_info "Certificate paths exported to environment variables!"
    log_info "  TP_TLS_CERT_MY=${TP_TLS_CERT_MY}"
    log_info "  TP_TLS_KEY_MY=${TP_TLS_KEY_MY}"
    log_info "  TP_TLS_CERT_TUNNEL=${TP_TLS_CERT_TUNNEL}"
    log_info "  TP_TLS_KEY_TUNNEL=${TP_TLS_KEY_TUNNEL}"
    echo ""
}

# Run main function
main "$@"
