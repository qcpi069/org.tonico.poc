#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR9400_KS_9480J_bld_clntsum.ksh
# Title         : Invoice Load - Build Client Sum
# Description   : This script will populate the client sum table which 
#                 is derived from the drug-client sum invoice data. 
#                 It also populates TAPC_SUM for the quarter.
# 
# Abends        : 
#                                 
#
# Parameters    : YYYYQN   (period id designator, year and quarter)
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-23-06   is89501     Initial Creation.
# 10-02-06   is89501     add update of Quarter Summary table
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSOR9400_KS_9480J_bld_clntsum.ksh
JOB=ks9480j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
DBMSG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.db2msg.log
DCDATA=$DBLOAD_PATH/clsum.tmp
DCSQL=$TMP_PATH/$JOB.sql
RETCODE=0

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

#
# examine Quarter parameter  YYYY4Q
#
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
      print ' !!! invalid parameter YEAR = ' $YEAR ' !!! Parm format is YYYYQN.  Terminating script '
      print ' !!! invalid parameter YEAR = ' $YEAR ' !!! Parm format is YYYYQN.  Terminating script '  >> $LOG_FILE 
      export RETCODE=12
    fi
    if (( $QTR > 0 && $QTR < 5 )); then
      print ' using parameter QUARTER of ' $QTR
    else
      print ' !!! invalid parameter QUARTER = ' $QTR ' !!! Parm format is YYYYQN. Terminating script '
      print ' !!! invalid parameter QUARTER = ' $QTR ' !!! Parm format is YYYYQN. Terminating script ' >> $LOG_FILE 
      export RETCODE=12
    fi
else
   export RETCODE=12
   print "aborting script - required parameter not supplied " 
   print "aborting script - required parameter not supplied "     >> $LOG_FILE  
fi
QPARM=$YEAR"Q"$QTR
print ' qparm is ' $QPARM
print ' year is ' $YEAR


#
# build tapc_sum for quarter
#
if [[ $RETCODE == 0 ]]; then 
  sqml --QPID $QPARM $XML_PATH/dm_calc_apc_sum_fixGNRC.xml                               
  export RETCODE=$?
  print `date`"sqml retcode was " $RETCODE " for build of TAPC_SUM period " $QPARM 
  print `date`"sqml retcode was " $RETCODE " for build of TAPC_SUM period " $QPARM  >> $LOG_FILE
fi





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

rm -f $DBMSG_FILE* 
rm -f $DCDATA
rm -f $DCSQL

mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "return_code =" $RETCODE
exit $RETCODE

