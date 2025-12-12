#!/bin/bash

# ARCHITECTURE + KERNEL
arch_wrapped="$(uname -a | fold -s -w 70)"
arch_indent="				" 
arch="$(printf '%s\n' "$arch_wrapped" | sed "2,\$s/^/$arch_indent/")"

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

wall <<EOF
	# Architecture:		$arch
	# CPU physical:		$cpu_physical
	# vCPU:			$vcpu
	# Memory Usage: 	${ram_used}/${ram_total}MB (${ram_percent}%)
	# Disk Usage:		${disk_used}/${disk_total_gb} (${disk_percent}%)
	# CPU load:		${cpu_load}%
	# Last boot:		$last_boot
	# LVM use:		$lvm_use
	# Connections TCP:	$tcp_conn ESTABLISHED
	# User log:		$user_log
	# Network:		IP $ip_addr ($mac_addr)
	# Sudo:			$sudo_cmds cmd
EOF
