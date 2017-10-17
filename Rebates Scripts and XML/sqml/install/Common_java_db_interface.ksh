#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : Common_Java_DB_Interface.ksh
#
# Description   : Runs database commands from an xml file
#
# Parameters    : The last parameter is the XML file.
#                 The parameters before the XML file are options used by 
#                 the java program of the form:
#                   --<option name> <option value>
#                 The java program will use these as named properties
#                 which may be substituted into SQL, etc...
#
# Output        : Log file as $OUTPUT_PATH/<base xml file name>.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 08-31-2004  B.Castillo Initial Creation.
#
#-------------------------------------------------------------------------#

EXIT_CODE=0
LOG_FILE=
XML_FILE=
SCRIPT_NAME="$0"
BASE_DIR=
CLASSPATH=
JAVACMD=
DEBUG=0
RET_CODE=0
APP_NAME=$(basename $0 | sed -e 's/.ksh$//')
APP_DIR=
BASE_DIR=$(dirname $SCRIPT_NAME)"/.."
BASE_DIR=$(ksh -c "cd $BASE_DIR; pwd")
SCRIPT_DIR=$(dirname $SCRIPT_NAME)
SYSTEM_ENV=
REGION_ID=
JAVA_EMAIL_ADDRESS='GDXITD@caremark.com'
#JAVA_EMAIL_ADDRESS='bryan.castillo@caremark.com'

#-------------------------------------------------------------------------#
# Find the proper environment script
function init_hostenv {
	if [[ -f "${SCRIPT_DIR}/Common_GDX_Environment.ksh" ]]; then
		SYSTEM_ENV=GDX
		. "${SCRIPT_DIR}/Common_GDX_Environment.ksh"
	elif [[ -f "${SCRIPT_DIR}/rebates_env.ksh" ]]; then
		SYSTEM_ENV=REBATES
		. "${SCRIPT_DIR}/rebates_env.ksh"
	else
		logmsg "Unknown environemnt"
		exit 1
	fi

	# What is the REGION and is it QA
	if [[ "$(echo $QA_REGION | tr 'a-z' 'A-Z')" = "TRUE" ]]; then
		REGION_ID="$REGION - QA"
	else
		REGION_ID="$REGION"
	fi 
}

#-------------------------------------------------------------------------#
# Find the applications directory containing jar files etc..
function find_appdir {
	if [[ ! -d "${BASE_DIR}/java/${APP_NAME}" ]]; then
		logmsg "Couldn't find the application directory"
		exit 1
	fi
	APP_DIR="${BASE_DIR}/java/${APP_NAME}"
}

#-------------------------------------------------------------------------#
# Finds the java command
function find_java {

	# Is JAVA_HOME already set?
	if [[ -n "$JAVA_HOME" ]]; then
		if [[ -x "$JAVA_HOME/bin/java" ]]; then
			export JAVA_HOME	
			export JAVACMD="$JAVA_HOME/bin/java"
			return
		fi
	fi

	# Look for common directories
	typeset jdkdirs='
		/usr/java1.4
		/usr/java14
		/usr/java131
	'
	typeset jdkdir
	for jdkdir in $jdkdirs; do
		if [[ -d "$jdkdir" ]] && [[ -x "$jdkdir/bin/java" ]]; then
			export JAVA_HOME="$jdkdir"
			export JAVACMD="$JAVA_HOME/bin/java"
			return
		fi
	done

	# Is java in the path
	export JAVACMD=$(which java 2>/dev/null) 
	if [[ -x "$JAVACMD" ]]; then
		return
	fi

	# No java
	logmsg "Java was not found on this sytem"
	exit 1
}

#-------------------------------------------------------------------------#
# Builds a classpath to be used by java 
function get_classpath {
	# The find command is used to recursively add all jar and zip files
	# to the class path.
	if [[ -z "$CLASSPATH" ]]; then
		CLASSPATH=$(printf "$APP_DIR/conf:$BASE_DIR/xml:$BASE_DIR")
	else
		CLASSPATH=${CLASSPATH}:$(printf "$APP_DIR/conf:$BASE_DIR/xml:$BASE_DIR")
	fi
	CLASSPATH="$CLASSPATH"`find "$APP_DIR/lib" \( -name '*.jar' -o -name '*.zip' \) -exec printf ":%s" {} \;`
	export CLASSPATH
}

#-------------------------------------------------------------------------#
# Logs a message with timestamp
function logmsg {
	echo $(date +'[%H:%M:%S] ')"$@"
}

#-------------------------------------------------------------------------#
# Exit routine
function exit_script {
	EXIT_CODE=$1
	# default to an error status if one isn't specified
	if [[ -z $EXIT_CODE ]]; then
		EXIT_CODE=1
	fi
	logmsg "Completed [$SCRIPT_NAME] EXIT_CODE=$EXIT_CODE"
	ARCH_FILE="$LOG_ARCH_PATH/"$(basename $LOG_FILE)"."$(date +"%Y%j%H%M")
	
	# close stdout and stderr which will close the log file
	exec 1>&-
	exec 2>&-
	
	if [[ $EXIT_CODE -eq 0 ]]; then
		mv -f "$LOG_FILE" "$ARCH_FILE"
	else
		cp "$LOG_FILE" "$ARCH_FILE"
	fi
	exit $EXIT_CODE
}

#-------------------------------------------------------------------------#
# Sets the variable LOG_FILE and redirects stdout and stderr to the
# LOG_FILE (the log file will be cleared)
function set_log_file {
	# remove the previous log file if 1 was set
	if [[ -n $LOG_FILE ]]; then
		rm -f "$LOG_FILE"
	fi
	
	LOG_FILE=$1
	rm -f $LOG_FILE
	
	# Redirect stdout and stderr to the log file
	exec 1> "$LOG_FILE"
	exec 2>&1
}

#-------------------------------------------------------------------------#
# MAIN

init_hostenv
set_log_file "${OUTPUT_PATH}/"$(basename $SCRIPT_NAME | sed -e 's/.ksh$/.log/')
find_appdir

# Check arguments
if [[ $# -lt 1 ]]; then
	logmsg "Usage: $0 <xml file> [options]"
	exit_script 1
fi

# Get the xml file and use that file for the log file name
# The xml file is the last parameter
# There has got to be a better way to get the last parameter.
eval 'XML_FILE=$'$#
set_log_file "$OUTPUT_PATH/"$(basename $XML_FILE | sed -e 's/.xml$/.log/')

# Setup java environment
get_classpath
find_java

# Execute the Java program
logmsg "----------------------------------------------------------------"
logmsg "Classpath:"
for cp in $(echo "$CLASSPATH" | tr ':' '\n'); do
	logmsg "  $cp"
done
logmsg "$($JAVACMD -version 2>&1)"
logmsg "----------------------------------------------------------------"


logmsg "$JAVACMD" "-Dlogfile=${LOG_FILE}" com.caremark.gdx.sqml.SqlXmlScript --email_address "$JAVA_EMAIL_ADDRESS" --region "$REGION_ID" "$@" 
"$JAVACMD" "-Dlogfile=${LOG_FILE}" com.caremark.gdx.sqml.SqlXmlScript --email_address "$JAVA_EMAIL_ADDRESS" --region "$REGION_ID" "$@" 
RET_CODE=$?

logmsg "----------------------------------------------------------------"
exit_script $RET_CODE

