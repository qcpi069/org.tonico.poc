#!/bin/ksh
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

function refresh_table
{
   print 'starting import from dev-null for '$SCHEMA'.'$RPS_TABLE          >> $LOG_FILE
   db2 -stvx import from /dev/null of del replace into $SCHEMA.$RPS_TABLE  >> $LOG_FILE
   RC=$?
   if [[ $RC != 0 ]]; then
        print " db2 import error truncating table "$RPS_TABLE              >> $LOG_FILE
        return $RC
   fi


   print '============ ' $DBMSG_FILE '======start=========='               >> $LOG_FILE
   cat $DBMSG_FILE                                                         >> $LOG_FILE
   print '============ ' $DBMSG_FILE '======end=========='                 >> $LOG_FILE
   

   print "start dm_refresh_$XML_SCRIPT "  `date`                           >> $LOG_FILE

   sqml $XML_PATH/$XML_SCRIPT                                              >> $LOG_FILE
   RC=$?
   print "retcode from dm_refresh_$XML_SCRIPT " $RC "   "`date`            >> $LOG_FILE
   return $RC
}

ZEUS_TABLE=$1
JOB=$2
SCRIPT=RPS_RIMN00024_Load_QL_Plan_Design_Tables
DBMSG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.db2msg.log
RPS_TABLE='TQL_'$ZEUS_TABLE
XML_SCRIPT='dm_refresh_'$RPS_TABLE'.xml'
LOG_FILE=$LOG_PATH/$XML_SCRIPT.$JOB.$TIME_STAMP.log
LOG_ARCH_FILE=$LOG_ARCH_PATH/$XML_SCRIPT.$JOB.$TIME_STAMP.log
SCHEMA=RPS
RETCODE=0
echo 'ZEUS_TABLE = ' $ZEUS_TABLE >> $LOG_FILE
echo 'JOB = ' $JOB >> $LOG_FILE
echo 'SCRIPT = ' $SCRIPT >> $LOG_FILE
echo 'DBMSG_FILE = ' $DBMSG_FILE >> $LOG_FILE
echo 'RPS_TABLE = ' $RPS_TABLE >> $LOG_FILE
echo 'XML_SCRIPT = ' $XML_SCRIPT >> $LOG_FILE
echo 'LOG_FILE = ' $LOG_FILE >> $LOG_FILE

echo $SCRIPT " start time: "`date`                                     >> $LOG_FILE

#
# connect to udb
#
if [[ $RETCODE == 0 ]]; then
   $UDB_CONNECT_STRING                                                 >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting $SCRIPT - cant connect to udb "                  >> $LOG_FILE
   fi
fi


if [[ $RETCODE == 0 ]]; then
    refresh_table
    export RETCODE=$?
fi

#
# disconnect from udb
#
db2 -stvx connect reset                                                >> $LOG_FILE
db2 -stvx quit                                                         >> $LOG_FILE


echo $SCRIPT " end time: "`date`                                       >> $LOG_FILE

#
# send email for script errors
#
if [[ $RETCODE != 0 ]]; then
   print "aborting $SCRIPT due to errors "                          >> $LOG_FILE
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   exit $RETCODE
fi


print "return_code =" $RETCODE                                      >> $LOG_FILE
mv $LOG_FILE $LOG_ARCH_FILE
exit $RETCODE
