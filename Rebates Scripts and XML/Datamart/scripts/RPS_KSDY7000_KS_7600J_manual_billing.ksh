#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSDY7000_KS_7600J_manual_billing.ksh
# Title         : Pull APC data for mainframe processing
#
# Description   : This script will pull APC data for manual billing  
#                 and insert to the mainframe payment system for
#                 batch processing.
# 
# Abends        : If select count does not match insert results then set bad	
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
# 02-06-06   qcpi768     Initial Creation.
# 09-29-06   qcpi030     change to pull by prcs_nb/inv_qtr from apc tables
#                        instead of view to improve performance
# 10-22-10   qcpi03o     CaRe2010 - add logic to use new xml
#				to pull from ksrb241
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSDY7000_KS_7600J_manual_billing
JOB=ks7600j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

if [[ $# -eq 1 ]]; then
#   read prcs_nb 
        PRCS_NB=$1
        export RETCODE=$?
else
   export RETCODE=12
   print "aborting script - required parameter not supplied "
   print "usage: RPS_KSDY7000_KS_7600J_manual_billing.ksh prcs_nb"
   print "aborting script - required parameter not supplied "     >> $LOG_FILE
fi

#
# connect to udb
#
if [[ $RETCODE == 0 ]]; then
   $UDB_CONNECT_STRING                                                 >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then
      print "!!! aborting  - cant connect to udb "
      print "!!! aborting  - cant connect to udb "               >> $LOG_FILE
   fi
fi

if [[ $RETCODE == 0 ]];then
  sql="select count(*) from $MF_SCHEMA.ksrb235_apc_stage "
  db2 -stx "$sql" | read ICOUNT
  export RETCODE=$?
fi

if [[ $RETCODE == 0 ]];then
  sql="select PRCS_REF_TRAN_ID from $MF_SCHEMA.KSZ6005_PCNTL_TRK where prcs_nb=$PRCS_NB "
  db2 -stx "$sql" | read REF_PRCS
  export RETCODE=$?
fi


if [[ $REF_PRCS == 0 ]];then
#############################################################################################
##      original data pull - prior to 12/02/2010
#############################################################################################
if [[ $RETCODE == 0 ]];then
  sql="select distinct rbat_bill_prd_nm from $MF_SCHEMA.ksrb230_rbll_stage 
	where tran_typ_cd in ('M','E')
	and prcs_nb=$PRCS_NB "
  db2 -stx "$sql" > ks7600j.period
  export RETCODE=$?
fi

if [[ $RETCODE == 0 ]];then
while read QTR; do

   print "pull for prcs_nb $PRCS_NB quarter $QTR......"     
   print "pull for prcs_nb $PRCS_NB quarter $QTR......"               >> $LOG_FILE

  sqml --PRCS_NB $PRCS_NB --QTR $QTR $XML_PATH/mf_load_ksrb235.xml              >> $LOG_FILE
  export RETCODE=$?
  tail sqml.log

done < ks7600j.period
fi
 
#############################################################################################
else
#############################################################################################
##      Cash Recon change 12/02/2010 - pull data from ksrb241
##      when KSZ6005_PCNTL_TRK.PRCS_REF_TRAN_ID for the prcs_nb is non-zero
#############################################################################################

if [[ $RETCODE == 0 ]];then
  sql="select distinct rbat_bill_prd_nm from $MF_SCHEMA.KSRB242_RECN_CLM_DTL 
	where tran_typ_cd in ('M','E')
	and prcs_nb=$PRCS_NB "
  db2 -stx "$sql" > ks7600j.period
  export RETCODE=$?
fi

if [[ $RETCODE == 0 ]];then
while read QTR; do

   print "pull for prcs_nb $PRCS_NB quarter $QTR......"     
   print "pull for prcs_nb $PRCS_NB quarter $QTR......"               >> $LOG_FILE

  sqml --PRCS_NB $PRCS_NB --QTR $QTR $XML_PATH/mf_load_ksrb235_cash.xml              >> $LOG_FILE
  export RETCODE=$?
  tail sqml.log

done < ks7600j.period
fi
 
#############################################################################################
##      end fork
#############################################################################################
fi

#############################################################################################
##      count total rows inserted into ksrb235_apc_stage
#############################################################################################

if [[ $RETCODE == 0 ]];then
  sql="select count(*) from $MF_SCHEMA.ksrb235_apc_stage "
  db2 -stx "$sql" | read FCOUNT
  ACOUNT=`expr $FCOUNT - $ICOUNT`
  print " *********************************************** "          >> $LOG_FILE
  printf " * Rows inserted into KSRB235 is %09d \n "  $ACOUNT        >> $LOG_FILE
  print " *********************************************** "          >> $LOG_FILE
  export RETCODE=$?
fi

if [[ $RETCODE != 0 ]];then
   print "load to KSRB235 failed, return-code = " $RETCODE           >> $LOG_FILE
   tail sqml.log                                                     >> $LOG_FILE
fi
 
#################################################################
# send email for script errors
#################################################################
if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "                               >> $LOG_FILE 
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   print "PRCS_NB =" $PRCS_NB
   print "return_code =" $RETCODE
   exit $RETCODE
fi

print " Script " $SCRIPT " completed successfully on " `date`                              
print " Script " $SCRIPT " completed successfully on " `date`            >> $LOG_FILE 

#################################################################
# dump this log to sysout for mainframe jes output
#################################################################
cat $LOG_FILE 

#################################################################
# cleanup from successful run
#################################################################
mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "PRCS_NB =" $PRCS_NB
print "return_code =" $RETCODE
exit $RETCODE
