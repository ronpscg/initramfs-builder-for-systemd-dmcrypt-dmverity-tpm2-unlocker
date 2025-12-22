#!/bin/sh
#
# This script takes care of autoenrollment of TPM, and is meant to be run in an initramfs, that may be a bit limited in tools.
# It is also designed to be run before udev has set up the respective disk devices (/dev/disk/by-...). HOWEVER - you don't want to do this
# in a systemd based system, as it is not too easy to avoid race conditions between this and  systemd-cryptsetup@<luks name as per cmdline>.service (e.g. systemd-cryptsetup@dmcryptdevice-luks.service). There are several ways to overcome it. Some would yield the latter service "unfound" in the full rootfs, and so the recommended approach is to run this script in a drop-in file for the latter service, running at it ExecStartPre=... hook.
#
# e.g., do something like creating a file at the target's initramfs like:
# /etc/systemd/system/systemd-cryptsetup@.service.d/tpm-auto-enrolling-hook.conf
# and then, add to the [Service] section
# ExecStartPre=-/usr/local/bin/tpm-auto-enrollment.sh %I
# (%I doesn't really matter since we go over all the names)
#
# Otherwise, the file is almost identical to the  one that was done to do enrollment only in rootfs. We deliberately presented these two options
#
set -euo pipefail

: ${tpm_autoenrollment=""}
: ${tpm_autoenrollment_password=""}
: ${tpm_autoenrollment_keyfile=""}
: ${tpm_autoenrollment_removepasswordslot=false}
: ${tpm_autoenrollment_removeprevioustpmenrollments=false}
: ${tpm_autoenrollment_pcrs="7"} # you can provide a ',' delimited list of pcrs to enroll. The default is otherwise systemd-cryptenroll's default, i.e. 7.


# Print to console (visible during boot)
console() {
	echo -e "$@" > /dev/console
	echo -e "$@" >&2 # redundant, but to keep it in the journalctl status as well
}

setup_password_file_if_needed() {
	if command -v mktemp >& /dev/null ; then 
		PASS_FILE=$(mktemp)
	else
		f=/tmp/foobarbazbla ;  echo -ne > $f ; echo $f ; chmod 0600 $f ; PASS_FILE=$f  # good for our purposes, and overcomes lack of 'touch'
	fi

	echo -n "$tpm_autoenrollment_password" > "$PASS_FILE"
	TPM2_ENROLL_CMD="$TPM2_ENROLL_CMD --unlock-key-file=$PASS_FILE"
	
}

teardown_password_file_if_needed() {
	if [ -f "$PASS_FILE" ] ; then
		rm -f "$PASS_FILE" # can even shred, but no one should care unless the attacker has both crazy timing and device presence. However, if we delete the password slot it's perfectly safe unless an attacker has access before first provisioning of a device and the password is identical in all devices (we could make a different password per device but then we would have to manage it
	fi
}

opportunisticly_wait_for_udev_disk_discoveries() {
	MAX_RETRIES=10
	for ((i=0; i<MAX_RETRIES; i++)); do
		if [ -e "$DEVICE_SYMLINK" ]; then
			console "Device found: $LUKS_UUID"
			break
		fi
		console "Waiting for device $LUKS_UUID to appear... (attempt $i/$MAX_RETRIES)"
		sleep 1
	done

	if [ ! -e "$DEVICE_SYMLINK" ]; then
		console "\e[31mERROR: Device $LUKS_UUID did not appear after $MAX_RETRIES seconds.\e[0m"
		exit 1 # give up on all devices in this case...
	fi
}

#
# This can be done also in an initramfs if you have systemd-cryptenroll there. It is uncommon to have it there though (but very possible and not hard to get...)
#
do_systemd_cryptenroll_tpm_enrollment() {
	console ""
	console "$0: \e[33mTPM2 LUKS auto-provisioning starting\e[0m"
	console ""

	CMDLINE=$(cat /proc/cmdline)

	# Extract all rd.luks.name=UUID=name entries
	mapfile -t LUKS_ENTRIES < <(echo "$CMDLINE" | grep -o 'rd\.luks\.name=[^ ]*' || true)

	if [[ ${#LUKS_ENTRIES[@]} -eq 0 ]]; then
		console "No rd.luks.name entries found in kernel command line."
		exit 0
	fi

	for entry in "${LUKS_ENTRIES[@]}"; do
		# rd.luks.name=<UUID>=<name>
		RAW="${entry#rd.luks.name=}"
		LUKS_UUID="${RAW%%=*}"
		MAPPED_NAME="${RAW#*=}"

		console "Processing LUKS UUID: $LUKS_UUID (mapped name: $MAPPED_NAME)"

		DEVICE_SYMLINK="/dev/disk/by-uuid/$LUKS_UUID"

		if ! opportunisticly_wait_for_udev_disk_discoveries ; then
			: # do nothing - unless you don't mind failing the system, or want to fail it if you cannot autounlock, and then exit 1
		fi

		if [[ ! -e "$DEVICE_SYMLINK" ]]; then
			console "  ERROR: Device not found: $DEVICE_SYMLINK"
			continue
		fi

		REAL_DEVICE=$(readlink -f "$DEVICE_SYMLINK")
		console "  Resolved device: $REAL_DEVICE"

		console "  Checking for existing TPM2 keyslots..."
	
		TPM2_ENROLL_CMD="$CRYPTENROLL --tpm2-device=auto $REAL_DEVICE"
                if $CRYPTSETUP luksDump $REAL_DEVICE | grep -q tpm2 ; then
			console "TPM device is already enrolled"
			if [ "$tpm_autoenrollment_removeprevioustpmenrollments" = "true" ] ; then
				# It's a good practice to do this at a first enrollment. Do not do this at subsequent enrollments
				TPM2_ENROLL_CMD="$TPM2_ENROLL_CMD --wipe-slot=tpm2"
				console "Will wipe the previous TPM2 slots"
			else
				continue
			fi
		fi

		set +eou pipefail	# manual error detection to be able to remove the password file if needs be (although it will be in tmpfs anyway...)
		setup_password_file_if_needed

		TPM2_ENROLL_CMD="$TPM2_ENROLL_CMD --tpm2-pcrs=$tpm_autoenrollment_pcrs"
		if [ "$tpm_autoenrollment_removepasswordslot" = "true" ] ; then
			# Do this only if you want to completely get rid of the password and understand the risks. It may leave your encrypted device unrecoverable!
			TPM2_ENROLL_CMD="$TPM2_ENROLL_CMD --wipe-slot=0"
		fi
		
		console "\e[33mEnrolling your TPM2 device for passwordless disk encryption\e[0m"
		if $TPM2_ENROLL_CMD ; then
			console "\[e32mEnrolling succeeded\e[0m"
		else
			console "\e[31mEnrolling failed\e[0m"
			rc=1
		fi
		teardown_password_file_if_needed
		set -euo pipefail	# restore auto error detection
	done

	return $rc
}

parse_kernel_cmdline() {
	# This block can be used in either initramfs or rootfs
	for c in $(cat /proc/cmdline) ; do
		case $c in
			tpm.autoenrollment=*)
				echo $c
				tpm_autoenrollment=${c#*=}
				;;
			tpm.autoenrollment.password=*)
				tpm_autoenrollment_password=${c#*=}
				;;
			tpm.autoenrollment.keyfile=*)
				# although it is ignored now (see notes in the respective GRUB config for the secboot-ovmf-x86_64 project
				tpm_autoenrollment_keyfile=${c#*=}
				;;
			tpm.autoenrollment.pcrs=*)
				tpm_autoenrollment_pcrs=${c#*=}
				;;
			tpm.autoenrollment.removepasswordslot)
				# This may make your device unrecoverable. On the other hand, it is best for security (or device management, unless you put a key/password per device)
				tpm_autoenrollment_removepasswordslot=true
				;;
			tpm.autoenrollment.removeprevioustpmenrollments)
				tpm_autoenrollment_removeprevioustpmenrollments=true
				;;
		esac
	done
}

#
# Your initramfs may not have some of the tools, and there is no real point in installing them. So we will use suiting alternatives.
#
set_expected_tools() {
	CRYPTSETUP=$(command -v cryptsetup) || CRYPTSETUP=$(command -v systemd-cryptsetup) || { console "\e[41mCould not find a matching cryptsetup utility. Please fix your initramfs\e[0m" ; return 1 ; }
	CRYPTENROLL=$(command -v systemd-cryptenroll) || { console "\e[41mCould not find the systemd-cryptenroll utility. Please fix your initramfs\e[0m" ; return 1 ; }
}

main() {
	console "Running: $0 $@ in initramfs"
	parse_kernel_cmdline
	if [ "$tpm_autoenrollment" = "initramfs" -o "$tpm_autoenrollment" = "all" ] ; then
		set_expected_tools || exit 0 # let things proceed. the user will enter a password and live with it (could exit 1 alternatively)
		if do_systemd_cryptenroll_tpm_enrollment ; then
			console "\e[31m: $0: successfully enrolled\e[0m"
		fi
	else
		: # nothing to do here
	fi
}

main $@
