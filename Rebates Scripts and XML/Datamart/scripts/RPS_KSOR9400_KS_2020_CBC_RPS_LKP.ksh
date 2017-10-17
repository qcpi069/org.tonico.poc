#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR9400_KS_2020_CBC_RPS_LKP.ksh
# Title         : Capital BC Custom Payment Report - RPS pull job
# Description   : This script will pull rps lookup info from Payments,
#                 using client apc claim set to limit the dataset.
#                 the following tables will be updated:
#                       rps.CBC_RPS_LKP
#
#         	  Up to 17 quarters of rebated claims will be stored in 
#         	  table rps.CBC_CLM_DTL with client requested CDD data.
#
#		  view CBC_REPORTING will join CBC_CLM_DTL and CBC_RPS_LKP
#                 as the base for CBC Custom Payment Report.
#
#         	  This script will be kicked off by 
#                          RPS_KSOR9400_KS_2030_CBC_RPS_Pull_Trigger.ksh
# 
# Abends        : 
#                                 
# Parameters    : none
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 02-15-11   qcpi03o     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH


SCRIPT=$(basename "$0")
JOB=$(echo $SCRIPT|awk -F. '{print $1}')
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

RETCODE=0

RBATE_CNT=$TMP_PATH/CBC.rebate
PERIOD_CNT=$TMP_PATH/CBC.period

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                                       > $LOG_FILE


################################################################
# 1) connect to udb
################################################################
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING                                                         >> $LOG_FILE 
   RETCODE=$?
   print "Step 1 completed - connect to db "                                   >> $LOG_FILE
   if [[ $RETCODE != 0 ]]; then 
      print "!!! terminating script - cant connect to udb " 
      print "!!! terminating script - cant connect to udb "                    >> $LOG_FILE  
   fi
fi

################################################################
#     truncate CBC_RPS_LKP for a full repull from Payments
################################################################
   if [[ $RETCODE == 0 ]]; then
    db2 -px "import from /dev/null of del replace into rps.CBC_RPS_LKP"
   RETCODE=$?
   fi


################################################################
# 2) read Rebate ID/inv_qtr from control table
################################################################

if [[ $RETCODE == 0 ]]; then 
    db2 -px "select distinct RBAT_ID from rps.cbc_control" > $RBATE_CNT
RETCODE=$?
fi

if [[ $RETCODE == 0 ]]; then
        db2 -px "select distinct INV_QTR from rps.cbc_control where inv_qtr>'2009Q1'" > $PERIOD_CNT
RETCODE=$?
fi

   print "Step 2 completed - read RebateID/inv_qtr from control table "    >> $LOG_FILE


################################################################
# 3) for each RebateID/inv_qtr, extract ksrb220
################################################################


while read RBATE; do

   while read QPARM; do

    if [[ $RETCODE == 0 ]]; then
    sqml --QPARM $QPARM --RBATE $RBATE $XML_PATH/CBC_ksrb220.xml        >> $LOG_FILE
    RETCODE=$?
    fi

   done <$PERIOD_CNT
done <$RBATE_CNT


   print "Step 3 completed - pull Payments ksrb220 into CBC_RPS_LKP "        >> $LOG_FILE

################################################################
# 4) for each rbate_id/inv_qtr, extract ksrb221
################################################################
while read RBATE; do

   while read QPARM; do

    if [[ $RETCODE == 0 ]]; then
    sqml --QPARM $QPARM --RBATE $RBATE $XML_PATH/CBC_ksrb221.xml        >> $LOG_FILE
    RETCODE=$?
    fi

   done <$PERIOD_CNT
done <$RBATE_CNT

   print "Step 4 completed - pull Payments ksrb221 into CBC_RPS_LKP"   >> $LOG_FILE

################################################################
# 5) resolve stmt_id field for table CBC_RPS_LKP
################################################################

    if [[ $RETCODE == 0 ]]; then
    sqml  $XML_PATH/CBC_rps_lkp_stmt.xml        >> $LOG_FILE
    RETCODE=$?
    fi

   print "Step 5 completed - update stmt_id field in CBC_RPS_LKP"   >> $LOG_FILE

################################################################
# zz) disconnect from udb
################################################################
db2 -stvx connect reset                                                        >> $LOG_FILE 
db2 -stvx quit                                                                 >> $LOG_FILE 

#################################################################
# send email for script errors
#################################################################
if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "                                     >> $LOG_FILE 
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   print "return_code =" $RETCODE

   exit $RETCODE
fi

print " Script " $SCRIPT " completed successfully on " `date`                              
print " Script " $SCRIPT " completed successfully on " `date`                  >> $LOG_FILE 


#################################################################
# cleanup from successful run
#################################################################
mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "return_code =" $RETCODE
exit $RETCODE
