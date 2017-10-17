#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR1000_KS_9130J_RPS_purge.ksh
# Title         : RPS Purge 
# Description   : This script will purge one quarter data out of 
#                 the following datamart tables:
#                       rps.ksrb103_inv_lnamt
#			rps.ksrb222_fesump
#			rps.ksrb223_fesumc
#			rps.ksrb250_distr
#			rps.tapc_lcm_summary
#
#                 One datamart table is impacted by the purge on MVS side,
#			rps.trebate_ID_QTR  (derived from dbap1.ksrb112_rbp)
#
#		  The purged quarter summary data should have been copied to 
#		  history tables before run this purge job:
#                       rps.t_inv_lnamt_sum_$YEAR
#                       rps.t_sl_client_pico_sum_$YEAR
#                       rps.ksrb223_$YEAR
#                       rps.t_sl_client_sum_$YEAR
#                       rps.ksrb250_$YEAR
#                       rps.t_claims_$YEAR
#
#                       rps.ksrb106_$YEAR
#                       rps.ksrb108_$YEAR
#                       rps.ksrb110_$YEAR
#                       rps.ksrb111_$YEAR
#                       rps.ksrb112_$YEAR
#                       rps.ksrb210_$YEAR
#
#                       rps.t_rebate_id_qtr_$YEAR
#                       rps.t_rac_qtr_$YEAR
#
#		  This script will be kicked off by MVS job KSZ6250.
# 
# Abends        : 
#                                 
# Parameters    : Period Id (required), eg  2004Q1
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 02-08-08   qcpi03o     Initial Creation.
# 04-08-08   qcpi03o     split the archive steps to seperate job.
# 11-08-11   qcpi03o     Cash Recon change - added table ksrb243
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSOR1000_KS_9130J_RPS_purge.ksh
JOB=RPS_KSOR1000_KS_9130J_RPS_purge
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

RETCODE=0


print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

################################################################
# 1) examine PeriodID parameter  yyyyQn
################################################################
print " input parm was: " $1   
print " input parm was: " $1   >> $LOG_FILE  
YEAR=""
QTR=""
QPARM=""
if [[ $# -eq 1 ]]; then
#   edit supplied parameter
    YEAR=`echo $1 |cut -c 1-4`
    QTR=`echo $1 |cut -c 6-6`
    if (( $YEAR > 1990 && $YEAR < 2050 )); then
      print ' using parameter YEAR of ' $YEAR
    else
      print ' !!! invalid parameter YEAR = ' $YEAR ' !!! Parm format is yyyyQn.  Terminating script '
      print ' !!! invalid parameter YEAR = ' $YEAR ' !!! Parm format is yyyyQn.  Terminating script '  >> $LOG_FILE 
      export RETCODE=12
    fi
    if (( $QTR > 0 && $QTR < 5 )); then
      print ' using parameter QUARTER of ' $QTR
    else
      print ' !!! invalid parameter QUARTER = ' $QTR ' !!! Parm format is yyyyQn. Terminating script '
      print ' !!! invalid parameter QUARTER = ' $QTR ' !!! Parm format is yyyyQn. Terminating script ' >> $LOG_FILE 
      export RETCODE=12
    fi
else
   export RETCODE=12
   print "aborting script - required parameter not supplied " 
   print "aborting script - required parameter not supplied "     >> $LOG_FILE  
fi

QPARM=$YEAR"Q"$QTR
QTR="Q"$QTR
print ' qparm is ' $QPARM
print ' year is ' $YEAR
print ' quarter is ' $QTR

################################################################
# 2) connect to udb
################################################################
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING                                                 >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! terminating script - cant connect to udb " 
      print "!!! terminating script - cant connect to udb "            >> $LOG_FILE  
   fi
fi

################################################################
# 3) Purge table KSRB103_INV_LNAMT
################################################################
if [[ $RETCODE == 0 ]]; then
   print " Starting purge table KSRB103 " `date`                                >> $LOG_FILE

#####backup to flat file before delete
     db2 "export to $TMP_PATH/ksrb103.$QPARM of del select * from rps.ksrb103_inv_lnamt where RBAT_BILL_YR_DT='$YEAR' and RBAT_BILL_QTR_DT='$QTR'"

   sqml --YEAR $YEAR --QPID $QTR $XML_PATH/dm_purge_ksrb103.xml			>> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error purge KSRB103 with return code: "  $RETCODE         >> $LOG_FILE
   fi
fi


################################################################
# 4) Purge table KSRB222_FESUMP
################################################################
if [[ $RETCODE == 0 ]]; then
   print " Starting purge table KSRB222 " `date`                                >> $LOG_FILE

#####backup to flat file before delete
     db2 "export to $TMP_PATH/ksrb222.$QPARM of del select * from rps.ksrb222_fesump where RBAT_BILL_PRD_NM='$QPARM' "

   sqml --QPARM $QPARM  $XML_PATH/dm_purge_ksrb222.xml				>> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error purge KSRB222 with return code: "  $RETCODE         >> $LOG_FILE
   fi
fi


################################################################
# 5) Purge table KSRB223_FESUMC
################################################################
if [[ $RETCODE == 0 ]]; then
   print " Starting purge table KSRB223 " `date`                                >> $LOG_FILE

#####backup to flat file before delete
     db2 "export to $TMP_PATH/ksrb223.$QPARM of del select * from rps.ksrb223_fesumc where RBAT_BILL_PRD_NM='$QPARM' "

   sqml --QPARM $QPARM  $XML_PATH/dm_purge_ksrb223.xml				>> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error purge KSRB223 with return code: "  $RETCODE         >> $LOG_FILE
   fi
fi


################################################################
# 6) Purge table KSRB250_DISTR
################################################################
if [[ $RETCODE == 0 ]]; then
   print " Starting purge table KSRB250 " `date`                                >> $LOG_FILE

#####backup to flat file before delete
     db2 "export to $TMP_PATH/ksrb250.$QPARM of del select * from rps.ksrb250_distr where RBAT_BILL_PRD_NM='$QPARM' "

   sqml --QPARM $QPARM  $XML_PATH/dm_purge_ksrb250.xml				>> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error purge KSRB250 with return code: "  $RETCODE         >> $LOG_FILE
   fi
fi


################################################################
# 7) Purge table KSRB300
################################################################
if [[ $RETCODE == 0 ]]; then
   print " Starting purge table KSRB300 " `date`                                >> $LOG_FILE

#####backup to flat file before delete
     db2 "export to $TMP_PATH/ksrb300.$QPARM of del select * from rps.tapc_lcm_summary where INV_CCYY='$YEAR' and INV_QTR='$QTR' "

   sqml --YEAR $YEAR --QPID $QTR $XML_PATH/dm_purge_ksrb300.xml			>> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error purge KSRB300 with return code: "  $RETCODE         >> $LOG_FILE
   fi
fi


################################################################
# 8) Purge table KSRB243
################################################################
if [[ $RETCODE == 0 ]]; then
   print " Starting purge table KSRB243 " `date`                                >> $LOG_FILE

#####backup to flat file before delete
     db2 "export to $TMP_PATH/ksrb243.$QPARM of del select * from rps.ksrb243_recn_summ where RBAT_BILL_PRD_NM='$QPARM' "

   sqml --QPARM $QPARM $XML_PATH/dm_purge_ksrb243.xml			>> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error purge KSRB243 with return code: "  $RETCODE         >> $LOG_FILE
   fi
fi


################################################################
# zzz) after purge the quarter, set the flag as purged
################################################################
if [[ $RETCODE == 0 ]]; then
   print "setting purged flag in quarter_summary " `date`                                >> $LOG_FILE

   db2 "update rps.quarter_summary set RPS_ACTIVE_IND='3' where PERIOD_ID='$QPARM' "
   export RETCODE=$?

   if [[ $RETCODE != 0 ]]; then
      print "aborting script - error setting purged flag in quarter_summary - with return code: "  $RETCODE   >> $LOG_FILE
   fi
fi


################################################################
# zz) disconnect from udb
################################################################
db2 -stvx connect reset                                                >> $LOG_FILE 
db2 -stvx quit                                                         >> $LOG_FILE 


#################################################################
# send email for script errors
#################################################################
if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "                               >> $LOG_FILE 
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   print "return_code =" $RETCODE
      exit $RETCODE
fi

print " Script " $SCRIPT " completed successfully on " `date`                              
print " Script " $SCRIPT " completed successfully on " `date`            >> $LOG_FILE 

#################################################################
# cleanup from successful run
#################################################################
mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "return_code =" $RETCODE
exit $RETCODE
