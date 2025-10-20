# OU Fork Modifications

This fork of the Overleaf Toolkit has been customized for the University of Oklahoma Computer Science department to provide a production-ready, SAML-authenticated LaTeX collaboration platform. The modifications documented below reflect deployment-specific requirements and operational tooling developed for the OUCS infrastructure.

## OU Instance Scripts

All files related to this fork of Overleaf, besides this README.md, are in the subdirectory `/ou-instance`.

## Images

The images are built from [overleaf-cep](https://github.com/yu-i-i/overleaf-cep).

> **Note:** The original Overleaf Toolkit documentation has been preserved and migrated to the bottom of this file for reference.

---

## Table of Contents
- [Authentication](#saml-authentication)
- [Certificate Management](#certificate-management)
- [Configuration Changes](#configuration-changes)
- [Instance Management Tools](#ou-instance-management-ou-instance)
- [Backup and Restoration](#restoring-from-backup)
- [Version Control](#version-control)
- [Notes and Limitations](#notes-and-limitations)

---

### SAML Authentication

This instance is configured to use the University of Oklahoma's centralized Single Sign-On (SSO) system via SAML 2.0 authentication. This integration ensures that:

- Users authenticate using their existing OU credentials
- Access control is managed centrally through OU's identity management system
- No separate password management is required for Overleaf
- User provisioning is automatic upon first login

The SAML configuration is defined in `config/variables.env` with the external authentication mode enabled. All authentication requests are redirected to the OU SSO portal, and successful authentication results in automatic user account creation within Overleaf.

### Certificate Management

The SAML authentication system requires a certificate for secure communication with the OU identity provider. The certificate management is handled as follows:

**Certificate Location:**
- **Host path:** `/ssd/overleaf/overleaf-toolkit/cert.pem`
- **Container path:** `/var/lib/overleaf/cert.pem`
- **Mount mode:** Read-only

**Technical Details:**
- The certificate is mounted directly from the host filesystem into the running container, allowing certificate rotation without rebuilding the container image
- The SAML certificate contains only public key material and does not include private credentials, making it safe to include in version control if needed
- However, `cert.pem` is currently excluded from version control via `.gitignore` for organizational preference

**Certificate Renewal:**
When the SAML certificate needs to be renewed, simply replace the `cert.pem` file on the host and restart the Overleaf container using `bin/stop` followed by `bin/up`. No code changes or configuration updates are required.

### Configuration Changes

The following configuration modifications have been made to customize the instance for OUCS deployment. All configuration files are located in the `config/` directory:

**Branding and Identity:**
- **Application Name:** `OUCS Overleaf` - Displays in the browser tab and application metadata
- **Site URL:** `https://overleaf.cs.ou.edu` - The canonical URL for accessing the service
- **Navigation Title:** `Overleaf at OUCS` - Appears in the top navigation bar

**Deployment Architecture:**
- **Sibling Containers:** Disabled (`SIBLING_CONTAINERS_ENABLED=false`)
  - This setting is appropriate for single-host deployments where all containers run on the same Docker host
  - Sibling container mode is only needed for distributed architectures with separate compile hosts

**User Experience:**
- **Email Confirmation:** Disabled
  - Since users authenticate via SAML, their email addresses are already verified by the OU identity system
  - This eliminates an unnecessary step in the user onboarding process

**Authentication Mode:**
- **External Authentication:** Set to SAML mode
  - Disables local password authentication
  - All authentication is delegated to the OU SSO system

All configuration changes are version-controlled (see [Version Control](#version-control) below) to maintain a clear history of deployment-specific customizations.

### OU Instance Management (`ou-instance/`)

A suite of custom operational scripts has been developed to assist with common administrative tasks. These scripts are located in the `ou-instance/` directory and provide functionality for backup, monitoring, and data export operations.

**Available Scripts:**

1. **`full-backup.sh`** - Complete Data Backup
   - Creates a compressed archive of the entire `data/` directory, including MongoDB databases, Redis state, and all user-uploaded files
   - Automatically stops the Overleaf server before backup to ensure data consistency
   - Generates timestamped backup files to prevent accidental overwrites
   - Optionally restarts the server after backup completion
   - Backups are stored in `ou-instance/backups/`
   - **Use case:** Regular scheduled backups, pre-upgrade snapshots, disaster recovery preparation

2. **`export-user-count.sh`** - User Statistics
   - Queries MongoDB to retrieve the total number of registered users
   - Exports the count to `user_count.txt` in the `ou-instance/` directory
   - **Use case:** Monitoring user growth, generating usage reports, capacity planning

3. **`export-users-as-json.sh`** - User Data Export
   - Exports complete user records from MongoDB to a JSON file
   - Output saved to `exported_users.json` in the `ou-instance/` directory
   - **Use case:** Data auditing, migration preparation, compliance reporting

**Important Notes:**
- All scripts must be executed from within the `ou-instance/` directory
- The scripts assume the parent directory contains the Overleaf Toolkit installation
- See [`ou-instance/README.md`](./ou-instance/README.md) for detailed usage instructions and examples

### Automatic Backups

You can view the logs for this machine,
```sh
journalctl -u overleaf-backup.service # preferred method
cat /var/log/overleaf-backup.log # or use this 
```

You can view the timer schedule (next backup) here, which also confirms if the backups are running in the background (if 0 listed, no timers are running).

```sh
systemctl list-timers overleaf-backup.timer
```

View the service: /etc/systemd/system/overleaf-backup.service (what to run)
View the timer: /etc/systemd/system/overleaf-backup.timer (when to run it)

#### Remote Logs of Backups
#### Remote Logs of Usage Statistics

### Version Control

**Configuration Tracking:**

Unlike the standard Overleaf Toolkit (which excludes the `config/` directory from version control), this fork **includes** the `config/` directory in Git. This decision provides several benefits:

- **Change History:** All configuration modifications are tracked with commit messages explaining the rationale
- **Audit Trail:** Enables review of when and why specific settings were changed
- **Rollback Capability:** Configuration errors can be quickly reverted to known-good states
- **Team Collaboration:** Multiple administrators can review and discuss configuration changes via pull requests
- **Documentation:** The Git history serves as living documentation of deployment evolution

**Excluded Files:**

The following files remain excluded from version control for operational reasons:
- `cert.pem` - SAML certificate (excluded by organizational preference, though it contains only public key material)
- `data/` - Runtime data directory (large, frequently changing, backed up separately)
- Generated or temporary files as defined in `.gitignore`

### Restoring from Backup

The OUCS Overleaf instance uses a single-server architecture with no remote database or distributed storage. All persistent data—including the MongoDB database, Redis state, user-uploaded files, compiled documents, and project histories—resides in the `data/` directory. This consolidated storage approach simplifies backup and restoration but requires careful attention to data consistency during the restoration process.

**Why Server Shutdown is Required:**

During normal operation, MongoDB maintains in-memory buffers and may have pending write operations. Additionally, Redis keeps transient session data in memory. Attempting to restore the `data/` directory while the server is running could result in:
- Database corruption due to partial writes
- Inconsistent state between memory and disk
- Race conditions between the restoration process and active user sessions
- Loss of in-flight transactions

Therefore, a complete server shutdown is mandatory before any restoration operation.

**What Gets Restored:**

When you restore from a backup, the following components are replaced:
- **MongoDB Database:** All user accounts, projects, metadata, collaboration history, and settings
- **Redis Data:** Session information and cached data (though this is typically ephemeral)
- **User Files:** All LaTeX source files, images, bibliographies, and other project assets
- **Compiled Documents:** PDF outputs and compilation logs
- **Git Bridge Data:** If enabled, all Git repository data for projects

**Prerequisites:**

Before beginning the restoration process, ensure you have:
- A backup archive created by `ou-instance/full-backup.sh` (located in `ou-instance/backups/`)
- Root or sudo access to the server
- Sufficient disk space (at least 2x the size of the backup file to accommodate extraction)
- A maintenance window where service downtime is acceptable (estimated 5-10 minutes)

**Restoration Steps:**

Follow these steps carefully to restore Overleaf from a backup archive. The process involves stopping the server, replacing the data directory, and verifying the restoration.

---

#### Step 1: Backup Current Data (Optional but Strongly Recommended)

Before restoring from an older backup, it's prudent to preserve the current state of the system. This provides a safety net in case the restoration needs to be rolled back.

**To create a backup of the current data:**
```bash
cd /ssd/overleaf/overleaf-toolkit/ou-instance
./full-backup.sh
cd ..
```

**What this does:**
- The `full-backup.sh` script will automatically stop the Overleaf server
- A timestamped backup file will be created in `ou-instance/backups/`
- The script will offer to restart the server (you can decline if proceeding immediately with restoration)

**Important:** If you run the backup script in this step, the server will already be stopped, so you can skip Step 3 and proceed directly to Step 4.

---

#### Step 2: Navigate to the Toolkit Root Directory

All subsequent commands must be executed from the toolkit root directory.

```bash
cd /ssd/overleaf/overleaf-toolkit
```

**Verification:** Running `pwd` should show `/ssd/overleaf/overleaf-toolkit`. Running `ls` should show directories including `bin/`, `config/`, `data/`, and `ou-instance/`.

---

#### Step 3: Stop the Overleaf Server

If the server is still running (because you skipped Step 1 or declined the restart), stop all Overleaf containers now.

```bash
bin/stop
```

**Expected output:** You should see messages indicating that the `sharelatex`, `mongo`, and `redis` containers are stopping. This may take 10-20 seconds.

**Verification:** Run `bin/docker-compose ps` to confirm all containers show a status other than "running" (typically "exited").

**Skip this step if:** You ran `full-backup.sh` in Step 1 and the server is already stopped.

---

#### Step 4: Remove or Move the Current Data Directory

The existing `data/` directory must be removed to make way for the restored version.

**Option A - If you backed up in Step 1 (recommended):**

Since you already have a backup, you can safely remove the current data directory:
```bash
rm -rf data
```

**Option B - If you did NOT backup in Step 1:**

Move the current data directory as a safety precaution:
```bash
mv data data.old-$(date +%s)
```

This creates a timestamped backup (e.g., `data.old-1760394323`) that can be restored if needed. Note that this approach consumes additional disk space.

---

#### Step 5: Extract the Backup Archive

Locate the backup file you want to restore from in `ou-instance/backups/` and extract it.

```bash
tar -xzf ou-instance/backups/data-<timestamp>.tar.gz
```

**Replace `<timestamp>`** with the actual timestamp from your backup filename. For example:
```bash
tar -xzf ou-instance/backups/data-1760394323.tar.gz
```

**What this does:**
- Extracts the compressed archive
- Creates a new `data/` directory in the current location
- Restores all MongoDB databases, Redis data, user files, and project content

**Expected duration:** 1-3 minutes depending on the size of the backup and disk I/O speed.

**Verification:** After extraction, confirm the `data/` directory exists and contains subdirectories like `mongo/`, `redis/`, `overleaf/`, and potentially `git-bridge/`.

---

#### Step 6: Restart the Overleaf Server

Now that the data has been restored, bring the Overleaf services back online.

```bash
bin/up
```

**What happens:**
- Docker Compose will start the `mongo`, `redis`, and `sharelatex` containers
- MongoDB will perform startup checks and recovery (if needed)
- The Overleaf application will initialize and connect to the database

**Expected duration:** 30-60 seconds for all services to become healthy.

**Note:** The first startup after restoration may take slightly longer as MongoDB validates data structures and rebuilds indexes.

---

#### Step 7: Verify the Restoration

Perform the following checks to ensure the restoration was successful:

**A. Check container status:**
```bash
bin/docker-compose ps
```

**Expected output:** All three containers (`mongo`, `redis`, `sharelatex`) should show a status of "running" or "healthy".

**B. Access the web interface:**

Open a web browser and navigate to `https://overleaf.cs.ou.edu`

**Expected result:** The Overleaf login page should appear, and you should be able to authenticate via SAML.

**C. Verify user data:**

Log in with a test account (or your own) and confirm:
- Your projects are visible in the project list
- Opening a project displays the correct files and content
- The project compiles successfully and generates a PDF
- Collaboration features work (if applicable)

**D. Check system logs (optional):**
```bash
bin/logs
```

Look for any error messages or warnings. Normal operation should show routine application logs without critical errors.

---

#### Step 8: Clean Up Old Data (If Applicable)

If you used Option B in Step 4 and created a `data.old-<timestamp>` directory, you can now clean it up after confirming the restoration is successful.

**To remove the old data:**
```bash
rm -rf data.old-<timestamp>
```

**Replace `<timestamp>`** with the actual timestamp from your directory name.

**Warning:** This action is irreversible. Only proceed after thoroughly verifying that the restored system is functioning correctly.

**Alternative:** If disk space is not a concern, you may choose to keep the `data.old-<timestamp>` directory as an additional safety backup for a few days before removing it.

---

**Summary:**

The restoration process typically takes 5-10 minutes of downtime, during which the Overleaf service will be unavailable to users. Plan the restoration during a maintenance window or low-usage period to minimize impact.

**If something goes wrong:**
- If the restored system doesn't work correctly and you used Option B in Step 4, you can revert by stopping the server, removing the `data/` directory, renaming `data.old-<timestamp>` back to `data`, and restarting
- If you created a backup in Step 1, you can restore from that backup following the same procedure
- Check the [Getting Help](#getting-help) section at the bottom of this document for support resources

---

### Notes and Limitations

This section documents important operational considerations, known limitations, and security implications of the current deployment configuration.

#### When to Restart the Server

**Toolkit repository changes do NOT require a server restart.** You can safely modify files in this repository (such as this README, scripts in `ou-instance/`, or documentation) without affecting the running Overleaf instance.

**Server restart is ONLY required when:**
- You modify configuration files in `config/` and want those changes to take effect
- You update the Overleaf version in `config/version`
- You change environment variables in `config/variables.env` or `config/overleaf.rc`
- You modify Docker Compose configuration in `config/docker-compose.override.yml`
- You need to apply certificate changes

**How to restart the server:**
```bash
cd /ssd/overleaf/overleaf-toolkit
bin/stop    # Gracefully stops all containers
bin/up      # Starts containers with current configuration
```

#### SAML Certificate Security

The `cert.pem` file contains only the **public certificate** for SAML authentication and does **not** contain any private keys or sensitive credentials.

#### Security Considerations: Sandboxed Compiles

**Current Configuration:** This instance has **sandboxed compiles disabled** (`SIBLING_CONTAINERS_ENABLED=false`).

**Security Implications:**

When sandboxed compiles are disabled, all LaTeX compilation processes run directly inside the main Overleaf container. This means that users have **full read and write access** to container resources during compilation, including:

- **Filesystem Access:** Users can potentially read any files accessible to the Overleaf process within the container
- **Environment Variables:** Compilation scripts can access environment variables defined in the container
- **Network Access:** LaTeX packages and compilation processes can make network requests from within the container
- **Resource Sharing:** All compilations share the same process namespace and resources

**Why This Configuration is Acceptable for OUCS:**

This deployment is intended for use by **trusted users** within the OU Computer Science department who authenticate via university SSO. In this context:

- All users are vetted members of the university community
- User accountability is maintained through SAML authentication logs
- The risk of malicious activity is significantly lower than in a public multi-tenant environment

**Alternative Configuration:**

For environments requiring stronger isolation (e.g., public instances or multi-tenant scenarios with untrusted users), Overleaf Server Pro supports **sandboxed compiles** (sibling containers), where each LaTeX compilation runs in a separate, isolated Docker container. However:

- Sandboxed compiles require Server Pro (not available in Community Edition)
- This feature introduces additional complexity in deployment and resource management
- The OUCS deployment currently uses Community Edition in a trusted-user environment

**Mitigation Measures:**

- Access is restricted to authenticated OU users via SAML
- Regular security updates are applied (currently running version 5.5.4)
- The instance is deployed on a dedicated server with appropriate network isolation
- User activity can be audited through university SSO logs

**References:**
- [Overleaf Sandboxed Compiles Documentation](./doc/sandboxed-compiles.md)
- [Overleaf Security Release Notes](https://github.com/overleaf/overleaf/wiki/Release-Notes-5.x.x)

#### Current Version and Updates

**Installed Version:** 5.5.4 (as of the last toolkit update)

**Update Policy:**
- Security releases should be applied promptly using `bin/upgrade`
- Always create a backup using `ou-instance/full-backup.sh` before upgrading
- Review the [CHANGELOG](./CHANGELOG.md) before applying updates
- Test upgrades in a development environment when possible

**Checking for Updates:**
```bash
cd /ssd/overleaf/overleaf-toolkit
bin/upgrade
```

The upgrade script will:
1. Check for available toolkit and Overleaf version updates
2. Offer to pull new Docker images
3. Stop the server, apply updates, and restart

#### Known Limitations

**Single-Server Architecture:**
- No high availability or automatic failover
- Server maintenance requires downtime (typically 5-10 minutes)
- All data resides on a single host
- Database is not distributed or replicated

**Backup Strategy:**
- Backups require server shutdown to ensure consistency
- No automated backup scheduling is configured by default
- Consider setting up a cron job to run `ou-instance/full-backup.sh` during off-peak hours

**Email Configuration:**
- Email confirmation is disabled since SAML handles identity verification
- Outbound email functionality may be limited depending on SMTP configuration
- Users may not receive certain notification emails (check `config/variables.env` for email settings)

**Resource Limits:**
- No explicit CPU or memory limits are set on containers
- Large compilation jobs can temporarily impact server performance
- Consider monitoring disk usage in the `data/` directory, especially for MongoDB growth

**Git Integration:**
- Git bridge is available but may not be enabled by default
- Check `config/overleaf.rc` for `GIT_BRIDGE_ENABLED` setting if Git integration is needed

---

# Overleaf Toolkit

This repository contains the Overleaf Toolkit, the standard tools for running a local
instance of [Overleaf](https://overleaf.com). This toolkit will help you to set up and administer both Overleaf Community Edition (free to use, and community supported), and Overleaf Server Pro (commercial, with professional support).

The [Developer wiki](https://github.com/overleaf/overleaf/wiki) contains further documentation on releases, features and other configuration elements.


## Getting Started

Clone this repository locally:

``` sh
git clone https://github.com/oucompsci/overleaf-toolkit.git ./overleaf-toolkit
```

Then follow the [Quick Start Guide](./doc/quick-start-guide.md).


## Documentation

See [Documentation Index](./doc/README.md)

## Getting Help

Users of the free Community Edition should [open an issue on github](https://github.com/overleaf/toolkit/issues). 
Users of Server Pro should contact `support@overleaf.com` for assistance.
In both cases, it is a good idea to include the output of the `bin/doctor` script in your message.