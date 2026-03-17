# TIBCO Platform 1.15.0 AKS Workshop Guide - Update Summary

## Overview
This document summarizes all changes made to the AKS workshop guide to incorporate the DNS simplification and optional hybrid connectivity features introduced in TIBCO Platform 1.15.0.

## Updated Date
March 17, 2026

## Files Modified

### 1. Main Guide: `how-to-cp-and-dp-aks-setup-guide.md`

#### Section: "What's New in v1.15.0"
**Changes:**
- Added "Major Architectural Changes" subsection highlighting DNS simplification and optional hybrid-proxy
- Documented resource savings (50% CPU/RAM) when hybrid connectivity disabled
- Added links to new reference documentation
- Expanded breaking changes to mention DNS structure options
- Added feature highlighting optional hybrid-proxy component

**Impact:** Users now understand the two DNS configuration options and when to use each

---

#### Section: "Step 1.3 - DNS Configuration Options (NEW)"
**Changes:**
- **NEW SECTION**: Comprehensive guide comparing two DNS approaches
  - **Option 1: Simplified DNS** (Recommended)
    - Single-level subdomain structure: `admin.example.com`
    - Single wildcard certificate
    - Optional hybrid-proxy
    - 50% resource savings when hybrid-proxy disabled
  - **Option 2: Legacy DNS** (Backward Compatible)
    - Multi-level subdomain structure: `admin.my.cp1.example.com`
    - Separate wildcard certificates
    - Hybrid-proxy typically enabled
    
- Added environment variable examples for both options
- Added DNS record requirements for each option
- Provided decision guidance with use case scenarios
- Linked to detailed Quick Reference guide

**Impact:** Clear decision framework for DNS architecture selection

---

#### Section: "Step 8 - Create Certificates"
**Changes:**
- Split into two complete configurations:
  - **Configuration 1: Simplified DNS - Single Wildcard Certificate**
    - Uses single certificate secret: `base-domain-cert`
    - Certificate covers `*.example.com`
    - Simplified certificate generation commands
    - Includes Let's Encrypt production option
  - **Configuration 2: Legacy DNS - Separate Domain Certificates**
    - Uses two certificate secrets: `my-domain-cert` and `tunnel-domain-cert`
    - Separate certificates for MY and TUNNEL domains
    - Backward compatible with 1.14.x

- Added subsection "8.2 DNS Record Creation"
  - Separate instructions for Simplified DNS (A records for specific subdomains)
  - Separate instructions for Legacy DNS (wildcard records)
  - Conditional tunnel DNS record creation based on `CP_HYBRID_CONNECTIVITY`
  - Alternative DNS setup options (hosts file, custom DNS server)

**Impact:** Clear certificate strategy aligned with DNS choice, automated DNS record creation

---

#### Section: "Step 9.2 - Create Control Plane Values File"
**Changes:**
- Completely restructured to present two complete configurations
- **Configuration 1: Simplified DNS Values** (NEW)
  - Environment variable setup for simplified approach
  - Complete Helm values file with:
    - `global.tibco.hybridConnectivity.enabled: ${CP_HYBRID_CONNECTIVITY}`
    - `hybrid-proxy.enabled: ${CP_HYBRID_CONNECTIVITY}` (conditional)
    - `router-operator.ingress.hosts`: Direct subdomain references without wildcards
      - `${CP_ADMIN_HOST_PREFIX}.${TP_BASE_DNS_DOMAIN}`
      - `${CP_SUBSCRIPTION}.${TP_BASE_DNS_DOMAIN}`
    - `hybrid-proxy.ingress.hosts`: `tunnel.${TP_BASE_DNS_DOMAIN}` (when enabled)
    - Session keys using `SESSION_KEY` and `SESSION_IV`
    - Single certificate secret reference
  - Uses `envsubst` for variable substitution
  
- **Configuration 2: Legacy DNS Values** (NEW)
  - Environment variable setup for legacy approach
  - Complete Helm values file with:
    - `global.external.dnsDomain: ${CP_MY_DNS_DOMAIN}`
    - `global.external.dnsTunnelDomain: ${CP_TUNNEL_DNS_DOMAIN}`
    - `global.tibco.hybridConnectivity.enabled: true` (always enabled)
    - `hybrid-proxy.enabled: true` with TLS configuration
    - `router-operator.ingress`: Wildcard hosts with TLS
    - Separate certificate secrets for MY and TUNNEL domains
  - Uses `envsubst` for variable substitution
  
- Added comprehensive notes explaining differences
- Added production deployment tips for resource customization

**Impact:** Users can follow step-by-step instructions for their chosen DNS approach

---

#### Section: "Step 9.3, 9.4, 9.5 - Deploy Control Plane"
**Changes:**
- No changes required - deployment steps are generic and work with both configurations
- Both configurations generate `cp-values.yaml` used by Helm deployment
- Capability chart installation identical for both approaches

**Impact:** Simplified deployment process regardless of DNS choice

---

## New Documentation Files Created

### 2. `CHANGES-1.15.0-DNS-SIMPLIFICATION.md`
**Purpose:** Comprehensive explanation of architectural changes

**Content:**
- Detailed comparison of DNS structures (before/after)
- Hybrid connectivity explained (when optional, when required)
- Environment variable changes
- Router-operator ingress configuration examples
- DNS record creation patterns
- Certificate generation approaches
- Migration guide for existing deployments
- When to use hybrid connectivity
- Prerequisites updates
- Benefits analysis
- Configuration examples with full Helm values
- Ingress controller support matrix
- Backward compatibility guidance

**Impact:** In-depth technical reference for understanding 1.15.0 changes

---

### 3. `DNS-CONFIGURATION-QUICK-REFERENCE.md`
**Purpose:** Quick decision guide and command reference

**Content:**
- **Decision flowchart** (Mermaid diagram)
  - Hybrid connectivity decision tree
  - Leads to simplified or standalone deployment
  
- **Quick Decision Matrix** table
  - Scenario comparisons
  - Resource estimates
  - Deployment time estimates
  
- **Configuration Comparison** side-by-side
  - Environment variables
  - DNS records
  - Certificate generation commands
  - Complete Helm values for both options
  
- **Quick Start Commands** for common scenarios
  - Standalone Control Plane (no hybrid)
  - Control Plane with hybrid connectivity
  
- **Certificate Generation Options** (A, B, C)
  - Single wildcard (recommended)
  - Specific subdomain certificates
  - Let's Encrypt production
  
- **DNS Zone Configuration** with Azure CLI
  - Simplified DNS record creation
  - Wildcard DNS alternative
  
- **Verification Commands** for each component
  - DNS resolution
  - Certificate validation
  - Ingress verification
  - Control Plane pods
  - Access UI
  
- **Troubleshooting** section
  - DNS issues
  - Certificate issues
  - Ingress issues
  - Hybrid-proxy issues
  
- **Common Patterns** examples
  - Multi-subscription setup
  - Multi-region setup
  - Environment isolation
  
- **Resource Requirements Comparison** table
- **Migration Path** guidance from 1.14.x to 1.15.0

**Impact:** Fast lookup reference for operators making deployment decisions

---

### 4. `UPDATE-SUMMARY.md` (This File)
**Purpose:** Change log documenting all modifications

**Content:**
- Complete list of modified sections
- New files created
- Validation checklist
- Testing recommendations
- Next steps

---

## Key Improvements

### 1. Flexibility
- Users can choose between simplified or legacy DNS architecture
- Hybrid connectivity is now clearly optional
- Both approaches fully documented and supported

### 2. Clarity
- Clear decision framework with use case scenarios
- Side-by-side comparison of configurations
- Explicit environment variable definitions

### 3. Completeness
- Full Helm values files for both configurations
- Certificate generation for both approaches
- DNS record creation for both patterns
- Verification commands for all components

### 4. Resource Optimization
- Documented 50% resource savings when hybrid-proxy disabled
- Clear guidance on when hybrid connectivity needed
- Resource requirement tables for planning

### 5. Production Readiness
- Let's Encrypt certificate generation included
- Production-grade Helm value customization tips
- Troubleshooting guidance for common issues

### 6. Backward Compatibility
- Legacy DNS configuration fully supported
- Migration path from 1.14.x documented
- No breaking changes for existing deployments

---

## Validation Checklist

### Documentation Review
- [x] "What's New" section updated with DNS simplification
- [x] DNS configuration options documented (Step 1.3)
- [x] Certificate generation split into two configurations (Step 8)
- [x] Helm values files provided for both approaches (Step 9.2)
- [x] DNS record creation automated with Azure CLI (Step 8.2)
- [x] Deployment steps remain generic and compatible (Step 9.3-9.5)

### Reference Documentation
- [x] CHANGES-1.15.0-DNS-SIMPLIFICATION.md created
- [x] DNS-CONFIGURATION-QUICK-REFERENCE.md created
- [x] UPDATE-SUMMARY.md created
- [x] Links to reference docs added in main guide

### Technical Accuracy
- [x] Environment variables aligned with TIBCO 1.15.0
- [x] Helm values keys match official chart structure
- [x] Certificate generation commands tested
- [x] DNS record creation commands valid for Azure DNS
- [x] Ingress configuration correct for Traefik and NGINX
- [x] Session keys secret keys corrected to SESSION_KEY and SESSION_IV

### Consistency
- [x] Terminology consistent across all documents
- [x] Variable naming conventions consistent
- [x] Configuration patterns aligned with ARO guide
- [x] Code blocks properly formatted
- [x] Mermaid diagrams valid

---

## Testing Recommendations

### Test Scenario 1: Simplified DNS (New Deploy)
1. Set environment variables per "Configuration 1: Simplified DNS"
2. Set `CP_HYBRID_CONNECTIVITY="false"`
3. Generate single wildcard certificate
4. Create DNS A records for `admin` and `dev` subdomains
5. Deploy using simplified Helm values
6. Verify hybrid-proxy pods NOT running
7. Access Control Plane UI at `admin.${TP_BASE_DNS_DOMAIN}`
8. Verify resource usage ~50% lower than legacy

### Test Scenario 2: Simplified DNS with Hybrid Connectivity
1. Set environment variables per "Configuration 1: Simplified DNS"
2. Set `CP_HYBRID_CONNECTIVITY="true"`
3. Generate single wildcard certificate
4. Create DNS A records for `admin`, `dev`, and `tunnel`
5. Deploy using simplified Helm values
6. Verify hybrid-proxy pods ARE running
7. Verify tunnel ingress accessible

### Test Scenario 3: Legacy DNS (Backward Compatible)
1. Set environment variables per "Configuration 2: Legacy DNS"
2. Generate separate MY and TUNNEL certificates
3. Create wildcard DNS records for MY and TUNNEL domains
4. Deploy using legacy Helm values
5. Verify Control Plane accessible at `admin.my.cp1.${TP_DOMAIN}`
6. Verify tunnel accessible at wildcard TUNNEL domain

### Test Scenario 4: Migration from 1.14.x
1. Existing 1.14.x deployment with legacy DNS
2. Upgrade to 1.15.0 using "Configuration 2: Legacy DNS"
3. Verify no service disruption
4. All existing Data Planes continue to connect
5. Plan future migration to simplified DNS during next certificate renewal

---

## Next Steps

### For Workshop Participants
1. Review [DNS-CONFIGURATION-QUICK-REFERENCE.md](./DNS-CONFIGURATION-QUICK-REFERENCE.md) to choose your DNS approach
2. Follow main guide [how-to-cp-and-dp-aks-setup-guide.md](./how-to-cp-and-dp-aks-setup-guide.md) with your chosen configuration
3. Refer to [CHANGES-1.15.0-DNS-SIMPLIFICATION.md](./CHANGES-1.15.0-DNS-SIMPLIFICATION.md) for detailed technical explanations

### For Production Deployments
1. Evaluate if hybrid connectivity is required for your architecture
2. Choose simplified DNS for new deployments unless legacy structure required
3. Plan certificate strategy (Let's Encrypt vs self-signed vs corporate CA)
4. Review resource requirements and adjust Helm values accordingly
5. Test in non-production environment before production deployment

### For Existing 1.14.x Deployments
1. Upgrade to 1.15.0 using legacy DNS configuration (no immediate changes)
2. Plan migration to simplified DNS during next certificate renewal cycle
3. Evaluate if hybrid-proxy can be disabled to reduce resource usage
4. Test simplified DNS in non-production environment

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| **Files Modified** | 1 (main guide) |
| **Files Created** | 3 (reference docs) |
| **Major Sections Updated** | 4 (What's New, DNS Config, Certificates, Helm Values) |
| **New Subsections Added** | 6 |
| **Configuration Options** | 2 (Simplified, Legacy) |
| **Complete Helm Values Files** | 2 |
| **Certificate Approaches** | 3 (Wildcard, Separate, Let's Encrypt) |
| **DNS Pattern Examples** | 2 (Simplified, Legacy) |
| **Decision Flowcharts** | 1 (Mermaid diagram) |
| **Comparison Tables** | 3 (Decision Matrix, Resource Requirements, Config Comparison) |
| **Verification Commands** | 15+ |
| **Troubleshooting Sections** | 4 (DNS, Cert, Ingress, Hybrid-Proxy) |

---

## Compatibility Matrix

| Version | Simplified DNS | Legacy DNS | Hybrid-Proxy Optional | Single Cert | Separate Certs |
|---------|----------------|------------|----------------------|-------------|----------------|
| 1.14.x | ❌ No | ✅ Yes | ❌ No | ❌ No | ✅ Yes |
| 1.15.0 | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |

---

## Feedback and Contributions

If you encounter issues with this documentation or have suggestions for improvements:

1. **Documentation Issues**: Create an issue in the workshop repository
2. **Technical Questions**: Consult TIBCO Platform official documentation
3. **Community Support**: TIBCO Community forums

---

**Document Version:** 1.0  
**Last Updated:** March 17, 2026  
**Applies To:** TIBCO Platform Control Plane 1.15.0 on Azure Kubernetes Service (AKS)  
**Maintained By:** TIBCO Platform Workshop Team
