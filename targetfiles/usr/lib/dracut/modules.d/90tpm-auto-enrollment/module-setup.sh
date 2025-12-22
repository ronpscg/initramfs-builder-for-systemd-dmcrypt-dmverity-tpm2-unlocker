#!/bin/bash

#
# Return 0 to include the module
#
check() {
	return 0
}

#
# Define dependencies. The echo here is intentional and required
#
depends() {
	echo systemd crypt
	return 0
}

#
# Do the real work
#
install() {
	# Install some binaries (could easily be done from the dracut command line as well)
	inst_multiple systemd-cryptenroll cryptsetup mktemp
	
	inst "/usr/local/bin/tpm-auto-enrollment.sh"

	inst "/etc/systemd/system/tpm-auto-enrollment.service" "/etc/systemd/system/tpm-auto-enrollment.service"

	# add place for a drop-in file, regardless of the intended /dev/mapper
	inst_dir "/etc/systemd/system/systemd-cryptsetup@.service.d/"

    	# Note the '-' before the path. This is what guarantees fallback to password!
    	# We also pass '%I' so the script knows which device we are talking about.
    	cat > "$initdir/etc/systemd/system/systemd-cryptsetup@.service.d/enroll-hook.conf" <<EOF
[Service]
ExecStartPre=-/usr/local/bin/tpm-auto-enrollment.sh %I
EOF
}

