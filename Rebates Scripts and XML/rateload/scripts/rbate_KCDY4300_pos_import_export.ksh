#!/bin/ksh
#------------------------------------------------------------------------------
# Script: pos_import_export.ksh
# Description:
#   This script runs the com.caremark.gdx.rateload.ImportMain or
#   com.caremark.gdx.rateload.ExportMain java programs. 
#
#   The import program loads rate, pharmacy exclusions and state exclusion
#   files into oracle tables.  It will send out emails when there are errors.
#   Error files will also be ftp'd to business.
#
#   The export program creates an export file for rate, pharmacy exlusion or
#   state exclusion data, for a given adjudication engine.  The propery file
#   used will tell what file type to create and what platform the file is for.
#
#   This program takes 2 parameters:
#     param 1 - Should be import or export
#     param 2 - Is the property file used for configuration.
#          (Each file type and adjudication engine will have a separate
#            property file) 
#
#  Author: Bryan Castillo
#
#
#
#	Change Log: 
#
#		1/8/09		QCPI898				Added -Xmx200m param to java execution to allocation larger
#                           memory slice when running to accomodate larger input files.        
#
#------------------------------------------------------------------------------

umask 002

SCRIPT_NAME="$0"
LOG_DIR=logs
LIB_DIR=lib
CONF_DIR=conf
INCOMING_DIR=data/incoming
BASEDIR=
CLASSPATH=
JAVA=
MODE=
FILE=
CLASS=
EXIT_CODE=0

# Take ownership of files in incoming
# If you have write permissions to a directory
# and read permissions on a file, but not write.
# you can copy the file and then overlay the original file.
# Even if you can't write to a file, but you can write to
# the directory you can delete the file.
# This is done because the user that FTP's files here
# can't set the permissions to have write access to the group.
function take_ownership {
	typeset incoming_dir=$1
	for file in $(ls $incoming_dir/*); do
		if [[ -f "$file" ]]; then
			echo "Taking ownership of $file"
			tmp_file="${file}.tmp~"
			cp "$file" "$tmp_file"
			if ! mv -f "$tmp_file" "$file"; then
				rm -f "$tmp_file"
			else
				chmod 666 "$file"
			fi
		fi
	done
}

# Get all jars and zips under LIB_DIR and the CONF_DIR as a path
function get_classpath {
	printf "$CONF_DIR"
	find "$LIB_DIR" \( -name '*.jar' -o -name '*.zip' \) -exec printf ":%s" {} \;
}

# Get the java command 
function get_java {
	typeset _java
	if [[ -n "$JAVA_HOME" && -x "${JAVA_HOME}/bin/java" ]]; then
		_java="${JAVA_HOME}/bin/java"
	else
		_java=`which java 2>/dev/null`
	fi
	if [[ ! -x "$_java" ]]; then
		echo "java command not found"
		exit 1
	fi
	echo $_java
}

# Waits for the incoming directory to stabilize
# for 30 seconds before proceeding.
# This is done so the java process is not run
# while a file is still in the process of being 
# uploaded via ftp.
function wait_for_incoming_stabilization {
	typeset check_interval=30
	typeset result=""
	typeset last_result=""
	while true; do
		result=`ls -l $INCOMING_DIR 2>/dev/null | sum`
		if [[ "$result" = "$last_result" ]]; then
			return
		fi
		echo `date +"[%H:%M:%S]"`" Waiting for file stabilization"
		sleep $check_interval
		last_result="$result"
	done
}

function show_usage {
	echo "Usage: ${SCRIPT_NAME} <import|export> <property file>"
}

function find_basedir {
	typeset basedir=`dirname ${SCRIPT_NAME}`
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

take_ownership "$BASEDIR/data/incoming"

# Get environment specific settings
if [[ -e "$CONF_DIR/env.ksh" ]]; then
	. "$CONF_DIR/env.ksh" 
fi

# Create log directory
if [[ ! -d "$LOG_DIR" ]]; then
	mkdir -p "$LOG_DIR" 2>&1
	if [[ ! -d "$LOG_DIR" ]]; then
		echo "Could not create log directory $LOG_DIR"
		exit 1
	fi
fi

export CLASSPATH=`get_classpath`
JAVA=`get_java`

if [[ $# -ne 2 ]]; then
	show_usage
	exit 1
fi

MODE=`echo $1 | tr '[A-Z]' '[a-z]'`
FILE="$2"

# Remove the first 2 parameters
shift
shift

case "$MODE" in
	import)
		CLASS="com.caremark.gdx.rateload.ImportMain"
		;;
	export)
		CLASS="com.caremark.gdx.rateload.ExportMain"
		;;
	*)
		show_usage
		exit 1
esac

echo "---------------------------------------------------"
echo "Starting: "`date` 
echo "---------------------------------------------------"
echo "Host    = "`hostname`
echo "Basedir = $BASEDIR"
echo "Mode    = $MODE"
echo "Config  = $FILE"
echo "Classpath:"
echo "$CLASSPATH" | awk -F':' '{
	for (i=1; i<=NF; i++) {
		printf("    %s\n", $i);
	}
}'	
echo
$JAVA -version 2>&1
echo "---------------------------------------------------"

# Make sure files aren't growing
if [[ "$MODE" = "import" ]]; then
	wait_for_incoming_stabilization
	echo "---------------------------------------------------"
fi

"$JAVA" -Xmx200m $CLASS "$FILE" "$@"
EXIT_CODE=$?
echo "---------------------------------------------------"
echo "Ended: "`date`
echo "Exit Code: $EXIT_CODE"
echo "---------------------------------------------------"

exit $EXIT_CODE


