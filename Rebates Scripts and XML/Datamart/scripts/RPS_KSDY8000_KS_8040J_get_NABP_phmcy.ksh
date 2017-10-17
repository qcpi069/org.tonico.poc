#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
# Script        : RPS_get_NABP_phmcy.ksh 
# Title         : Pull NABP_CODE and PHMCY_NAME from EDW to RPS DM 
# Description   : Build table RPS.TPHMCY to be used
#                 to join with RPS.VAPC_DETAIL on NABP_CODE
# Abends        : 
#
# Parameters    : None
#
# Output        : Log file as $LOG_FILE 
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
# Date                    Description
# ----------  ----------  -------------------------------------------------#
# 04-30-2009  qcpi08a     Initial Creation.
#--------------------------------------------------------------------------#

#--------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#--------------------------------------------------------------------------#

  . `dirname $0`/Common_RPS_Environment.ksh

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

function exit_error {
   RETCODE=$1
   ERROR=$2

   cp -f $DATA_FILE $LOG_ARCH_PATH/$FILE_BASE.$TIME_STAMP.dat

   if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
   fi

   print " "                                                 >> $LOG_FILE
   print " "                                                 >> $LOG_FILE
   print "	!!! Aborting due to " $ERROR `date`
   print "	!!! Aborting due to " $ERROR `date`          >> $LOG_FILE
   mailx -s "$EMAIL_SUBJECT" $SUPPORT_EMAIL_ADDRESS          < $LOG_FILE
   print "return_code = " $RETCODE   >> $LOG_FILE

   cp -f $LOG_FILE $LOG_ARCH_FILE
   exit $RETCODE
}

cd $SCRIPT_PATH

SCRIPTNAME=$(basename "$0") 
FILE_BASE=$(echo $SCRIPTNAME|awk -F. '{print $1}')
EMAIL_SUBJECT=$SCRIPTNAME" Abended on "`date`
LOG_FILE=$LOG_PATH/$FILE_BASE".log"
LOG_ARCH_FILE=$LOG_ARCH_PATH/$FILE_BASE.$TIME_STAMP".log"
DATA_FILE=$TMP_PATH/$FILE_BASE".dat"
SQL_FILE=$TMP_PATH/$FILE_BASE".sql"
DB2MSG_FILE=$TMP_PATH/$FILE_BASE."db2msg"
ORACLE_DB_USER_PASSWORD=$(cat "${CONFIG_PATH}/ora_user_edw.fil")
RETCODE=0

rm -f $LOG_FILE
rm -f $DATA_FILE
rm -f $SQL_FILE
rm -f $DB2MSG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the start time.
#-------------------------------------------------------------------------#

   print " ------ Script Started on " `date`
   print " ------ Script Started on " `date` > $LOG_FILE

#-------------------------------------------------------------------------#
# Query to put data from EDW 
#-------------------------------------------------------------------------#

cat > $SQL_FILE << EOF
    set LINESIZE 200
    set TERMOUT OFF
    set PAGESIZE 0
    set NEWPAGE 0
    set SPACE 0
    set ECHO OFF
    set FEEDBACK OFF
    set HEADING OFF
    set WRAP off
    set verify off
    whenever sqlerror exit 1
    SPOOL $DATA_FILE
    alter session enable parallel dml; 

    SELECT NABP_CODE, MAX(PHMCY_NAME)
      FROM (
            SELECT NVL(NABP_CODE, '0000000') AS NABP_CODE, 
                   NVL(PHMCY_NAME, 'N/A') AS PHMCY_NAME
              FROM DMA_RBATE2.V_PMCY_DENORM
             UNION 
            SELECT NVL(NABP_CODE_ORIG, '0000000') AS NABP_CODE,  
                   NVL(PHMCY_NAME, 'N/A') AS PHMCY_NAME
              FROM DMA_RBATE2.V_PMCY_DENORM
           )
     GROUP BY NABP_CODE 
    ;
    quit;
EOF

#-------------------------------------------------------------------------#
# Execute the query to put data from EDW
#-------------------------------------------------------------------------#

    START_DATE=`date +"%D %r %Z"`

    #--------------------------------------------------------------------#
    # Developemnt env run
    #--------------------------------------------------------------------# 

#    $ORACLE_HOME/instantclient10_1/sqlplus -s $ORACLE_DB_USER_PASSWORD @$SQL_FILE

    #--------------------------------------------------------------------#
    # Production env run
    #--------------------------------------------------------------------#

    $ORACLE_HOME/bin/sqlplus -s $ORACLE_DB_USER_PASSWORD @$SQL_FILE

    export RETCODE=$?
    END_DATE=`date +"%D %r %Z"`

    print                                                           >> $LOG_FILE
    print "****** Pull data from EDW ****** " `date`                >> $LOG_FILE
    if [[ $RETCODE != 0 ]]; then
       tail -20 $DATA_FILE                                          >> $LOG_FILE
       export ERROR="error when pulling data from EDW "
       exit_error $RETCODE "$ERROR"
    else
    {
      print "    *** Completed pulling data between $START_DATE and $END_DATE"
      print
    } >> $LOG_FILE
    fi

#-------------------------------------------------------------------------#
# Connect to RPS 
#-------------------------------------------------------------------------#

    print                                                             >> $LOG_FILE
    print "****** Connect to RPS UDB ******" `date`                   >> $LOG_FILE
    $UDB_CONNECT_STRING                                               >> $LOG_FILE
    export RETCODE=$?
    if [[ $RETCODE != 0 ]]; then
       export ERROR="error when connect to RPS"
       exit_error $RETCODE "$ERROR"
    fi

#-------------------------------------------------------------------------#
# Import data to RPS, update rows with matching primary key values 
# with values of input rows and insert imported rows without matching  
#-------------------------------------------------------------------------#

    print "****** Import data to RPS.TPHMCY ****** " `date`               >> $LOG_FILE
    import_sql="import from $DATA_FILE of asc modified by usedefaults method L(1 16, 17 76) 
                commitcount 1000 messages "$DB2MSG_FILE"
                INSERT_UPDATE INTO RPS.TPHMCY(NABP_CODE,PHMCY_NAME) "
    echo "$import_sql"                                                    >> $LOG_FILE 
    import_sql=$(echo "$import_sql" | tr '\n' ' ')
    print                                                                 >> $LOG_FILE
    START_DATE=`date +"%D %r %Z"`
    db2 -px "$import_sql"                                                 >> $LOG_FILE                                                  
    export RETCODE=$?
    END_DATE=`date +"%D %r %Z"`

    if [[ $RETCODE != 0 ]]; then
       export ERROR="error when import data to RPS "
       exit_error $RETCODE "$ERROR" 
    else
      print "    *** Completed import data between $START_DATE and $END_DATE"  >> $LOG_FILE
      print                                                                   >> $LOG_FILE
    fi
#-------------------------------------------------------------------------#
# Successful complete 
#-------------------------------------------------------------------------#

#   mv $DATA_FILE $LOG_ARCH_PATH/$FILE_BASE.$TIME_STAMP.dat
    print " return_code =" $RETCODE
    print " ------ Script completed on " `date`
    print " ------ Script completed on " `date`                         >> $LOG_FILE
    print " return_code =" $RETCODE                                     >> $LOG_FILE

    mv $LOG_FILE $LOG_ARCH_FILE
    exit $RETCODE

