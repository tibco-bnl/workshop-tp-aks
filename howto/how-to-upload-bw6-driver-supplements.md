---
layout: default
title: Uploading Driver Supplements to TIBCO BusinessWorks 6 Capability
---

# How to Upload Driver Supplements to TIBCO BusinessWorks 6 (Containers) Capability

**Document Purpose**: Step-by-step guide for uploading Oracle Database and EMS driver supplements to the TIBCO BusinessWorks 6 (Containers) capability after provisioning it in the Data Plane.

**Target Audience**: Integration developers, Platform administrators

**Prerequisites**: 
- TIBCO BusinessWorks 6 (Containers) capability must be provisioned in your Data Plane
- Access to TIBCO Control Plane UI
- Local TIBCO BusinessWorks Container Edition installation (for Oracle driver preparation)
- Local TIBCO EMS installation (for EMS driver preparation)

**Last Updated**: March 6, 2026

---

## Table of Contents

- [Overview](#overview)
- [Oracle Database Driver Supplement](#oracle-database-driver-supplement)
  - [Phase 1: Create the oracle.zip Archive](#phase-1-create-the-oraclezip-archive)
  - [Phase 2: Upload to TIBCO Control Plane](#phase-2-upload-oracle-driver-to-tibco-control-plane)
- [EMS Driver Supplement](#ems-driver-supplement)
  - [Phase 1: Create the ems.zip Archive](#phase-1-create-the-emszip-archive)
  - [Phase 2: Upload to TIBCO Control Plane](#phase-2-upload-ems-driver-to-tibco-control-plane)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Reference](#reference)

---

## Overview

After provisioning the TIBCO BusinessWorks 6 (Containers) capability in your Data Plane, you may need to supplement additional drivers for specific integrations such as:
- **Oracle Database Driver**: For connecting to Oracle databases
- **EMS Client Libraries**: For TIBCO Enterprise Message Service integration

This guide walks you through preparing and uploading these driver supplements via the TIBCO Control Plane UI.

> **Important**: Driver supplements must be packaged in a specific format with all files at the root level of the zip archive (no parent folders).

---

## Oracle Database Driver Supplement

### Phase 1: Create the oracle.zip Archive

#### Step 1: Install the Oracle Driver Locally

First, ensure you have installed the Oracle driver in your local TIBCO BusinessWorks Container Edition environment using the `bwinstall` utility.

```bash
# Navigate to your BWCE installation directory
cd <BWCE_installation_directory>

# Use bwinstall utility to install Oracle driver
# Follow the bwinstall prompts to complete installation
```

#### Step 2: Locate the Required Files

Navigate to the following path in your local BWCE installation directory:

```bash
cd <BWCE_installation_directory>/<BWCE_Version>/config/drivers/shells/jdbc.oracle.runtime/runtime/plugins
```

This directory typically contains the `com.tibco.bw.jdbc.datasourcefactory.oracle` folder and related Oracle driver files.

#### Step 3: Zip the Contents

Create a zip archive containing the contents of the `plugins` folder.

> **Critical**: All contents must be zipped directly into the root of the zip file. **Do not include any parent folders** inside the zipped archive.

**Correct structure (when you open oracle.zip):**
```
oracle.zip
├── com.tibco.bw.jdbc.datasourcefactory.oracle/
│   ├── (Oracle driver files)
└── (other Oracle-related files)
```

**Incorrect structure (DO NOT DO THIS):**
```
oracle.zip
└── plugins/
    └── com.tibco.bw.jdbc.datasourcefactory.oracle/
        └── (Oracle driver files)
```

**Example commands:**

```bash
# Navigate to the plugins directory
cd <BWCE_installation_directory>/<BWCE_Version>/config/drivers/shells/jdbc.oracle.runtime/runtime/plugins

# Create zip archive from current directory contents
zip -r oracle.zip ./*

# Verify the zip structure (root-level files, no parent folder)
unzip -l oracle.zip
```

#### Step 4: Name the File

Ensure the resulting archive is named exactly: **`oracle.zip`**

---

### Phase 2: Upload Oracle Driver to TIBCO Control Plane

Once your `oracle.zip` file is ready, upload it to the BW6 capability.

#### Step 1: Log in to TIBCO Control Plane

Navigate to your TIBCO Control Plane URL and log in with your credentials.

#### Step 2: Navigate to Your Data Plane

1. From the left navigation menu, click **Data Planes**
2. Locate your target Data Plane
3. Click **Go to Data Plane** button

#### Step 3: Open the BW6 Capability

1. On the Data Plane page, you will see all provisioned capabilities
2. Click on your **TIBCO BusinessWorks 6 (Containers)** capability card to open the integration capabilities page

#### Step 4: Upload Supplement

1. Click the **Upload Supplement** button
2. In the **Upload Supplement** window:
   - From the dropdown list, select **Oracle Database plug-in/driver**
   - Drag your `oracle.zip` archive onto the upload area, **OR**
   - Click **browse to upload** to select it from your file system
3. Click **Upload selected file**

#### Step 5: Wait for Upload to Complete

The system will process the upload. You should see a success message indicating the Oracle driver supplement has been uploaded successfully.

---

## EMS Driver Supplement

### Phase 1: Create the ems.zip Archive

#### Step 1: Locate the Required Files

Navigate to your local TIBCO EMS installation directory and open the following path:

```bash
cd <EMS_installation_directory>/EMS/components/shared/1.0.0/plugins
```

#### Step 2: Select the EMS JAR Files

Within the `plugins` directory, select the required EMS `.jar` files needed for your application.

Common files include:
- `tibjms.jar`
- `tibjmsadmin.jar`
- `tibjmsapps.jar`
- `tibjmsufo.jar`
- And other related EMS libraries

#### Step 3: Zip the JAR Files

Compress the selected `.jar` files into a zip archive.

> **Critical**: All `.jar` files must be zipped directly into the root of the zip folder with **no parent folder** inside the zipped folder.

**Correct structure (when you open ems.zip):**
```
ems.zip
├── tibjms.jar
├── tibjmsadmin.jar
├── tibjmsapps.jar
└── (other EMS .jar files)
```

**Incorrect structure (DO NOT DO THIS):**
```
ems.zip
└── plugins/
    ├── tibjms.jar
    └── (other files)
```

**Example commands:**

```bash
# Navigate to the plugins directory
cd <EMS_installation_directory>/EMS/components/shared/1.0.0/plugins

# Create zip archive from JAR files at root level
zip ems.zip *.jar

# Verify the zip structure (JAR files at root, no parent folder)
unzip -l ems.zip
```

#### Step 4: Name the Archive

Ensure the resulting file is named exactly: **`ems.zip`**

---

### Phase 2: Upload EMS Driver to TIBCO Control Plane

Once your `ems.zip` file is ready, upload it to the BW6 capability.

#### Step 1: Log in to TIBCO Control Plane

Navigate to your TIBCO Control Plane URL and log in with your credentials.

#### Step 2: Navigate to Your Data Plane

1. From the left navigation menu, click **Data Planes**
2. Locate your target Data Plane
3. Click **Go to Data Plane** button

#### Step 3: Open the BW6 Capability

1. On the Data Plane page, you will see all provisioned capabilities
2. Click on your **TIBCO BusinessWorks 6 (Containers)** capability card to open the integration capabilities page

#### Step 4: Upload Supplement

1. Click the **Upload Supplement** button
2. In the **Upload Supplement** window:
   - From the dropdown list, select **EMS plug-in/driver**
   - Drag your `ems.zip` archive onto the upload area, **OR**
   - Click **browse to upload** to select it from your file system
3. Click **Upload selected file**

#### Step 5: Wait for Upload to Complete

The system will process the upload. You should see a success message indicating the EMS driver supplement has been uploaded successfully.

---

## Verification

After uploading the driver supplements, verify they are available for use:

1. **Navigate to your BW6 capability** in the Control Plane UI
2. **Check the Supplements section** - you should see the uploaded drivers listed
3. **Deploy a test application** that uses Oracle or EMS connections to confirm the drivers are working correctly

---

## Troubleshooting

### Upload Fails with "Invalid Archive Structure" Error

**Cause**: The zip file contains a parent folder instead of having files at the root level.

**Solution**: 
- Extract the zip file
- Re-create it ensuring files are at the root level (see examples above)
- Use the command: `zip -r <filename>.zip ./*` from within the directory containing the files

### Oracle Driver Not Recognized After Upload

**Cause**: The Oracle driver files were not properly installed using `bwinstall` before zipping.

**Solution**:
- Verify the Oracle driver installation in your local BWCE environment
- Ensure you're zipping from the correct `plugins` directory
- Check that `com.tibco.bw.jdbc.datasourcefactory.oracle` folder is present in the zip

### EMS JAR Files Not Found

**Cause**: Incorrect path to EMS installation or missing components.

**Solution**:
- Verify your EMS installation is complete
- Check the path: `<EMS_installation_directory>/EMS/components/shared/1.0.0/plugins`
- Ensure all required JAR files are present before zipping

### Cannot Find Upload Supplement Button

**Cause**: BW6 capability may not be fully provisioned.

**Solution**:
- Wait for the capability provisioning to complete
- Refresh the Control Plane UI
- Verify you're viewing the correct capability (TIBCO BusinessWorks 6 Containers)

---

## Reference

**Official TIBCO Documentation**:
- [Supplementing Drivers - TIBCO Platform 1.15.0](https://docs.tibco.com/pub/platform-cp/1.15.0/doc/html/Default.htm#Subsystems/bwce-capability/bwce-user-guide/supplementing-drivers.htm)

**Related Workshop Guides**:
- [TIBCO Platform Data Plane Setup on AKS](how-to-dp-aks-setup-guide.md)
- [TIBCO Platform Control Plane and Data Plane Setup on AKS](how-to-cp-and-dp-aks-setup-guide.md)

---

**Questions or Issues?** Refer to the official TIBCO documentation or contact TIBCO Support.
