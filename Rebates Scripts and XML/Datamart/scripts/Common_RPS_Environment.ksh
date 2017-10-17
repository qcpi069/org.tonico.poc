#-------------------------------------------------------------------------#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 11-09-15   qcpi733     Corrected return code capture and exit for DB connection
# 06-23-15   qcpi733     Added call to UNIX_ENVIRONMENT_VARIABLES table
# 02-27-15   qcpue98u    SFTP user and hostname added
# 02-18-11   qcpi03o     updated MVS_FTP_ID to use DNS name
# 03-07-06   is89501     Updates for March 10 release
# 11-01-05   qcpi768     Initial Creation.
#-------------------------------------------------------------------------#
#!/bin/ksh

export RPS_ENV_SETTING="$(hostname -s)-$(echo $SCRIPTS_DIR | awk -F/ '{ print $3 }')"
case $RPS_ENV_SETTING in
       tstdbs1-*)
        export REGION="test"
        export QA_REGION="FALSE"
        PATH=/usr/bin:/etc:/usr/sbin:/usr/ucb:$HOME/bin:/usr/bin/X11:/sbin:.:/usr/java14/bin:/home/user/rpsdev1/sqllib/bin:/home/user/rpsdev1/sqllib/adm:/home/user/rpsdev1/sqllib/misc:/oracle/instantclient10_1:.
        . /home/user/rpsdev1/sqllib/db2profile
        export ORACLE_HOME=/u01/app/oracle/product/11.2.0/bin
        export BASE=/RPSDEV
        export MF_SCHEMA=dbad1
        export SUPPORT_EMAIL_ADDRESS='gdxdevtest@caremark.com'
        export MONITOR_EMAIL_ADDRESS='gdxdevtest@caremark.com'
        export Sftp_Server=tstwebtransport.caremark.com
        ;;
       tstdbs1a-*)
        export REGION="test"
        export QA_REGION="FALSE"
        PATH=/usr/bin:/etc:/usr/sbin:/usr/ucb:$HOME/bin:/usr/bin/X11:/sbin:.:/usr/java14/bin:/home/user/rpsdev1/sqllib/bin:/home/user/rpsdev1/sqllib/adm:/home/user/rpsdev1/sqllib/misc:/oracle/instantclient10_1:.
        . /home/user/rpsdev1/sqllib/db2profile
        export BASE=/RPSDEV
        export MF_SCHEMA=dbad1
        export SUPPORT_EMAIL_ADDRESS='gdxdevtest@caremark.com'
        export MONITOR_EMAIL_ADDRESS='gdxdevtest@caremark.com'
        export Sftp_Server=tstwebtransport.caremark.com
        ;;
       tstdbs2-*)
        export REGION="test"
        export QA_REGION="FALSE"
        PATH=/usr/bin:/etc:/usr/sbin:/usr/ucb:$HOME/bin:/usr/bin/X11:/sbin:.:/usr/java14/bin:/home/user/rpsdev2/sqllib/bin:/home/user/rpsdev2/sqllib/adm:/home/user/rpsdev2/sqllib/misc:/oracle/instantclient10_1:.
        . /home/user/rpsdev2/sqllib/db2profile
        export BASE=/RPSDEV
        export MF_SCHEMA=dbaw1
        export SUPPORT_EMAIL_ADDRESS='gdxdevtest@caremark.com'
        export MONITOR_EMAIL_ADDRESS='gdxdevtest@caremark.com'
        export Sftp_Server=tstwebtransport.caremark.com
        ;;
       tstdbs2a-*)
        export REGION="test"
        export QA_REGION="FALSE"
        PATH=/usr/bin:/etc:/usr/sbin:/usr/ucb:$HOME/bin:/usr/bin/X11:/sbin:.:/usr/java14/bin:/home/user/rpsdev2/sqllib/bin:/home/user/rpsdev2/sqllib/adm:/home/user/rpsdev2/sqllib/misc:/oracle/instantclient10_1:.
        . /home/user/rpsdev2/sqllib/db2profile
        export BASE=/RPSDEV
        export MF_SCHEMA=dbaw1
        export SUPPORT_EMAIL_ADDRESS='gdxdevtest@caremark.com'
        export MONITOR_EMAIL_ADDRESS='gdxdevtest@caremark.com'
        export Sftp_Server=tstwebtransport.caremark.com
        ;;
       tstdbs4-*)
        export REGION="prod"
        export QA_REGION="true"
        PATH=/usr/bin:/etc:/usr/sbin:/usr/ucb:$HOME/bin:/usr/bin/X11:/sbin:.:/usr/java14/bin:/home/user/rpssit1/sqllib/bin:/home/user/rpssit1/sqllib/adm:/home/user/rpssit1/sqllib/misc:/oracle/instantclient10_1:.
        . /home/user/rpssit1/sqllib/db2profile
        export BASE=/RPSPRD
        export MF_SCHEMA=dbax1
        export SUPPORT_EMAIL_ADDRESS='gdxsittest@caremark.com'
        export MONITOR_EMAIL_ADDRESS='gdxsittest@caremark.com'
        export Sftp_Server=tstwebtransport.caremark.com
        ;;
       tstdbs4a-*)
        export REGION="prod"
        export QA_REGION="true"
        PATH=/usr/bin:/etc:/usr/sbin:/usr/ucb:$HOME/bin:/usr/bin/X11:/sbin:.:/usr/java14/bin:/home/user/rpssit1/sqllib/bin:/home/user/rpssit1/sqllib/adm:/home/user/rpssit1/sqllib/misc:/oracle/instantclient10_1:.
        . /home/user/rpssit1/sqllib/db2profile
        export BASE=/RPSPRD
        export MF_SCHEMA=dbax1
        export SUPPORT_EMAIL_ADDRESS='gdxsittest@caremark.com'
        export MONITOR_EMAIL_ADDRESS='gdxsittest@caremark.com'
        export Sftp_Server=tstwebtransport.caremark.com
        ;;
       tstdbs5-*)
        export REGION="prod"
        export QA_REGION="true"
        PATH=/usr/bin:/etc:/usr/sbin:/usr/ucb:$HOME/bin:/usr/bin/X11:/sbin:.:/usr/java14/bin:/home/user/rpssit2/sqllib/bin:/home/user/rpssit2/sqllib/adm:/home/user/rpssit2/sqllib/misc:/oracle/instantclient10_1:.
        . /home/user/rpssit2/sqllib/db2profile
        export BASE=/RPSPRD
        export MF_SCHEMA=dbae1
        export SUPPORT_EMAIL_ADDRESS='gdxsittest@caremark.com'
        export MONITOR_EMAIL_ADDRESS='gdxsittest@caremark.com'
        export Sftp_Server=tstwebtransport.caremark.com
        ;;
       tstdbs5a-*)
        export REGION="prod"
        export QA_REGION="true"
        PATH=/usr/bin:/etc:/usr/sbin:/usr/ucb:$HOME/bin:/usr/bin/X11:/sbin:.:/usr/java14/bin:/home/user/rpssit2/sqllib/bin:/home/user/rpssit2/sqllib/adm:/home/user/rpssit2/sqllib/misc:/oracle/instantclient10_1:.
        . /home/user/rpssit2/sqllib/db2profile
        export BASE=/RPSPRD
        export MF_SCHEMA=dbae1
        export SUPPORT_EMAIL_ADDRESS='gdxsittest@caremark.com'
        export MONITOR_EMAIL_ADDRESS='gdxsittest@caremark.com'
        export Sftp_Server=tstwebtransport.caremark.com
        ;;
       prdrpd1a-*)
        export REGION="prod"
        export QA_REGION="FALSE"
        PATH=/usr/bin:/etc:/usr/sbin:/usr/ucb:$HOME/bin:/usr/bin/X11:/sbin:.:/usr/java14/bin:/home/user/prsprd/sqllib/bin:/home/user/prsprd/sqllib/adm:/home/user/prsprd/sqllib/misc:/u01/app/oracle/product/9.2.0/bin 
        . /home/user/prsprd/sqllib/db2profile
        export ORACLE_HOME=/u01/app/oracle/product/9.2.0
        export BASE=/RPSPRD
        export MF_SCHEMA=dbap1
        export SUPPORT_EMAIL_ADDRESS='ITD.Rebates@caremark.com'
        export MONITOR_EMAIL_ADDRESS='ITD.Rebates@caremark.com'
        export Sftp_Server=webtransport.caremark.com
        ;;
    *)
        echo "Unknown RPS_ENV_SETTING [${RPS_ENV_SETTING}]" >&2
        exit 1
        ;;
esac

###############################################################
#######  RPSDM DB Connection to get Enviornment data  ###########
###############################################################
# Figure out what environment we are in using:
# 1. The host name
# 2. The directory where the script that called this resides.

SCRIPTS_DIR=$(dirname "$0")

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

ID_FILE=$TEMP_WRK_DIR/DB_id_file_`echo $RanFileNm`_`date +"%Y%j%H%M%S"`.txt

export DB=" "
export C_ID=" "
export C_PWD=" "

#read the connection information for the database
read DB C_ID C_PWD < $SCRIPTS_DIR/.connect/.rpsdm_connect.txt

# Connect to database
db2 -p "connect to $DB user $C_ID using $C_PWD"

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print "Return code=>$RETCODE<-aborting environment script - cant connect to udb to query UNIX_ENVIRONMENT_VARIABLE table"
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
  FROM RPS.UNIX_ENVIRONMENT_VARIABLE 
where HOME_TXT='RPSDM';"

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
        export SMTP_HOST=$JAVA_SMTP_HOST_IP_ID
        export RCI_LIB_HOME=$JAVA_LIB_HOME_TXT
        export RCI_SCRIPT_DIR=$JAVA_SCRIPT_DIR_TXT
        export TO_MAIL=$FAILURE_TO_EMAIL_TXT
        export MVS_DB_REGION=$MVS_DB_REGION_TXT
        export SFTP_SERVER=$ST_SERVER_NM
        export ORACLE_HOME_TXT=$ORACLE_HOME_TXT
        export DBLOAD_PATH_TXT=$DBLOAD_PATH_TXT
        export CLNTREG_SCHEMA_NM=$CLNTREG_SCHEMA_NM
        export APPL_SCHEMA_NM=$APPL_SCHEMA_NM

export LOG_DIR=$REBATES_HOME/logs
export ARCH_LOG_DIR=$LOG_DIR/archive
export INPUT_DIR=$REBATES_HOME/input
export ARCH_INPUT_DIR=$INPUT_DIR/archive
export OUTPUT_DIR=$REBATES_HOME/output
export ARCH_OUTPUT_DIR=$OUTPUT_DIR/archive

####### end new variables

print " "
print "Successfully assigned UNIX variables for $UNIX_SYSTEM from UNIX_ENVIRONMENT_VARIABLES table."
print " "

export PATH
LANG=en_US

export SCHEMA=rps

export CLIENT_SCHEMA=client_reg

export CONFIG_PATH=$BASE/conf
export TMP_PATH=$BASE/tmp
export DBLOAD_PATH=/dbspace/data/rpsadm
export JAVA_XPATH=$BASE/java

#
export INPUT_PATH=$BASE/input
export INPUT_ARCH_PATH=$INPUT_PATH/archive
#
export LOG_PATH=$BASE/logs
export LOG_ARCH_PATH=$LOG_PATH/archive

export SCRIPT_PATH=$BASE/scripts

export XML_PATH=$BASE/scripts/xml

#######################################################
#
# UDB Connectivity strings
#
#######################################################
#
CONNECT_ID_FILE=$CONFIG_PATH/d1i.dat
PASSWORD_FILE=$CONFIG_PATH/d1p.dat
DATABASE_CONNECT_FILE=$CONFIG_PATH/d1d.dat
#
export CONNECT_ID=$(< $CONNECT_ID_FILE)
export CONNECT_PWD=$(< $PASSWORD_FILE)
export DATABASE=$(< $DATABASE_CONNECT_FILE)
export UDB_CONNECT_STRING="db2 -p connect to "$DATABASE" user "$CONNECT_ID" using "$CONNECT_PWD

#######################################################
#
# DB2 Z/OS Connectivity strings
#
#######################################################
CONNECT_ID_FILE2=$CONFIG_PATH/d2i.dat
PASSWORD_FILE2=$CONFIG_PATH/d2p.dat
DATABASE_CONNECT_FILE2=$CONFIG_PATH/d2d.dat
#
export CONNECT_ID2=$(< $CONNECT_ID_FILE2)
export CONNECT_PWD2=$(< $PASSWORD_FILE2)
export DATABASE2=$(< $DATABASE_CONNECT_FILE2)
export DB2_CONNECT_STRING="db2 -p connect to "$DATABASE2" user "$CONNECT_ID2" using "$CONNECT_PWD2 


#######################################################
#
# Oracle Connectivity strings
#
#######################################################
CONNECT_ID_FILE3=$CONFIG_PATH/d3i.dat
PASSWORD_FILE3=$CONFIG_PATH/d3p.dat
DATABASE_CONNECT_FILE3=$CONFIG_PATH/d3d.dat
#
export CONNECT_ID3=$(< $CONNECT_ID_FILE3)
export CONNECT_PWD3=$(< $PASSWORD_FILE3)
export DATABASE3=$(< $DATABASE_CONNECT_FILE3)
export ORA_CONNECT_STRING="sqlplus -s "$CONNECT_ID3"/"$CONNECT_PWD3"@"$DATABASE3 


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
#
#######################################################
#
# SFTP variables
#
#######################################################
#

export Sftp_User=rebates_sftp
#
