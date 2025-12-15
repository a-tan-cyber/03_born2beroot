*This project has been created as part of the 42 curriculum by amtan.*

# Born2beroot

## Description

Born2beroot is a system-administration project where you build a **minimal, secure Linux server** inside a virtual machine (VM). The goal is to practice the real basics of running a server: disk layout, users/groups, secure remote access, firewall rules, logging, and automated monitoring.

In my setup, the server is **Debian** running in **VirtualBox**, with:

* **Encrypted disk** (LUKS) + **LVM** (Logical Volume Manager)
* **SSH** (Secure Shell) on port **4242**
* **UFW** (Uncomplicated Firewall) enabled
* **AppArmor** enabled at boot
* A `monitoring.sh` Bash script that broadcasts system status at boot and every 10 minutes (via `cron` + `wall`)

## Project setup and design choices

### Operating system choice: Debian

I chose **Debian** because it is stable, widely used on servers, and has a large community and package ecosystem.

**Pros**

* Very stable and conservative updates (good for servers)
* Huge package repository with `apt`
* Strong community documentation

**Cons**

* Software versions can be older than “bleeding-edge” distros
* Some defaults can be minimal (you configure more yourself)

### Partitioning and storage

* **LUKS encryption**: protects data on disk if the VM disk file is copied/stolen.
* **LVM**: manages disk space as flexible “logical volumes” (e.g., `root`, `swap`) instead of fixed partitions.

### Security policies

* **Password policy**: minimum length/complexity + password aging rules.
* **sudo policy**: limited retries, custom message, logging (including I/O logging), and safer defaults.
* **AppArmor**: enabled to add an extra layer of access control.

### User management

* Created a normal user (not root) and placed it into:

  * `sudo` group (admin rights via sudo)
  * `user42` group (project requirement)

### Services installed (minimal)

* `openssh-server` (SSH access)
* `ufw` (firewall)
* `sudo` (privileged command execution)
* `cron` (scheduled tasks)
* Tools for auditing/monitoring (e.g., `lvm2`, `net-tools`/`iproute2`, etc.)

## Instructions

### What’s in this repository

Typical files (may vary depending on how you organized your repo):

* `monitoring.sh`: the monitoring script (installed on the VM at `/usr/local/bin/monitoring.sh`)
* `signature.txt`: SHA1 signature of the VM disk file (required for submission)
* Optional notes/config extracts used during setup

### How to run the monitoring script manually

On the VM:

```bash
sudo /usr/local/bin/monitoring.sh
```

You should see a broadcast message on all logged-in terminals.

### How it runs automatically (boot + every 10 minutes)

This is handled by **cron** (the Linux scheduler). Root’s crontab typically contains:

```cron
@reboot sleep 30 && /usr/local/bin/monitoring.sh
*/10 * * * * /usr/local/bin/monitoring.sh
```

Notes:

* `sleep 30` helps ensure you can actually *see* the startup broadcast after logging in.
* The script uses `wall -n` to broadcast without showing an extra banner.

### How to “interrupt it without modifying it” (for evaluation)

During peer review, you can stop the schedule by stopping cron (then start it again):

```bash
sudo systemctl stop cron
# ...confirm no more broadcasts...
sudo systemctl start cron
```

### Quick verification commands (useful for defense)

Disk encryption + LVM:

```bash
lsblk -f
sudo pvs && sudo vgs && sudo lvs
```

Firewall:

```bash
sudo ufw status verbose
sudo ss -tulpn
```

SSH:

```bash
sudo ss -tulpn | grep ssh
sudo grep -E '^(Port|PermitRootLogin)' /etc/ssh/sshd_config
```

AppArmor:

```bash
systemctl status apparmor
sudo aa-status
```

## Required comparisons (high-level)

### Debian vs Rocky Linux

* **Debian**: community-driven, stability-focused, uses `apt` and `.deb` packages.
* **Rocky Linux**: enterprise-focused, designed to be compatible with RHEL (Red Hat Enterprise Linux), uses `dnf` and `.rpm` packages.

### AppArmor vs SELinux

Both are **MAC** systems (**M**andatory **A**ccess **C**ontrol) that restrict what programs can do.

* **AppArmor**: “profile” rules based on **paths** (often simpler to start with).
* **SELinux**: rules based on **labels/contexts** (very powerful and granular, common in enterprise environments).

### UFW vs firewalld

Both manage firewall rules.

* **UFW**: simple CLI, often used on Debian/Ubuntu; good for straightforward rule sets.
* **firewalld**: zone-based, supports runtime vs permanent rules; common on RHEL/Rocky.

### VirtualBox vs UTM

Both run virtual machines.

* **VirtualBox**: cross-platform (Linux/macOS/Windows), widely used in 42, lots of tutorials.
* **UTM**: macOS-focused VM app based on QEMU/Apple virtualization frameworks; popular on Apple Silicon.

## Resources

### Classic references

(Links are provided as plain URLs to keep the README portable.)

Debian

```text
Debian Wiki (Releases): https://wiki.debian.org/DebianReleases
Debian Security FAQ: https://www.debian.org/security/faq
```

Rocky Linux

```text
Rocky Linux (about): https://rockylinux.org/
Rocky Linux documentation: https://docs.rockylinux.org/
```

AppArmor / SELinux

```text
Red Hat overview (AppArmor vs SELinux): https://www.redhat.com/en/blog/apparmor-selinux-isolation
```

UFW / firewalld

```text
Debian Wiki (ufw): https://wiki.debian.org/Uncomplicated_Firewall_%28ufw%29
firewalld documentation: https://firewalld.org/documentation/
RHEL firewalld guide: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/configuring_and_managing_networking/using-and-configuring-firewalld_configuring-and-managing-networking
```

Virtualization

```text
VirtualBox Manual (Virtual Networking): https://www.virtualbox.org/manual/ch06.html
UTM docs: https://docs.getutm.app/
```

### How AI was used

AI (ChatGPT) was used as a study/tooling assistant to:

* Translate the subject requirements into a step-by-step setup plan.
* Explain Linux concepts (LUKS, LVM, AppArmor, UFW, SSH, cron) in beginner-friendly language.
* Draft and iterate on the `monitoring.sh` script and formatting.
* Provide troubleshooting checklists (e.g., why a cron `@reboot` job didn’t show a `wall` message).

All commands and configuration changes were **verified manually on the VM**, and the final configuration was tested using the project’s evaluation checklist.
