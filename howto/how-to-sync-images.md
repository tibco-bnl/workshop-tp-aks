---
layout: default
title: How to Push TIBCO Platform Images to a Custom Container Registry
---

# How to Push TIBCO Platform Images to a Custom Container Registry

When deploying TIBCO Platform in environments where AKS cluster nodes cannot reach the TIBCO JFrog registry directly — such as corporate firewalled environments, regulated environments requiring private registry policies, or air-gapped deployments — you must first mirror the required container images to an accessible internal registry before running the Helm install.

This guide covers the official TIBCO synchronization script, safe copy methods for each environment type, BusinessWorks plugin image requirements, and a verification and remediation runbook.

> **Official sync script**: [TIBCOSoftware/tp-helm-charts — sync-artifacts](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/scripts/sync-artifacts)  
> **See also**: If BW plugin extraction jobs fail after pushing images, see [Troubleshooting — BW Plugin Extraction Crash](./troubleshooting#businessworks-plugin-extraction-crash--image-layer-corruption) for diagnosis steps.

---

## Prerequisites

### Tools

| Tool | Purpose | Required For |
|------|---------|-------------|
| `docker` + `buildx` plugin | Bit-perfect manifest copy | `sync-images.sh` and `imagetools` |
| `skopeo` | Bit-perfect registry-to-registry copy | Podman or skopeo-only environments |
| `az` CLI | Azure Container Registry login | ACR target registries |
| `helm` 3.17+ | Chart sync (optional) | `sync-charts.sh` |

### Credentials

- [ ] TIBCO JFrog registry credentials (provided by TIBCO): `csgprduswrepoedge.jfrog.io`
- [ ] Target registry credentials (ACR service principal or managed identity)
- [ ] `RELEASE_VERSION` — the TIBCO Platform version being deployed (e.g., `1.18.0`)

### Clone the TIBCO tp-helm-charts Repository

The sync script and image lists live in the tp-helm-charts repository:

```bash
git clone https://github.com/TIBCOSoftware/tp-helm-charts.git
cd tp-helm-charts/scripts/sync-artifacts
```

---

## The Official TIBCO sync-images.sh Script

TIBCO provides an official synchronization script at [`scripts/sync-artifacts/sync-images.sh`](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/scripts/sync-artifacts).

**This is the recommended method.** The script uses `docker buildx imagetools create` internally, which performs a bit-perfect registry-to-registry copy — images are never pulled or re-compressed locally. This is safe for all image types including BusinessWorks plugins.

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SOURCE_REGISTRY` | TIBCO JFrog source registry | `csgprduswrepoedge.jfrog.io` |
| `SOURCE_REGISTRY_USERNAME` | JFrog username | `your-username` |
| `SOURCE_REGISTRY_PASSWORD` | JFrog password or API token | `your-token` |
| `RELEASE_VERSION` | Platform version (`major.minor.patch`) | `1.18.0` |
| `TARGET_REGISTRY` | Your private registry URL | `myacr.azurecr.io` |

### Optional Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TARGET_REGISTRY_USERNAME` | — | Target registry username |
| `TARGET_REGISTRY_PASSWORD` | — | Target registry password |
| `TARGET_REGISTRY_REPO` | — | Target repository path override |
| `CAPABILITY_NAME` | _(all)_ | Sync only a specific capability (e.g., `bwce`) |
| `MAX_RETRY` | `0` | Retry count for failed copy operations |
| `WAIT_BEFORE_RETRY` | `0` | Seconds between retries |
| `WRITE_SCRIPT_LOGS_TO_FILE` | `false` | Write logs to `image_sync_<timestamp>.log` |

### Usage

```bash
export SOURCE_REGISTRY="csgprduswrepoedge.jfrog.io"
export SOURCE_REGISTRY_USERNAME="john.doe@company.com"
export SOURCE_REGISTRY_PASSWORD="AKCp8mnyYZQ..."
export RELEASE_VERSION="1.18.0"
export TARGET_REGISTRY="tibcoworkshopacr.azurecr.io"
export TARGET_REGISTRY_USERNAME="sp-tibco-acr-push"
export TARGET_REGISTRY_PASSWORD="V3ryStr0ngP@ssw0rd!"

cd tp-helm-charts/scripts/sync-artifacts
./sync-images.sh
```

The script reads image lists from `../../artifacts/*-${RELEASE_VERSION}-images.txt` and copies each image directly between registries without touching local disk.

---

## ⚠️ Critical: BusinessWorks Plugin Images Require Bit-Perfect Copying

> **Do not use `docker push`, `podman push`, `docker save`, or `podman save` to transfer BusinessWorks plugin images.** These commands silently re-compress image layers and cause extraction jobs to fail during BW capability deployment.

### What Breaks

When using standard push/save commands, the container engine decompresses and re-compresses image layers locally. For BusinessWorks plugin images (which contain nested Java archives), this changes the internal GZIP DEFLATE block type:

| Block Type | Bytes 10–11 | Extraction Result |
|-----------|-------------|------------------|
| `BTYPE=01` Fixed Huffman — original TIBCO layer | `ecf2` | ✅ Succeeds |
| `BTYPE=00` Stored block — re-compressed by push | `00ff` | ❌ `tar: invalid tar header checksum` |

The `busybox tar` binary inside the `bwce-utilities` extraction container cannot handle `BTYPE=00` stored blocks.

### What to Use Instead

Any of the safe methods below perform registry-to-registry copies that stream raw layer blobs without local re-compression, preserving the original `BTYPE=01` headers.

---

## Safe Image Copy Methods

### Method 1 — sync-images.sh (Recommended)

See the [previous section](#the-official-tibco-sync-imagessh-script). The official script handles all images at once with retry logic and logging.

---

### Method 2 — docker buildx imagetools (Manual, per-image)

Use this for copying individual images or when the full sync script is not needed.

```bash
# Log in to both registries
docker login csgprduswrepoedge.jfrog.io \
  --username john.doe@company.com --password AKCp8mnyYZQ...

az acr login --name tibcoworkshopacr

# Copy directly between registries — no local disk use
docker buildx imagetools create \
  --tag tibcoworkshopacr.azurecr.io/tibco-platform/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0 \
  csgprduswrepoedge.jfrog.io/tibco-platform-docker-prod/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0
```

---

### Method 3 — skopeo copy (Podman or skopeo-only environments)

`skopeo` streams raw binary chunks directly between registries without local decompression. Use `--format v2s2` to preserve the Docker V2 Schema 2 layer structure.

```bash
# Log in
skopeo login csgprduswrepoedge.jfrog.io \
  --username john.doe@company.com --password AKCp8mnyYZQ...
skopeo login tibcoworkshopacr.azurecr.io \
  --username sp-tibco-acr-push --password V3ryStr0ngP@ssw0rd!

# Copy a single image
skopeo copy --format v2s2 \
  docker://csgprduswrepoedge.jfrog.io/tibco-platform-docker-prod/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0 \
  docker://tibcoworkshopacr.azurecr.io/tibco-platform/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0
```

---

### Method 4 — skopeo dir:// (Air-Gapped / No Direct Connectivity)

Use this when the AKS cluster and the TIBCO registry have no shared network path and images must be physically transported across an air-gap.

> **Do not use `docker save` / `podman save` for this.** Always use `skopeo copy dir://` which preserves raw layer blobs.

**On the internet-connected machine:**

```bash
# Dump raw blobs to a staging directory (preserves original GZIP headers)
skopeo copy \
  docker://csgprduswrepoedge.jfrog.io/tibco-platform-docker-prod/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0 \
  dir:/tmp/staging/tci-bw-plugin-cics

# Archive the staging directory
tar -cvf tibco-bw-plugins.tar -C /tmp/staging tci-bw-plugin-cics

# [Transfer the archive across the air-gap]
```

**On the target machine (inside the secure network):**

```bash
tar -xvf tibco-bw-plugins.tar -C /tmp/staging

# --force ensures any previously corrupted blobs are overwritten
skopeo copy --force --format v2s2 \
  dir:/tmp/staging/tci-bw-plugin-cics \
  docker://tibcoworkshopacr.azurecr.io/tibco-platform/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0
```

---

### Method Comparison

| Method | Tooling | Best For | Bit-Perfect |
|--------|---------|----------|-------------|
| `sync-images.sh` | Docker + buildx | All images at once, recommended path | ✅ Yes |
| `docker buildx imagetools` | Docker + buildx | Manual per-image copy | ✅ Yes |
| `skopeo copy` | skopeo | Podman environments, scripted copy | ✅ Yes |
| `skopeo dir://` | skopeo | Air-gapped / physical data transfer | ✅ Yes |
| `docker push` / `podman push` | Any | ❌ Avoid for BW plugin images | ❌ No |

---

## Azure Container Registry (ACR) Setup

### Create the ACR and Grant AKS Pull Access

```bash
# Create ACR
az acr create --name tibcoworkshopacr --resource-group rg-tibco-workshop --sku Standard --location westeurope

# Attach ACR to AKS (grants pull access via managed identity)
az aks update --name aks-tibco-workshop --resource-group rg-tibco-workshop \
  --attach-acr tibcoworkshopacr
```

### Log In for Image Copying

```bash
# Option A: az acr login (recommended for local dev)
az acr login --name tibcoworkshopacr

# Option B: service principal credentials (for CI/CD pipelines)
az acr login --name tibcoworkshopacr \
  --username a1b2c3d4-e5f6-7890-abcd-ef1234567890 --password V3ryStr0ngP@ssw0rd!
```

### Create the Kubernetes Image Pull Secret (if not using managed identity)

```bash
kubectl create secret docker-registry tibco-container-registry-credentials \
  --docker-server=tibcoworkshopacr.azurecr.io \
  --docker-username=a1b2c3d4-e5f6-7890-abcd-ef1234567890 \
  --docker-password=V3ryStr0ngP@ssw0rd! \
  --docker-email=platform-team@company.com \
  -n cp1-ns
```

---

## Verify Image Integrity

After pushing images, verify that BusinessWorks plugin layer headers are intact before running the Helm install.

```bash
REGISTRY="tibcoworkshopacr.azurecr.io"
REPO="tibco-platform"
IMAGE="tci-bw-plugin-cics"
TAG="2.5.0.v4.3-tci-2.0"
TOKEN=$(az acr login --name tibcoworkshopacr --expose-token --query accessToken -o tsv)

# Get the first layer digest
DIGEST=$(curl -s \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  "https://$REGISTRY/v2/$REPO/$IMAGE/manifests/$TAG" \
  | jq -r '.layers[0].digest')

# Download and inspect the layer blob
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://$REGISTRY/v2/$REPO/$IMAGE/blobs/$DIGEST" \
  -o /tmp/check_header.tar.gz

xxd /tmp/check_header.tar.gz | head -1
```

**Expected output (intact image):**
```
00000000: 1f8b 0800 0000 0000 00ff ecf2 638c 2f40 ...
```

Bytes 10–11 should read `ecf2` (BTYPE=01 Fixed Huffman). If you see `00ff` (BTYPE=00 Stored), re-mirror the image using a bit-perfect method before proceeding.

---

## Runbook: Fix an Already-Corrupted Registry

If images were previously pushed using standard push commands and the registry has cached corrupted layers, a new push will be skipped (`already exists`). You must force-overwrite using `--force`.

### Step 1 — Re-push with --force

```bash
skopeo copy --force --format v2s2 \
  docker://csgprduswrepoedge.jfrog.io/tibco-platform-docker-prod/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0 \
  docker://tibcoworkshopacr.azurecr.io/tibco-platform/tci-bw-plugin-cics:2.5.0.v4.3-tci-2.0
```

### Step 2 — Delete Broken Extraction Job Pods

```bash
kubectl delete jobs -n cp1-ns \
  --selector=app.kubernetes.io/component=bwce-utilities
```

### Step 3 — Verify Header Integrity

Run the verification commands above. Confirm `ecf2` is present.

### Step 4 — Retry the Helm Install

The extraction jobs will now find intact images and complete successfully.

---

## Additional Resources

- [TIBCOSoftware/tp-helm-charts — sync-artifacts](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/scripts/sync-artifacts)
- [TIBCO Platform — Pushing Images to Custom Container Registry](https://docs.tibco.com/pub/platform-cp/latest/doc/html/UserGuide/pushing-images-to-registry.htm)
- [Customer Prerequisites Checklist](./prerequisites-checklist-for-customer)
- [AKS Firewall Requirements](../docs/firewall-requirements-aks)
- [skopeo documentation](https://github.com/containers/skopeo)
- [docker buildx imagetools](https://docs.docker.com/engine/reference/commandline/buildx_imagetools/)
- [Azure Container Registry documentation](https://docs.microsoft.com/en-us/azure/container-registry/)
