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

## Project description and design choices

### Operating system choice (Debian vs Rocky Linux)

I chose **Debian** for this project.

**Debian (chosen)**

* **Pros:** very stable; huge package repository; straightforward server setup with `apt`.
* **Cons:** packages can be older than more “bleeding-edge” distributions.

**Rocky Linux (alternative)**

* **Pros:** enterprise-oriented; designed to be compatible with **RHEL** (Red Hat Enterprise Linux); common in professional server environments.
* **Cons:** setup can be more complex for beginners; uses different tooling defaults (e.g., SELinux + firewalld).

### Security framework (AppArmor vs SELinux)

Both AppArmor and SELinux are **MAC** systems (**M**andatory **A**ccess **C**ontrol): an extra security layer that limits what programs can do.

* **AppArmor (Debian):** profile rules based on file paths; usually easier to start with and reason about.
* **SELinux (Rocky/RHEL):** label/context-based rules; very powerful and fine-grained, but can be harder to configure.

### Firewall (UFW vs firewalld)

Both manage Linux firewall rules.

* **UFW (Debian):** simple command-line interface; quick to allow/deny specific ports.
* **firewalld (Rocky/RHEL):** zone-based model; supports runtime vs permanent rules; common in enterprise.

### Virtualization (VirtualBox vs UTM)

Both run virtual machines.

* **VirtualBox (chosen):** cross-platform (Linux/macOS/Windows), widely used in 42, lots of learning resources.
* **UTM (alternative):** popular on macOS (especially Apple Silicon); based on QEMU/Apple virtualization.

### Partitioning and storage

* **LUKS encryption:** protects the VM disk contents if the `.vdi` file is copied/stolen.
* **LVM:** splits disk space into flexible “logical volumes” (e.g., `root`, `swap`) instead of fixed partitions.

### Security policies

* **Password policy:** minimum length/complexity + password aging rules.
* **sudo policy:** limited retries, custom message, logging (including I/O logging), safer defaults.
* **AppArmor:** enabled to add an extra access-control layer.

### User management

* Created a normal user (not root) and placed it into:

  * `sudo` group (admin rights via sudo)
  * `user42` group (project requirement)

### Services installed (minimum)

* `openssh-server` (SSH access)
* `ufw` (firewall)
* `sudo` (admin command execution)
* `cron` (scheduled tasks)
* Other basic monitoring/admin tools 

### The `monitoring.sh` script

### **Source code:**

```
#!/bin/bash

# ARCHITECTURE + KERNEL
arch_indent="				"
arch="$(
  uname -a \
  | tr -d '\r' \
  | fold -sbw 50 \
  | sed '/^[[:space:]]*$/d' \
  | sed "2,\$s/^/$arch_indent/"
)"

# PHYSICAL CPU (sockets) + VCPU
cpu_physical="$(grep "physical id" /proc/cpuinfo 2>/dev/null | sort -u | wc -l)"
# Fallback if "physical id" doesn't exist (rare, but just in case)
if [ "$cpu_physical" -eq 0 ]; then
  cpu_physical="$(lscpu | awk -F: '/Socket\(s\)/ {gsub(/ /,"",$2); print $2}')"
  [ -z "$cpu_physical" ] && cpu_physical=1
fi
vcpu="$(grep -c "^processor" /proc/cpuinfo)"

# RAM (used/total + percent) in MB
ram_total="$(free --mega | awk '$1=="Mem:" {print $2}')"
ram_used="$(free --mega | awk '$1=="Mem:" {print $3}')"
ram_percent="$(free --mega | awk '$1=="Mem:" {printf("%.2f"), $3/$2*100}')"

# DISK (exclude /boot), used in MB, total in Gb, percent
disk_used="$(df -m | awk '$1 ~ "^/dev/" && $6 != "/boot" {u += $3} END {print u}')"
disk_total_gb="$(df -m | awk '$1 ~ "^/dev/" && $6 != "/boot" {t += $2} END {printf("%.1fGb"), t/1024}')"
disk_percent="$(df -m | awk '$1 ~ "^/dev/" && $6 != "/boot" {u += $3; t += $2} END {printf("%d"), (u/t)*100}')"

# CPU LOAD %
cpu_idle="$(vmstat 1 2 | tail -1 | awk '{print $15}')"
cpu_load="$(awk "BEGIN {printf \"%.1f\", 100 - $cpu_idle}")"

# LAST BOOT
last_boot="$(who -b | awk '{print $3 " " $4}')"

# LVM ACTIVE?
if lsblk | grep -q "lvm"; then
  lvm_use="yes"
else
  lvm_use="no"
fi

# TCP CONNECTIONS (ESTABLISHED)
tcp_conn="$(ss -ta | grep ESTAB | wc -l)"

# LOGGED-IN USERS COUNT
user_log="$(users | wc -w)"

# NETWORK: IPv4 + MAC
ip_addr="$(hostname -I | awk '{print $1}')"
mac_addr="$(ip link show | awk '/link\/ether/ {print $2; exit}')"

# SUDO COMMAND COUNT (based on your sudo logfile)
sudo_cmds="$(grep -c "COMMAND=" /var/log/sudo/sudo.log 2>/dev/null || echo 0)"

wall -n <<EOF
	# Architecture:		$arch
	# CPU physical:		$cpu_physical
	# vCPU:			$vcpu
	# Memory Usage: 	${ram_used} / ${ram_total}MB (${ram_percent}%)
	# Disk Usage:		${disk_used} / ${disk_total_gb} (${disk_percent}%)
	# CPU load:		${cpu_load}%
	# Last boot:		$last_boot
	# LVM use:		$lvm_use
	# Connections TCP:	$tcp_conn ESTABLISHED
	# User log:		$user_log
	# Network:		IP $ip_addr ($mac_addr)
	# Sudo:			$sudo_cmds cmd
EOF
```

**Where the script is saved on the VM:**

* `/usr/local/bin/monitoring.sh`

## Instructions

### **How to install/update** `monitoring.sh`:

```
sudo nano /usr/local/bin/monitoring.sh
sudo chown root:root /usr/local/bin/monitoring.sh
sudo chmod 755 /usr/local/bin/monitoring.sh
```

Note: The “sudo command count” only works if `sudo` is configured to write logs to `/var/log/sudo/sudo.log` (so the script can count `COMMAND=` lines). To set up sudo logging:

1. Create the log directory:

```
sudo mkdir -p /var/log/sudo
sudo chown root:root /var/log/sudo
sudo chmod 700 /var/log/sudo
```

2. Create/edit the sudo config file *safely* with `visudo`:

```
sudo visudo -f /etc/sudoers.d/born2beroot
```

3. Add these lines:

```
Defaults logfile="/var/log/sudo/sudo.log"
Defaults log_input, log_output
Defaults iolog_dir="/var/log/sudo"
```

4. Fix permissions (sudoers files must be read-only):

```
sudo chmod 0440 /etc/sudoers.d/born2beroot
sudo chown root:root /etc/sudoers.d/born2beroot
```

5. Validate:

```
sudo visudo -c
```

After this, your `monitoring.sh` sudo counter should work, and sudo will also record input/output logs under `/var/log/sudo/`.

### How to run `monitoring.sh` manually

On the VM:

```bash
sudo /usr/local/bin/monitoring.sh
```

You should see a broadcast message on all logged-in terminals.

### How to make `monitoring.sh` run automatically (boot + every 10 minutes)

This is handled by **cron** (the Linux scheduler).

1. Edit root’s crontab:

```
sudo crontab -e
```

2. Add these lines:

```cron
@reboot /usr/local/bin/monitoring.sh
*/10 * * * * /usr/local/bin/monitoring.sh
```

`@reboot` cron jobs run as soon as the **cron service** starts after boot, which is often **before you’ve logged in**. And since `wall` broadcasts the message to the terminals of users who are logged in **at that moment**, it’s normal to:

* reboot → log in → **not** see the startup `wall` message, and then
* only see the next message at the next 10 minute interval.

To see the broadcast message right after log in, you can trigger the script on console (TTY) login via PAM:

1. Edit:

```bash
sudo nano /etc/pam.d/login
```

2. Add this line at the end:

```text
session optional pam_exec.so type=open_session seteuid /usr/local/bin/monitoring.sh
```

This runs `monitoring.sh` automatically whenever a user successfully logs in on the console (TTY). With `seteuid`, it runs as the user who is logging in (not root). If you want it to run as root, remove `seteuid` (but understand the security implications), or keep the cron-based root job for the “official” requirement.

### How to interrupt `monitoring.sh` without modifying the script

You can interrupt the scheduled broadcasts in either of these ways:

**Option 1: Stop cron (pause all cron jobs)**

```bash
sudo systemctl stop cron
# ...confirm no more broadcasts...
sudo systemctl start cron
```

**Option 2: Comment out the cron line (pause only this script)**

1. Open root’s crontab:

```bash
sudo crontab -e
```

2. Add a `#` at the start of the `*/10` line:

```cron
#*/10 * * * * /usr/local/bin/monitoring.sh
```

3. Save and exit. To re-enable it later, remove the `#`.

### Quick verification commands

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

## Resources

### Classic references

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

All commands and configuration changes were verified manually on the VM, and the final configuration was tested using an evaluation checklist.
