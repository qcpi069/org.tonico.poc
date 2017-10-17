#!/bin/ksh
#set -x
#------------------------------------------------------------------------------
# Script: rbate_reg_batch.ksh
# Description:
#   This script runs a RebateRegistration Batch job

#   This program takes 1 parameters:
#     param 1 - the name of the Main class for the batch job
#
#  Author: IS99601
#
#------------------------------------------------------------------------------

umask 002

SCRIPT_NAME="$0"
MAIN_CLASS_NAME="$1"
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
	echo "Usage: ${SCRIPT_NAME} main_class_name"
}

function find_basedir {
	typeset basedir=`dirname ${SCRIPT_NAME}`
	for dir in ../rebate_registration ../java/clientreg; do
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

echo "BASEDIR: " $BASEDIR
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

echo "CLASSPATH: " $CLASSPATH
JAVA=`get_java`

if [[ $# -lt 1 ]]; then
	show_usage
	exit 1
fi


CLASS="com.caremark.rebates.registration.batch.main."$@


echo "---------------------------------------------------"
echo "Starting: "`date` 
echo "---------------------------------------------------"
echo "Host    = "`hostname`
echo "Basedir = $BASEDIR"
echo "Class    = $CLASS"
echo "Classpath:"
echo "$CLASSPATH" | awk -F':' '{
	for (i=1; i<=NF; i++) {
		printf("    %s\n", $i);
	}
}'	
echo
$JAVA -version 2>&1
echo "---------------------------------------------------"


#wait_for_incoming_stabilization


#"$JAVA" $CLASS
"$JAVA" -Xmx512m $CLASS
EXIT_CODE=$?
echo "---------------------------------------------------"
echo "Ended: "`date`
echo "Exit Code: $EXIT_CODE"
echo "---------------------------------------------------"
print "return_code =" $EXIT_CODE
exit $EXIT_CODE


