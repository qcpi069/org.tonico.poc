#!/bin/ksh
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

function refresh_table
{
   db2 -stvx import from /dev/null of del replace into $SCHEMA.$1  >> $LOG_FILE
   RC=$?
   if [[ $RC != 0 ]]; then
        print " db2 import error truncating table "$1
        print " db2 import error truncating table "$1                  >> $LOG_FILE
        return $RC
   fi

   print "start dm_refresh_$1 "  `date`
   print "start dm_refresh_$1 "  `date`                               >> $LOG_FILE

   sqml $XML_PATH/dm_refresh_$1.xml                                    >> $LOG_FILE
   RC=$?
   print "retcode from dm_refresh_$1  " $RC "   "`date`
   print "retcode from dm_refresh_$1  " $RC "   "`date`              >> $LOG_FILE
   return $RC
}

SCRIPT=RPS_RIMN0024_RI_0024J_dm_refresh
JOB=M010J
TBLNAME=$1
LOG_FILE=$LOG_PATH/RIMN0024_dm_refresh.$TBLNAME.$TIME_STAMP.log
DBMSG_FILE=$LOG_PATH/$TBLNAME.$TIME_STAMP.db2msg.log
RETCODE=0

echo $SCRIPT " start time: "`date`
echo $SCRIPT " start time: "`date`                                     > $LOG_FILE

#
# connect to udb
#
if [[ $RETCODE == 0 ]]; then
   $UDB_CONNECT_STRING                                                 >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting dm_refresh - cant connect to udb "
      print "aborting dm_refresh - cant connect to udb "               >> $LOG_FILE
   fi
fi


if [[ $RETCODE == 0 ]]; then
    
    refresh_table $1
    export RETCODE=$?
fi

#
# disconnect from udb
#
db2 -stvx connect reset                                                >> $LOG_FILE
db2 -stvx quit                                                         >> $LOG_FILE


echo $SCRIPT " end time: "`date`
echo $SCRIPT " end time: "`date`                                       >> $LOG_FILE

#
# send email for script errors
#
if [[ $RETCODE != 0 ]]; then
   print "aborting $SCRIPT due to errors "
   print "aborting $SCRIPT due to errors "                          >> $LOG_FILE
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   exit $RETCODE
fi

mv $LOG_FILE $LOG_ARCH_PATH/
print "return_code =" $RETCODE
exit $RETCODE

