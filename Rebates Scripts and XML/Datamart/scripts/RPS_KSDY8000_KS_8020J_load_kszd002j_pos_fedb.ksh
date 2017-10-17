#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSDY8000_KS_8020J_load_kszd002j_pos_fedb.ksh 
# Title         : Import POS claims from FEDB into Datamart
#
# Description   : This script will import the daily POS claim feed from  
#                 FEDB.  
# 
# Abends        : If count parm does not match insert results then set bad 
#                 return code.
#                 
#
# Parameters    : None 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 11-01-05   qcpi768     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh
  . $SCRIPT_PATH/Common_RPS_Script_Functions.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSDY8000_KS_8020J_load_kszd002j_pos_fedb

JOB=ks8020j
MFJOB=kszd002j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

UDB_OUTPUT_MSG_FILE=$BASE/tmp/$JOB.msg
UDB_SQL_FILE=$BASE/tmp/$JOB.sql

RETCODE=0

cd $BASE/scripts

echo $SCRIPT " start time: "`date` 
echo $SCRIPT " start time: "`date`                                     > $LOG_FILE

MYPARM=""
if [[ $# -eq 1 ]]; then
    MYPARM=`echo $1`
fi
print " input parm was: " $MYPARM

#################################################################
# examine the ftpd  trailer record
#################################################################
FTP_TRIG_NAME=$MFJOB.posftp.fedb.tlr
FTP_DATA_NAME=$MFJOB.posftp.fedb.dat

FTP_TRIGFILE=$INPUT_PATH/$FTP_TRIG_NAME
FTP_DATAFILE=$INPUT_PATH/$FTP_DATA_NAME

PDATE=`cat $FTP_TRIGFILE |cut -c 2-11`
print " pdate from tigger file is " $PDATE                              >> $LOG_FILE 

PCOUNT=`cat $FTP_TRIGFILE |cut -c 52-61`
print " pcount from trigger file is " $PCOUNT                           >> $LOG_FILE 

print ' trigger file name is '  $FTP_TRIGFILE                           >> $LOG_FILE 
print " pcount is " $PCOUNT

cat $FTP_TRIGFILE                                                       >> $LOG_FILE 

#################################################################
# determine the quarter of the process date
#################################################################
QTR=""
QPID=""
YEAR=`echo $PDATE |cut -c 1-4`
MM=`echo $PDATE |cut -c 6-7`
case $MM in 
  01|02|03) export QTR=1 ;;
  04|05|06) export QTR=2 ;;
  07|08|09) export QTR=3 ;;
  10|11|12) export QTR=4 ;;
esac 
QPID=$YEAR"Q"$QTR
print ' period id derived from trailer record is ' $QPID
print ' period id derived from trailer record is ' $QPID                 >> $LOG_FILE 

#################################################################
# count the datafile and check unix return code from wc  
#################################################################
if [[ $RETCODE == 0 ]]; then 
   DCOUNT=$(wc -l < $FTP_DATAFILE)
   RETCODE=$?
   if [[ $RETCODE != 0 ]] ; then
       print `date` ' *** Ftp Validation return code ' $RC ' on wc command using ' $FTP_DATAFILE   
       print `date` ' *** Ftp Validation return code ' $RC ' on wc command using ' $FTP_DATAFILE    >> $LOG_FILE 
   fi
   print " wc file record count is " $DCOUNT                               >> $LOG_FILE 
fi

#################################################################
# compare counts
#################################################################
if [[ $RETCODE == 0 ]]; then 
   if (( $DCOUNT != $PCOUNT )) ; then
       print `date` ' *!!!!!!! counts do not match - arg! trailer:' $PCOUNT ' file: ' $DCOUNT   
       print `date` ' *!!!!!!! counts do not match - arg! trailer:' $PCOUNT ' file: ' $DCOUNT     >> $LOG_FILE 
       RETCODE = 12
   else
       print `date` ' **** counts match okay.  trailer:' $PCOUNT ' file: ' $DCOUNT 
       print `date` ' **** counts match okay.  trailer:' $PCOUNT ' file: ' $DCOUNT      >> $LOG_FILE 
   fi
fi
 
#################################################################
# connect to udb
#################################################################
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING      >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
         print ' !!!! error connecting to db2, retcode ' $RETCODE   
         print ' !!!! error connecting to db2, retcode ' $RETCODE    >> $LOG_FILE 
   fi
fi

#################################################################
# import the data
#################################################################
if [[ $RETCODE == 0 ]]; then 
   cat > $UDB_SQL_FILE << 99EOFSQLTEXT99
import from $FTP_DATAFILE of del modified by coldel|,usedefaults commitcount 1000 warningcount 1 INSERT into $SCHEMA.tpos_claims_$QPID;
99EOFSQLTEXT99
   db2 -stvxf $UDB_SQL_FILE   >> $LOG_FILE   > $UDB_OUTPUT_MSG_FILE
   export RETCODE=$?
   print "import retcode was " $RETCODE
   print "import retcode was " $RETCODE   >> $LOG_FILE 
   cat $UDB_OUTPUT_MSG_FILE              >> $LOG_FILE
fi

#################################################################
# check the actual insert count
#################################################################
if [[ $RETCODE == 0 ]]; then 
       CME_Get_db2_Import_Results $UDB_OUTPUT_MSG_FILE
       print "     Rows Read by Import: "$DB_ROWS_READ                        >> $LOG_FILE
       print " Rows Inserted by Import: "$DB_ROWS_INSERTED                    >> $LOG_FILE
       print " Rows Rejected by Import: "$DB_ROWS_REJECTED                    >> $LOG_FILE
       print "Rows Committed by Import: "$DB_ROWS_COMMITTED                   >> $LOG_FILE
       print " "                                                              >> $LOG_FILE
       if (( $PCOUNT == $DB_ROWS_INSERTED )) ; then
           print "The trailer count  "\($PCOUNT\)                             >> $LOG_FILE
           print "  equals the number of rows inserted via the IMPORT "       >> $LOG_FILE
           print \($DB_ROWS_INSERTED\)"."                                     >> $LOG_FILE
       else
           print "The number of rows extracted "\($PCOUNT\)                   >> $LOG_FILE
           print "  DOES NOT MATCH the number of rows inserted via the "      >> $LOG_FILE
           print "  IMPORT "\($DB_ROWS_INSERTED\)"."                          >> $LOG_FILE
           print "LOAD MISMATCH.  Script will now abend."                     >> $LOG_FILE
           RETCODE=10
       fi
fi


#################################################################
# disconnect from udb
#################################################################
if [[ $RETCODE == 0 ]]; then 
   db2 -stvx connect reset                                                >> $LOG_FILE 
   db2 -stvx quit                                                         >> $LOG_FILE 
fi

echo $SCRIPT " end time: "`date`                                      
echo $SCRIPT " end time: "`date`                                       >> $LOG_FILE 

#################################################################
# send email and return 12 if any errors
#################################################################
if [[ $RETCODE != 0 ]]; then 
   print " !!!!! Aborting " $SCRIPT " due to errors " 
   print " !!!!! Aborting " $SCRIPT " due to errors "                    >> $LOG_FILE 
   EMAIL_SUBJECT=$SCRIPT"_has_abended "
   # feed the log file into the email
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS  < $LOG_FILE
   exit 12
fi

#################################################################
# cleanup from successful run
#################################################################
mv $LOG_FILE       $LOG_ARCH_PATH/ 
mv $FTP_TRIGFILE   $INPUT_ARCH_PATH/$FTP_TRIG_NAME.$TIME_STAMP
mv $FTP_DATAFILE   $INPUT_ARCH_PATH/$FTP_DATA_NAME.$TIME_STAMP
rm -f $UDB_OUTPUT_MSG_FILE
rm -f $UDB_SQL_FILE

print "return_code =" $RETCODE
exit $RETCODE
