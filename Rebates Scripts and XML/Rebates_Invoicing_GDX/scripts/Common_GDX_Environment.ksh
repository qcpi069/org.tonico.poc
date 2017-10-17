#!/bin/ksh
#-------------------------------------------------------------------------#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 11-10-15   qcpi733     Fix to return code capture and evaluation after DB2 commands  
# 06-25-15   is45401     ITPR011275-Added call to UNIX_ENVIRONMENT_VARIABLES table  
# 04-03-14   qcpi733     changed GDX_ENV_SETTING case for all DEV/SIT boxes
#                        removed r07tst07 from case
# 10-15-13   qcpue98     Env setting to drop RCN temp tables in VACTUATE schema
# 11-06-11   is90001     Changed GDX_ENV_SETTING check from r07prd01 to prdrgd1a
# 05-01-07   is31701     Added variables for new db2 load id and password
# 11-15-06   is45401     Replaced R07TST07 with TSTUDB4 
# 06-19-06   is94901     Added lookup of host environment.
# 04-05-06   is94901     Added java environment stuff.
# 05-11-05   qcpi733     Changed variable values for Prod
# 04-08-05   qcpi733     Changed from MDA to GDX
# 03-03-05   qcpi733     Added Functions script call; Added Oracle client;
# 02-20-05   qcpu70x     Initial Creation.
#-------------------------------------------------------------------------#

# Figure out what environment we are in using:
# 1. The host name
# 2. The directory where the script that called this resides.

print "0=>$0<"


if [[ $0 != "/"* ]];then
    SCRIPTS_DIR=`pwd`
    TEMP_WRK_DIR=`echo $SCRIPTS_DIR/tmpwkdir`
else
    SCRIPTS_DIR=`dirname $0`
    TEMP_WRK_DIR=`echo $SCRIPTS_DIR/tmpwkdir`
fi

print "SCRIPTS_DIR=$SCRIPTS_DIR"

cd "$SCRIPTS_DIR"

export GDX_ENV_SETTING="$(hostname -s)-$(echo $SCRIPTS_DIR | awk -F/ '{ print $3 }')"
case $GDX_ENV_SETTING in
       tstdbs1-*)
        export REGION="test"
        export QA_REGION="FALSE"
        export GDXUSER_HOME=/home/user/gdxdev1
        export ORACLE_HOME=/u01/app/oracle/product/11.2.0/bin
        ;;
       tstdbs1a-*)
        export REGION="test"
        export QA_REGION="FALSE"
        export GDXUSER_HOME=/home/user/gdxdev1
        export ORACLE_HOME=/u01/app/oracle/product/11.2.0/bin
        ;;
       tstdbs2-*)
        export REGION="test"
        export QA_REGION="FALSE"
        export GDXUSER_HOME=/home/user/gdxdev2
        ;;
       tstdbs2a-*)
        export REGION="test"
        export QA_REGION="FALSE"
        export GDXUSER_HOME=/home/user/gdxdev2
        ;;
       tstdbs4-*)
        export REGION="prod"
        export QA_REGION="true"
        export GDXUSER_HOME=/home/user/gdxsit1
        ;;
       tstdbs4a-*)
        export REGION="prod"
        export QA_REGION="true"
        export GDXUSER_HOME=/home/user/gdxsit1
        ;;
       tstdbs5-*)
        export REGION="prod"
        export QA_REGION="true"
        export GDXUSER_HOME=/home/user/gdxsit2
        ;;
       tstdbs5a-*)
        export REGION="prod"
        export QA_REGION="true"
        export GDXUSER_HOME=/home/user/gdxsit2
        ;;
       prdrgd1a-*)
        export REGION="prod"
        export QA_REGION="FALSE"
        export GDXUSER_HOME=/home/user/gdxprd
        ORACLE_HOME=/oracle/instantclient10_1
        ;;
    *)
        echo "Unknown GDX_ENV_SETTING [${GDX_ENV_SETTING}]" >&2
        exit 1
        ;;
esac

PATH="/usr/bin"
PATH="/etc:$PATH"
PATH="/usr/sbin:$PATH"
PATH="/usr/ucb:$PATH"
PATH="/home/user/vactuate/bin:$PATH"
PATH="/usr/bin/X11:$PATH"
PATH="/sbin:$PATH"
PATH="/usr/lpp/cobol/bin:$PATH"
PATH="/usr/lpp/cobol/lib:$PATH"
PATH="/usr/lib/nls/msg/%L/%N:$PATH"
PATH="/usr/lib/nls/msg/%L/%N.cat:$PATH"
PATH="/udbprod/udbinst8/sqllib:$PATH"
PATH="$ORACLE_HOME:$PATH"
PATH="/usr/local/bin:$PATH"
PATH="$GDXUSER_HOME/sqllib/bin:$PATH"
PATH="$GDXUSER_HOME/sqllib/adm:$PATH"
PATH="$GDXUSER_HOME/sqllib/misc:$PATH"
PATH=".:$PATH"
export PATH

. $GDXUSER_HOME/sqllib/db2profile
LANG=en_US

###############################################################
#######  GDX DB Connection to get Enviornment data  ###########
###############################################################
# Figure out what environment we are in using:
# 1. The host name
# 2. The directory where the script that called this resides.

# the ID_FILE generated below needs to have a unique name to it.  Since this
#   script is executed by numerous other scripts, we determined to generate
#   a random number, 3 times, would build us a unique filename for this
#   temporary file.
RanNum1=$RANDOM
RanNum2=$RANDOM
RanNum3=$RANDOM
RanFileNm="$RanNum1$RanNum2$RanNum3"

cd "$SCRIPTS_DIR"

ID_FILE=$TEMP_WRK_DIR/DB_id_file_`echo $RanFileNm`_`date +"%Y%j%H%M%S"`.txt

export DB=" "
export C_ID=" "
export C_PWD=" "

#read the connection information for the database
read DB C_ID C_PWD < $SCRIPTS_DIR/.connect/.gdx_connect.txt

# Connect to database
db2 -p "connect to $DB user $C_ID using $C_PWD"

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "aborting environment script - cant connect to udb to query UNIX_ENVIRONMENT_VARIABLE table"
    rm -f $ID_FILE
    exit $RETCODE
fi

print " "
print "Connected successfully to $DB for variable query"
print " "

###############################################################
#########   Build SQL for environment variables   #############
###############################################################

#select fields from the environment table
export query="SELECT HOME_TXT
       ,UNIX_REGION_TXT
       ,QA_UNIX_REGION_TXT
       ,REBATES_UNIX_HOME_TXT
       ,JAVA_CONFIG_DIR_TXT
       ,APPL_DB_CONNECT_ID
       ,APPL_DB_LOADER_CONNECT_ID
       ,GDX_APPL_DB_SERVER_NM
       ,RPSDM_APPL_DB_SERVER_NM
       ,APPL_ETL_SERVER_NM
       ,JAVA_HOME_TXT
       ,JAVA_JDBCURL_TXT
       ,DB_PORT_NB
       ,JAVA_SMTP_HOST_IP_ID
       ,JAVA_LIB_HOME_TXT
       ,JAVA_SCRIPT_DIR_TXT
       ,FAILURE_TO_EMAIL_TXT
       ,MVS_DB_REGION_TXT
       ,ST_SFTP_USER
       ,ST_SERVER_NM
       ,ORACLE_HOME_TXT
       ,DBLOAD_PATH_TXT
       ,MONITOR_EMAIL_ADDRESS_TXT
       ,CLNTREG_SCHEMA_NM
       ,APPL_SCHEMA_NM
  FROM VRAP.UNIX_ENVIRONMENT_VARIABLE 
where HOME_TXT='GDX';"

db2 -stxw $query > $ID_FILE

RC=$?

if [[ $RC != 0 ]]; then
    print "Return code=>$RC< - aborting script while trying to execute UNIX_ENVIRONMENT_VARIABLE query-Error executing query "
    if [[ $RC == 1 ]]; then 
        print "No rows found in UNIX_ENVIRONMENT_VARIABLE table"
    fi
    print " "
    cat $ID_FILE
    print " "
    rm -f $ID_FILE
    exit $RC
fi

###############################################################
#########       Disconnect from udb              ##############
###############################################################
db2 -stvx connect reset
db2 -stvx quit

read HOME_TXT UNIX_REGION_TXT QA_UNIX_REGION_TXT REBATES_UNIX_HOME_TXT JAVA_CONFIG_DIR_TXT APPL_DB_CONNECT_ID APPL_DB_LOADER_CONNECT_ID GDX_APPL_DB_SERVER_NM RPSDM_APPL_DB_SERVER_NM APPL_ETL_SERVER_NM JAVA_HOME_TXT JAVA_JDBCURL_TXT DB_PORT_NB JAVA_SMTP_HOST_IP_ID JAVA_LIB_HOME_TXT JAVA_SCRIPT_DIR_TXT FAILURE_TO_EMAIL_TXT MVS_DB_REGION_TXT ST_SFTP_USER ST_SERVER_NM ORACLE_HOME_TXT DBLOAD_PATH_TXT MONITOR_EMAIL_ADDRESS_TXT CLNTREG_SCHEMA_NM APPL_SCHEMA_NM < $ID_FILE

##########################################
#  Any new project after Aug’15 to use these variables
########################################## 

# In the future, with the next box name change, change the way already defined
#   variables are assigned from the above, to the use of the environment table

        export UNIX_SYSTEM=$HOME_TXT
#already defined        export REGION=$UNIX_REGION_TXT
#already defined        export QA_REGION=$QA_UNIX_REGION_TXT
        export REBATES_HOME=$REBATES_UNIX_HOME_TXT
        export CONFIG_DIR=$JAVA_CONFIG_DIR_TXT
        export APPL_DB_CONNECT_ID=$APPL_DB_CONNECT_ID
        export APPL_DB_LOADER_CONNECT_ID=$APPL_DB_LOADER_CONNECT_ID
        export GDX_DB_SERVER=$GDX_APPL_DB_SERVER_NM
        export RPSDM_DB_SERVER=$RPSDM_APPL_DB_SERVER_NM
        export APPL_ETL_SERVER=$APPL_ETL_SERVER_NM
#already defined        export JAVA_HOME=$JAVA_HOME_TXT
        export JDBCURL=$JAVA_JDBCURL_TXT
        export DB_PORT=$DB_PORT_NB
#already defined        export SMTP_HOST=$JAVA_SMTP_HOST_IP_ID
        export JAVA_LIB_HOME=$JAVA_LIB_HOME_TXT
        export GDX_JAVA_SCRIPT_DIR=$JAVA_SCRIPT_DIR_TXT
#already defined        export TO_MAIL=$FAILURE_TO_EMAIL_TXT
        export MVS_DB_REGION=$MVS_DB_REGION_TXT
        export SFTP_SERVER=$ST_SERVER_NM
#already defined        export ORACLE_HOME=$ORACLE_HOME_TXT
        export DBLOAD_PATH=$DBLOAD_PATH_TXT
        export CLNTREG_SCHEMA=$CLNTREG_SCHEMA_NM
        export APPL_SCHEMA=$APPL_SCHEMA_NM

export LOG_DIR=$REBATES_HOME/log
export ARCH_LOG_DIR=$LOG_DIR/archive
export INPUT_DIR=$REBATES_HOME/input
export ARCH_INPUT_DIR=$INPUT_DIR/archive
export OUTPUT_DIR=$REBATES_HOME/output
export ARCH_OUTPUT_DIR=$OUTPUT_DIR/archive

print " "
print "Successfully assigned UNIX variables for $UNIX_SYSTEM from $APPL_SCHEMA.UNIX_ENVIRONMENT_VARIABLES table."
print " "

export GDX_PATH=/GDX/$REGION

export INPUT_PATH=$GDX_PATH/input
export INPUT_ARCH_PATH=$INPUT_PATH/archive

export LOG_PATH=$GDX_PATH/log
export LOG_ARCH_PATH=$LOG_PATH/archive

export OUTPUT_PATH=$GDX_PATH/output
export OUTPUT_ARCH_PATH=$OUTPUT_PATH/archive

export SCRIPT_PATH=$GDX_PATH/scripts
export SCRIPT_ARCH_PATH=$SCRIPT_PATH/archive

export SQL_PATH=$GDX_PATH/sql 
export SQL_ARCH_PATH=$SQL_PATH/archive

ORACLE_DB_USER_PASSWORD=$SCRIPT_PATH/ora_user.fil

export TMP_PATH=$GDX_PATH/tmp

#######################################################
#
# UDB Connectivity strings
#
#######################################################
#

CONNECT_ID_FILE=$INPUT_PATH/GDX_COMMON_CONNECT_ID.dat
PASSWORD_FILE=$INPUT_PATH/GDX_COMMON_CONNECT_ID_PASSWORD.dat
#
LOAD_CONNECT_ID_FILE=$INPUT_PATH/GDX_LOAD_CONNECT_ID.dat
LOAD_PASSWORD_FILE=$INPUT_PATH/GDX_LOAD_CONNECT_ID_PASSWORD.dat
#
RCN_CONNECT_ID_FILE=$INPUT_PATH/.CASH_CONNECT_ID.dat
RCN_PASSWORD_FILE=$INPUT_PATH/.CASH_CONNECT_ID_PASSWORD.dat
#
DATABASE_CONNECT_FILE=$INPUT_PATH/GDX_COMMON_CONNECT_DATABASE.dat
#
export CONNECT_ID=$(< $CONNECT_ID_FILE)
export CONNECT_PWD=$(< $PASSWORD_FILE)
#
export LOAD_CONNECT_ID=$(< $LOAD_CONNECT_ID_FILE)
export LOAD_CONNECT_PWD=$(< $LOAD_PASSWORD_FILE)
#
export RCN_CONNECT_ID=$(< $RCN_CONNECT_ID_FILE)
export RCN_CONNECT_PWD=$(< $RCN_PASSWORD_FILE)
#
export DATABASE=$(< $DATABASE_CONNECT_FILE)

#######################################################
#
# Generically defined Error codes
#
#######################################################
#
export CME_SUCCESS=0
export CME_MINOR=4
export CME_WARNING=8
export CME_FATAL_ERROR=12
#
#######################################################
#
# Other common variables
#
#######################################################
#
export TIME_STAMP=`date +"%Y%j%H%M"`

#######################################################
#
# Set java environment
#
#######################################################

# Adds an entry to the CLASSPATH environment variable
# if it does not exist in the CLASSPATH.
function gdx_add_to_classpath {
    typeset cp="$1"
    if ! echo "$CLASSPATH" | tr ':' '\n' | egrep -q "^${cp}\$"; then
        if [[ "$CLASSPATH" = "" ]]; then
            CLASSPATH="$cp"
        else
            CLASSPATH="${cp}:${CLASSPATH}"
        fi
    fi
}

# Set java environment
export JAVA_HOME=/usr/java14

# Add java bin to path
if ! echo "$PATH" | grep -q "$JAVA_HOME/bin"; then
    PATH=$JAVA_HOME/bin:$PATH
fi

# Note jar files are added in reverse order, because they 
# are prepended to the classpath, not appended.
 
# Add jars in lib to classpath
for jar in $(ls -r $GDX_PATH/java/lib/*.jar $GDX_PATH/java/lib/*.zip 2>/dev/null)
do
    gdx_add_to_classpath "$jar"
done

# Add the xml and conf directories
gdx_add_to_classpath "${GDX_PATH}/xml"
gdx_add_to_classpath "${GDX_PATH}/java/conf"

export JAVA_HOME
export CLASSPATH


