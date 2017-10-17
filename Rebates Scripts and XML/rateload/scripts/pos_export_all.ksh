#!/bin/ksh

umask 002

CONF_DIR=conf
SCRIPT_NAME="$0"
BASEDIR=
EXIT_CODE=0

function find_basedir {
	typeset basedir=`dirname $0`
	for dir in ../pos_import_export ../clientreg/pos_import_export; do
		if [[ -d "$basedir/$dir" ]]; then
			echo "$basedir/$dir"
			return
		fi
	done
	echo "$basedir/.."
}

# Change to base directory
BASEDIR=`find_basedir`
if ! cd "$BASEDIR" 2>/dev/null; then
	echo "Could not change to $BASEDIR"
	exit 1
fi
BASEDIR=`pwd`

for propertyFile in `ksh -c "cd ${CONF_DIR}; ls -1 export.*.properties"`; do
	echo "Running [$propertyFile]"
	scripts/rbate_KCDY4300.pos_import_export.ksh export "$propertyFile"
	EXIT_CODE=$?
	if [[ $EXIT_CODE -ne 0 ]]; then
		exit $EXIT_CODE
	fi
done

exit $EXIT_CODE
