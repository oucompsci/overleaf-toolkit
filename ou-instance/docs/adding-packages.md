# Adding LaTeX Packages to Overleaf

## Overview

This Overleaf instance uses **TeX Live** for LaTeX package management. By default, the Overleaf Docker image includes only a minimal TeX Live installation to save bandwidth and disk space. This document explains how to add additional LaTeX packages when needed.

## Default Package Installation

The base Overleaf image installs TeX Live with the `scheme-basic` profile, which includes only essential packages plus a few additional tools:

- `latexmk` - Build automation tool for LaTeX documents
- `texcount` - Word counting utility
- `synctex` - Synchronization between source and output
- `etoolbox` - Toolbox for LaTeX programming
- `xetex` - XeTeX engine

This minimal installation is sufficient for basic LaTeX documents but may not include specialized packages your users need.

## Package Management Methods

### Method 1: Installing Individual Packages

If you only need specific packages, you can install them individually using the TeX Live Manager (`tlmgr`).

#### Step 1: Enter the Overleaf Container

From the toolkit directory:

```bash
cd /ssd/overleaf/overleaf-toolkit
bin/shell
```

You should see a prompt like:
```
root@309b192d4030:/#
```

#### Step 2: Check Your TeX Live Version

It's important to know which version of TeX Live you're running:

```bash
tlmgr --version
```

Example output:
```
tlmgr revision 59291 (2021-05-21 05:14:40 +0200)
tlmgr using installation: /usr/local/texlive/2021
TeX Live (https://tug.org/texlive) version 2021
```

**Note**: If you're running an older TeX Live version (not the current release), you may need to configure `tlmgr` to use a historic repository. See the [TeX Live documentation](https://www.tug.org/texlive/acquire.html#past) for details.

#### Step 3: Install Packages

Install the packages you need:

```bash
tlmgr install tikzlings tikzmarmots tikzducks
```

#### Step 4: Update System Path (Required)

**Important**: From Overleaf version 3.3.0 onwards, you must run this command after every `tlmgr install`:

```bash
tlmgr path add
```

This ensures all binaries are correctly symlinked into the system path.

#### Step 5: Exit the Container

```bash
exit
```

### Method 2: Installing Full TeX Live

If you want all available LaTeX packages, you can install the complete TeX Live distribution:

#### Step 1: Enter the Container

```bash
cd /ssd/overleaf/overleaf-toolkit
bin/shell
```

#### Step 2: Install Full Scheme

```bash
tlmgr install scheme-full
```

**Warning**: This will download and install several gigabytes of packages. It may take considerable time depending on your internet connection.

#### Step 3: Update System Path

```bash
tlmgr path add
```

#### Step 4: Exit the Container

```bash
exit
```

## Making Changes Persistent

**Critical**: Any changes made inside the container are temporary and will be lost when the container is recreated (e.g., during config updates or system restarts).

To make your package installations permanent, you must commit the container to a new Docker image:

### Step 1: Check Current Version

```bash
cd /ssd/overleaf/overleaf-toolkit
cat config/version
```

Example output: `5.0.3`

### Step 2: Commit the Container

Create a new Docker image with your changes, using a descriptive tag that includes the version:

```bash
docker commit sharelatex sharelatex/sharelatex:5.0.3-with-texlive-full
```

Or for custom packages:

```bash
docker commit sharelatex sharelatex/sharelatex:5.0.3-with-custom-packages
```

### Step 3: Update Version Configuration

Update the version file to reference your new image:

```bash
echo 5.0.3-with-texlive-full > config/version

### Step 4: Recreate the Container

Apply the changes by recreating the container:

```bash
bin/up
```

## Additional Resources

- **TeX Live Manager Help**: Run `tlmgr help` inside the container for all available commands
- **TeX Live Homepage**: https://www.tug.org/texlive/
- **TeX Live Package Browser**: https://www.ctan.org/pkg/
- **Official Documentation**: See `/ssd/overleaf/overleaf-toolkit/doc/ce-upgrading-texlive.md`

## Troubleshooting

### Package Not Found

If `tlmgr` can't find a package:
1. Ensure you're using the correct package name (search on CTAN)
2. Check if your TeX Live version is outdated
3. Update the package database: `tlmgr update --self`

### Changes Lost After Restart

If your installed packages disappear:
- You forgot to commit the container to a new image
- Follow the "Making Changes Persistent" section above

### Out of Date TeX Live

If you're running an old TeX Live version:
1. Wait for the next Overleaf image release and upgrade using `bin/upgrade`
2. Or configure `tlmgr` to use historic repositories (see TeX Live documentation)

## Notes for Administrators

- **Upgrades**: When upgrading Overleaf, you'll need to reinstall packages or recreate your custom image with the new base version
- **Disk Space**: A full TeX Live installation requires several gigabytes of storage
- **Backup**: Consider backing up your Docker image or documenting the packages you've installed
- **Server Pro Alternative**: Server Pro editions support sandboxed compiles with pre-built full TeX Live images

## Architecture Notes

The Overleaf application consists of multiple services:

- **CLSI (Compiler Service)**: Handles LaTeX compilation using the installed TeX Live packages
- **Base Image**: Built from `Dockerfile-base` with minimal TeX Live
- **Main Image**: Built from base image, contains the Overleaf application

Package installations modify the running container, which is why committing to a new image is necessary for persistence.

## Example Workflow

Here's a complete example of adding the `pgfplots` package:

```bash
# Enter the toolkit directory
cd /ssd/overleaf/overleaf-toolkit

# Enter the container
bin/shell

# Install the package
tlmgr install pgfplots

# Update paths
tlmgr path add

# Exit the container
exit

# Save the changes
docker commit sharelatex sharelatex/sharelatex:5.0.3-with-pgfplots 
echo 5.0.3-with-pgfplots > config/version # update the version. this implies we can rollback versions too.

# Apply changes
bin/stop # graceful shutdown. do this for safety.
bin/up # remember to restart the server
```cd 

---

**Last Updated**: October 24, 2025

