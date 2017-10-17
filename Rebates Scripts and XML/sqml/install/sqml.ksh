#!/bin/ksh
#-------------------------------------------------------------------------------
# Korn shell scrip t to run sqml (SQL XML) interpreter.
#-------------------------------------------------------------------------------

SCRIPT_NAME="$0"
BASEDIR=""
CONF_DIR=""
LIB_DIR=""

# Intialize the directory names for the script
function init_dirs {
	find_basedir
	CONF_DIR="$BASEDIR/conf"
	LIB_DIR="$BASEDIR/lib"
}

function find_basedir {
	BASEDIR=""
	BASEDIR=`dirname $SCRIPT_NAME`"/.."
	BASEDIR=`ksh -c "cd $BASEDIR; pwd"`
}

# Builds a classpath to be used by java 
function get_classpath {
	if [[ -n "$CLASSPATH" ]]; then
		printf "$CLASSPATH:"
	fi
	printf ".:$CONF_DIR"
	find "$LIB_DIR" \( -name '*.jar' -o -name '*.zip' \) -exec printf ":%s" {} \;
}

# Finds the java command
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

init_dirs

# Source the script env.ksh in the conf directory if it exists.
if [[ -f "$CONF_DIR/env.ksh" ]]; then
	. "$CONF_DIR/env.ksh"
fi

JAVA=`get_java`
export CLASSPATH=`get_classpath`

# Execute the java command
# Pass all arguments to the java command
exec "$JAVA" com.caremark.gdx.sqml.SqlXmlScript "$@"

