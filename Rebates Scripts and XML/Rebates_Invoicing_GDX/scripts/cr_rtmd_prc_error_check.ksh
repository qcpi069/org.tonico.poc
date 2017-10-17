#!/bin/ksh
#------------------------------------------------------------------------------
# Script: pos_error_check.ksh
# Description:
#   This script runs the com.caremark.gdx.rateload.ErrorWatchMain java
#   program.  This program looks at a directory for error files.
#   If those error files exists:
#      1) An email is sent out saying errors were found.
#      2) The error files are ftp'd to business.
#      3) The error files are  zipped and put in the error directory.
#
#   This program takes 1 parameter which is the name of a properties file.
#   This file should be in the conf directory.  The file contains
#   the configuration for the java program.
#   It has email settings, file patterns, etc...
#
#  Author: Bryan Castillo
#------------------------------------------------------------------------------

umask 002

SCRIPT_NAME="$0"
LOG_DIR=logs
LIB_DIR=lib
CONF_DIR=conf
BASEDIR=
CLASSPATH=
JAVA=
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

function find_basedir {
	typeset basedir=`dirname $SCRIPT_NAME`
	for dir in ../java/clientreg ../java; do
		if [[ -d "$basedir/$dir" ]]; then
			echo "$basedir/$dir"
			return
		fi
	done
	echo "$basedir/.."
}

function show_usage {
	echo "Usage: $SCRIPT_NAME <property file>"
}

function remove_empty_errors {
	for errfile in $(ls -d data/incoming/ERROR* 2>/dev/null); do
		if [[ -f "$errfile" ]]; then
			errcnt=$(egrep -v -c '^T' "$errfile")
			if [[ $errcnt = 0 ]]; then
				rm -f "$errfile"
			fi
		fi
	done
}

# Change to base directory
BASEDIR=`find_basedir`
if ! cd "$BASEDIR" 2>/dev/null; then
	echo "Could not change to $BASEDIR"
	exit 1
fi
BASEDIR=`pwd`

take_ownership "$BASEDIR/data/incoming"
remove_empty_errors

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

FILE="errorwatch.properties"
if [[ ! -z "$1" ]]; then
	FILE="$1"
fi

CLASS="com.caremark.gdx.rateload.ErrorWatchMain"

echo "---------------------------------------------------"
echo "Starting: "`date` 
echo "---------------------------------------------------"
echo "Host    = "`hostname`
echo "Basedir = $BASEDIR"
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
"$JAVA" $CLASS "$FILE"
EXIT_CODE=$?
echo "---------------------------------------------------"
echo "Ended: "`date`
echo "Exit Code: $EXIT_CODE"
echo "---------------------------------------------------"

exit $EXIT_CODE

