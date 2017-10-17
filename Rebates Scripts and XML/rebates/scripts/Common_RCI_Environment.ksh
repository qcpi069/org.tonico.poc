#!/bin/ksh
#--------------------------------------------------------------------------#
#   Date                 Description
# ----------  ----------  -------------------------------------------------#
# 06-26-2015   qcpi733     ITPR011275 - added WHERE to 
#                          UNIX_ENVIRONMENT_VARIABLE query
# 03-21-2014   qcpuk218    Introduced 2 environment variables for SFTP.  
#                          ST_SFTP_USER and ST_SERVER_NM 
# 11-02-2013   qcpi2gt     Introduced 3 random variables and used them
#                          in making ID_FILE more unique
# 07-19-2013   qcpi2d6     Introduced DEV2/SIT2 variables, table driven
#                          approach and removed all hardcoded password
# 04-01-2009   qcpu70x     Initial Creation.
#--------------------------------------------------------------------------#

# Figure out what environment we are using:
# 1. The host name
# 2. The directory where the script that called this resides.

. /home/user/udbcae/sqllib/db2profile

PRE_WOR_DIR=$(pwd)
SCRIPTS_DIR=$(dirname "$0")
ENV_SCRIPT_NM="Common_RCI_Environment.ksh"

if [[ $0 != "/"* ]];then
    SCRIPTS_DIR=`pwd`
    TEMP_WRK_DIR=`echo $SCRIPTS_DIR/tmpwkdir`
else
    SCRIPTS_DIR=`dirname $0`
    TEMP_WRK_DIR=`echo $SCRIPTS_DIR/tmpwkdir`
fi

# the ID_FILE generated below needs to have a unique name to it.  Since this
#   script is executed by numerous other scripts, we determined to generate
#   a random number, 3 times, would build us a unique filename for this
#   temporary file.
RanNum1=$RANDOM
RanNum2=$RANDOM
RanNum3=$RANDOM
RanFileNm="$RanNum1$RanNum2$RanNum3"

cd "$SCRIPTS_DIR"
cd "$PRE_WOR_DIR"

STREAM_DIR=`echo $SCRIPTS_DIR | awk -F/ '{ print $4 }'`

print " "
print "Starting $ENV_SCRIPT_NM"
print " "
print "STREAM_DIR=>$STREAM_DIR<"
print " "

read DB C_ID C_PWD < $SCRIPTS_DIR/.connect/.db_connect.txt

###############################################################

        export DATABASE=$DB
        export CONNECT_ID=$C_ID
        export CONNECT_PWD=$C_PWD

###############################################################
#######  GDX DB Connection to get Enviornment data  ###########
###############################################################

export query="select HOME_TXT
       ,UNIX_REGION_TXT
       ,INFA_DOMAIN_NM
       ,QA_UNIX_REGION_TXT
       ,INFA_REPOSITORY_NM
       ,INFA_INTSVC_NM
       ,INFA_HOME_TXT
       ,REBATES_UNIX_HOME_TXT
       ,JAVA_CONFIG_DIR_TXT
       ,INFA_PMUSER_ID
       ,INFA_META_DB_NM
       ,INFA_META_SCHEMA_NM
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
where HOME_TXT='ETL';"

ID_FILE=$TEMP_WRK_DIR/${STREAM_DIR}_$1_id_file_`echo $RanFileNm`_`date +"%Y%j%H%M%S"`.txt

db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"

 if [[ $? != 0 ]]; then
    print "aborting script - cant connect to udb "
    rm -f $ID_FILE
   exit 1
 fi

db2 -stxw $query >> $ID_FILE

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
#########       Disconnect form udb              ##############
###############################################################
db2 -stvx connect reset
db2 -stvx quit

###############################################################
#########   Read variables and connection files   #############
###############################################################

read HOME_TXT  UNIX_REGION_TXT  INFA_DOMAIN_NM  QA_UNIX_REGION_TXT  INFA_REPOSITORY_NM  INFA_INTSVC_NM  INFA_HOME_TXT  REBATES_UNIX_HOME_TXT  JAVA_CONFIG_DIR_TXT  INFA_PMUSER_ID  INFA_META_DB_NM  INFA_META_SCHEMA_NM  APPL_DB_CONNECT_ID  APPL_DB_LOADER_CONNECT_ID  GDX_APPL_DB_SERVER_NM  RPSDM_APPL_DB_SERVER_NM  APPL_ETL_SERVER_NM  JAVA_HOME_TXT  JAVA_JDBCURL_TXT  DB_PORT_NB  JAVA_SMTP_HOST_IP_ID  JAVA_LIB_HOME_TXT  JAVA_SCRIPT_DIR_TXT  FAILURE_TO_EMAIL_TXT  MVS_DB_REGION_TXT  ST_SFTP_USER  ST_SERVER_NM  ORACLE_HOME_TXT  DBLOAD_PATH_TXT  MONITOR_EMAIL_ADDRESS_TXT  CLNTREG_SCHEMA_NM  APPL_SCHEMA_NM  <  $ID_FILE

read META_C_ID META_C_PWD < $SCRIPTS_DIR/.connect/.meta_connect.txt

read L_C_ID L_C_PWD < $SCRIPTS_DIR/.connect/.loader_connect.txt

##############################################################
###### EXport of Rebates environmental variables #############
##############################################################

        export REGION=$UNIX_REGION_TXT
        export REBATES_INFA_DOM=$INFA_DOMAIN_NM
        export QA_REGION=$QA_UNIX_REGION_TXT
        export REBATES_INFA_REPOS=$INFA_REPOSITORY_NM
        export REBATES_INFA_SV=$INFA_INTSVC_NM
        export INFA_HOME=$INFA_HOME_TXT
        export REBATES_HOME=$REBATES_UNIX_HOME_TXT
        export CONFIG_DIR=$JAVA_CONFIG_DIR_TXT
        export PMUSER=$INFA_PMUSER_ID
        export META_DB=$INFA_META_DB_NM
        export META_SCHEMA=$INFA_META_SCHEMA_NM
        export APPL_DB_CON_ID=$APPL_DB_CONNECT_ID
        export APPL_DB_LOAD_CON_ID=$APPL_DB_LOADER_CONNECT_ID
        export GDX_DB_SERVER=$GDX_APPL_DB_SERVER_NM
        export RPSDM_DB_SERVER=$RPSDM_APPL_DB_SERVER_NM
        export APPL_ETL_SERVER=$APPL_ETL_SERVER_NM
        export JAVA_HOME=$JAVA_HOME_TXT
        export JDBCURL=$JAVA_JDBCURL_TXT
        export DB_PORT=$DB_PORT_NB
        export SMTP_HOST=$JAVA_SMTP_HOST_IP_ID
        export RCI_LIB_HOME=$JAVA_LIB_HOME_TXT
        export RCI_SCRIPT_DIR=$JAVA_SCRIPT_DIR_TXT
        export TO_MAIL=$FAILURE_TO_EMAIL_TXT
        export MVS_DB_REGION=$MVS_DB_REGION_TXT
        export SFTP_USER=$ST_SFTP_USER
        export SFTP_SERVER=$ST_SERVER_NM
        export ORACLE_HOME_TXT=$ORACLE_HOME
        export DBLOAD_PATH_TXT=$DBLOAD_PATH
        export MONITOR_EMAIL_ADDRESS_TXT=$MONITOR_EMAIL_ADDRESS
        export CLNTREG_SCHEMA_NM=$CLNTREG_SCHEMA_NM
        export APPL_SCHEMA_NM=$APPL_SCHEMA_NM
#Connection variables 
        export PMPASS=09ZVpQU20bIz1tXYfpOX6w==
        export META_CONNECT_ID=$META_C_ID
        export META_CONNECT_PWD=$META_C_PWD
        export LOADER_CONNECT_ID=$L_C_ID
        export LOADER_CONNECT_PWD=$L_C_PWD

##############################################################

PATH=$JAVA_HOME/bin:$PATH
LIB_PATH=$REBATES_HOME/lib

export LOG_DIR=$REBATES_HOME/log
export ARCH_LOG_DIR=$LOG_DIR/archive
export INPUT_DIR=$REBATES_HOME/input
export ARCH_INPUT_DIR=$INPUT_DIR/archive
export OUTPUT_DIR=$REBATES_HOME/output
export ARCH_OUTPUT_DIR=$OUTPUT_DIR/archive
export PMCMD_SCRIPT=infa_pmcmd.sh

rm -f $ID_FILE

print "End of $ENV_SCRIPT_NM"
print " "
