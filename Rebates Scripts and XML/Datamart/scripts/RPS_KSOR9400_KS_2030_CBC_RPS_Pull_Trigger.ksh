#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR9400_KS_2030_CBC_RPS_Pull_Trigger.ksh
# Title         : Capital BC Custom Payment Report - RPS pull trigger job
# Description   : This script will read from Payments process control table
#                 ksrb250, if the list of Rebate IDs processed in the past 
#                 day are in the CBC control table, kick off RPS pull job.
#                          RPS_KSOR9400_KS_2030_CBC_RPS_Pull_Trigger.ksh
#
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
# 02-18-11   qcpi03o     Initial Creation.
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
# 2) check if we have CBC rebate IDs processed in the past day
################################################################

if [[ $RETCODE == 0 ]]; then 
    db2 -px "select count(*) from
                (select prcs_nb,be_id
                        from rps.ksrb250_distr
                        where prcs_nb in
                                (select prcs_nb from rps.ksz6005_pcntl_trk
                                        where prcs_typ_cd = 23
                                        and prcs_end_ts > current timestamp - 1 days
                                        and prcs_stat_cd = 'C')
                        and obj_stat_cd = 'C'
                        and be_id in (select distinct RBAT_ID from rps.CBC_control)
                ) as prcsed
				" |read RBATE_CNT
RETCODE=$?
fi

   print "Step 2 completed - check if we have CBC rebate IDs processed in the past day "    >> $LOG_FILE


################################################################
# 3) if CBC rbate_id processed in the past day, kick off RPS Pull
################################################################

if [[ $RBATE_CNT > 0 ]]; then 
   . RPS_KSOR9400_KS_2020_CBC_RPS_LKP.ksh

   RETCODE=$?
   print "Step 3 completed - Kick Off RPS data Pull job "        >> $LOG_FILE
fi

   print "Step 3 completed - no CBC rbate_id processed in the past day "        >> $LOG_FILE

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
