#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR9400_KS_9460J_bld_drgclntsum.ksh
# Title         : Invoice Load - Build Drug Client Sum
# Description   : This script will build the drug client sum table which 
#                 is derived from the quarterly APC invoice data.
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
#
# 02-23-07   qcpi03o     update summary to group by pmt_sys_elig_cd field
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSOR9400_KS_9460J_bld_drgclntsum.ksh
JOB=ks9460j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
DBMSG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.db2msg.log
DCDATA=$DBLOAD_PATH/dcsum.tmp
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
      print ' !!! invalid parameter YEAR = ' $YEAR ' !!! Parm format is YYYY4Q.  Terminating script '
      print ' !!! invalid parameter YEAR = ' $YEAR ' !!! Parm format is YYYY4Q.  Terminating script '  >> $LOG_FILE 
      export RETCODE=12
    fi
    if (( $QTR > 0 && $QTR < 5 )); then
      print ' using parameter QUARTER of ' $QTR
    else
      print ' !!! invalid parameter QUARTER = ' $QTR ' !!! Parm format is YYYY4Q. Terminating script '
      print ' !!! invalid parameter QUARTER = ' $QTR ' !!! Parm format is YYYY4Q. Terminating script ' >> $LOG_FILE 
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
# connect to udb
#
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING                                             >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "aborting script - cant connect to udb " 
      print "aborting script - cant connect to udb "               >> $LOG_FILE  
   fi
fi


#
# create sql file
#
cat > $DCSQL << EOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE SELECT PERIOD_ID,
   rbate_id,
   extnl_src_code,
   extnl_lvl_id1,
   extnl_lvl_id2,
   extnl_lvl_id3,
   lcm_code,
   pico_no,
   ndc,
   SUBSTR(ndc,1,5),
   substr(ndc,6,4),
   substr(ndc,10,2),
   COUNT(*) ,
   SUM(CASE WHEN claim_type='+1' THEN 1 
            WHEN claim_type='  ' THEN 1 
            WHEN claim_type='-1' THEN -1 
            ELSE 0 END),
   SUM(CASE WHEN mail_order_code='0'  
            THEN (CASE WHEN claim_type='+1' THEN 1
	               WHEN claim_type='  ' THEN 1 
		       ELSE -1 END) 
            ELSE 0 END),
   SUM(CASE WHEN mail_order_code='1'  
            THEN (CASE WHEN claim_type='+1' THEN 1
	               WHEN claim_type='  ' THEN 1
	                ELSE -1 END) 
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' 
            THEN (CASE WHEN (rbate_access+rbate_mrkt_shr)>0 THEN 1 
                       WHEN (rbate_access+rbate_mrkt_shr)<0 THEN -1 
                       ELSE 0 END)  
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='0' 
            THEN (CASE WHEN (rbate_access+rbate_mrkt_shr)>0 THEN 1 
                       WHEN (rbate_access+rbate_mrkt_shr)<0 THEN -1 
                       ELSE 0 END)  
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='1' 
            THEN (CASE WHEN (rbate_access+rbate_mrkt_shr)>0 THEN 1 
                       WHEN (rbate_access+rbate_mrkt_shr)<0 THEN -1 
                       ELSE 0 END) 
   ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND rbate_admin_fee>0 THEN 1 
            WHEN excpt_stat='R' AND rbate_admin_fee<0 THEN -1 
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='0' 
            THEN (CASE WHEN rbate_admin_fee>0 THEN 1  
                       WHEN rbate_admin_fee<0 THEN -1 
                       ELSE 0 END)  
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='1' 
            THEN (CASE WHEN rbate_admin_fee>0 THEN 1  
                       WHEN rbate_admin_fee<0 THEN -1  
                       ELSE 0 END) 
            ELSE 0 END),
   SUM(unit_qty),
   SUM(CASE WHEN mail_order_code ='0' THEN unit_qty ELSE 0 END),
   SUM(CASE WHEN mail_order_code ='1' THEN unit_qty ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND (rbate_access+rbate_mrkt_shr)<>0 THEN unit_qty 
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='0' AND (rbate_access+rbate_mrkt_shr)<>0 THEN unit_qty 
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='1' AND (rbate_access+rbate_mrkt_shr)<>0 THEN unit_qty 
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND rbate_admin_fee<>0 THEN unit_qty 
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='0' AND rbate_admin_fee<>0 THEN unit_qty 
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='1' AND rbate_admin_fee<>0 THEN unit_qty 
            ELSE 0 END),
   SUM(ingrd_cst),
   SUM(CASE WHEN mail_order_code='0' THEN ingrd_cst ELSE 0 END),
   SUM(CASE WHEN mail_order_code='1' THEN ingrd_cst ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND (rbate_access+rbate_mrkt_shr)<>0 THEN ingrd_cst 
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='0' AND (rbate_access+rbate_mrkt_shr)<>0 THEN ingrd_cst 
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='1' AND (rbate_access+rbate_mrkt_shr)<>0 THEN ingrd_cst 
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND rbate_admin_fee<>0 THEN ingrd_cst 
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='0' AND rbate_admin_fee<>0 THEN ingrd_cst 
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='1' AND rbate_admin_fee<>0 THEN ingrd_cst 
            ELSE 0 END),
 
   round(SUM(double(awp_unit_cst)*double(unit_qty)),2),
   round(SUM(CASE WHEN mail_order_code='0' THEN (double(awp_unit_cst)*double(unit_qty)) ELSE 0 END),2),
   round(SUM(CASE WHEN mail_order_code='1' THEN (double(awp_unit_cst)*double(unit_qty)) ELSE 0 END),2),
   round(SUM(CASE WHEN excpt_stat='R' AND (rbate_access+rbate_mrkt_shr)<>0 THEN (double(awp_unit_cst)*double(unit_qty)) 
            ELSE 0 END),2),
   round(SUM(CASE WHEN excpt_stat='R' AND mail_order_code='0' AND (rbate_access+rbate_mrkt_shr)<>0 THEN (double(awp_unit_cst)*double(unit_qty)) 
            ELSE 0 END),2),
   round(SUM(CASE WHEN excpt_stat='R' AND mail_order_code='1' AND (rbate_access+rbate_mrkt_shr)<>0 THEN (double(awp_unit_cst)*double(unit_qty)) 
            ELSE 0 END),2),
   round(SUM(CASE WHEN excpt_stat='R' AND rbate_admin_fee<>0 THEN (double(awp_unit_cst)*double(unit_qty)) 
            ELSE 0 END),2),
   round(SUM(CASE WHEN excpt_stat='R' AND mail_order_code = '0' AND rbate_admin_fee<>0 THEN (double(awp_unit_cst)*double(unit_qty)) 
            ELSE 0 END),2),
   round(SUM(CASE WHEN excpt_stat='R' AND mail_order_code = '1' AND rbate_admin_fee<>0 THEN (double(awp_unit_cst)*double(unit_qty)) 
            ELSE 0 END),2),
  
   SUM(rbate_access),
   SUM(CASE WHEN mail_order_code='0' THEN rbate_access ELSE 0 END),
   SUM(CASE WHEN mail_order_code='1' THEN rbate_access ELSE 0 END),
   SUM(rbate_mrkt_shr),
   SUM(CASE WHEN mail_order_code='0' THEN rbate_mrkt_shr ELSE 0 END),
   SUM(CASE WHEN mail_order_code='1' THEN rbate_mrkt_shr ELSE 0 END),
   SUM(rbate_admin_fee),
   SUM(CASE WHEN mail_order_code='0' THEN rbate_admin_fee ELSE 0 END),
   SUM(CASE WHEN mail_order_code='1' THEN rbate_admin_fee ELSE 0 END),
   SUM(CASE WHEN gnrc_ind in ('0') AND (rbate_access+rbate_mrkt_shr)>0 THEN 1 
            WHEN gnrc_ind in ('0') AND (rbate_access+rbate_mrkt_shr)<0 THEN -1 
            ELSE 0 END),
   SUM(CASE WHEN gnrc_ind in ('0') AND claim_type='+1' THEN 1 
            WHEN gnrc_ind in ('0') AND claim_type='-1' THEN -1 
            ELSE 0 END),
   SUM(CASE WHEN clm_use_srx_cd='1' AND gnrc_ind in ('0') AND (rbate_access+rbate_mrkt_shr)>0 THEN 1 
            WHEN clm_use_srx_cd='1' AND gnrc_ind in ('0') AND (rbate_access+rbate_mrkt_shr)<0 THEN -1 
            ELSE 0 END),
   SUM(CASE WHEN clm_use_srx_cd='1' AND gnrc_ind in ('0') AND claim_type='+1' THEN 1 
            WHEN clm_use_srx_cd='1' AND gnrc_ind in ('0') AND claim_type='  ' THEN 1 
            WHEN clm_use_srx_cd='1' AND gnrc_ind in ('0') AND claim_type='-1' THEN -1 
            ELSE 0 END),
   SUM(CASE WHEN user_field6_flg='1' AND gnrc_ind in ('0') AND (rbate_access+rbate_mrkt_shr)>0 THEN 1 
            WHEN user_field6_flg='1' AND gnrc_ind in ('0') AND (rbate_access+rbate_mrkt_shr)<0 THEN -1  
            ELSE 0 END),
   SUM(CASE WHEN user_field6_flg='1' AND gnrc_ind in ('0') AND claim_type='+1' THEN 1 
            WHEN user_field6_flg='1' AND gnrc_ind in ('0') AND claim_type='  ' THEN 1 
            WHEN user_field6_flg='1' AND gnrc_ind in ('0') AND claim_type='-1' THEN -1 
            ELSE 0 END), 
   SUM(CASE WHEN clm_use_srx_cd='1' AND gnrc_ind in ('0','1') AND (rbate_access+rbate_mrkt_shr)>0 THEN 1 
            WHEN clm_use_srx_cd='1' AND gnrc_ind in ('0','1') AND (rbate_access+rbate_mrkt_shr)<0 THEN -1 
            ELSE 0 END),
   SUM(CASE WHEN clm_use_srx_cd='1' AND gnrc_ind in ('0','1') and  claim_type='+1' THEN 1 
            WHEN clm_use_srx_cd='1' AND gnrc_ind in ('0','1') and  claim_type='  ' THEN 1 
            WHEN clm_use_srx_cd='1' AND gnrc_ind in ('0','1') and  claim_type='-1' THEN -1 
            ELSE 0 END),
   SUM(CASE WHEN user_field6_flg='1' AND gnrc_ind in ('0','1') AND (rbate_access+rbate_mrkt_shr)>0 THEN 1 
            WHEN user_field6_flg='1' AND gnrc_ind in ('0','1') AND (rbate_access+rbate_mrkt_shr)<0 THEN -1 
            ELSE 0 END),
   SUM(CASE WHEN user_field6_flg='1' AND gnrc_ind in ('0','1') AND claim_type='+1' THEN 1 
            WHEN user_field6_flg='1' AND gnrc_ind in ('0','1') AND claim_type='  ' THEN 1 
            WHEN user_field6_flg='1' AND gnrc_ind in ('0','1') AND claim_type='-1' THEN -1 
            ELSE 0 END),
   SUM(CASE when gnrc_ind in ('0') AND mail_order_code='0' AND claim_type='+1' THEN 1 
            when gnrc_ind in ('0') AND mail_order_code='0' AND claim_type='  ' THEN 1 
            when gnrc_ind in ('0') AND mail_order_code='0' AND claim_type='-1' THEN -1 
            ELSE 0 END) ,
   SUM(CASE when gnrc_ind in ('0') AND mail_order_code='1' AND claim_type='+1' THEN 1 
            when gnrc_ind in ('0') AND mail_order_code='1' AND claim_type='  ' THEN 1 
            when gnrc_ind in ('0') AND mail_order_code='1' AND claim_type='-1' THEN -1 
            ELSE 0 END),
   SUM(CASE when excpt_stat='R' AND clm_use_srx_cd='1' THEN (rbate_access+rbate_mrkt_shr) ELSE 0 END),
   SUM(CASE when excpt_stat='R' AND user_field6_flg='1' THEN (rbate_access+rbate_mrkt_shr) ELSE 0 END),
   SUM(CASE when excpt_stat='R' AND clm_use_srx_cd='1' THEN rbate_admin_fee ELSE 0 END),
   SUM(CASE when excpt_stat='R' AND user_field6_flg='1' THEN rbate_admin_fee ELSE 0 END)
   , pmt_sys_elig_cd
    FROM RPS.TAPC_DETAIL_$QPARM 
    WHERE extnl_src_code='QLC' and (excpt_stat IN ('P','R') 
    OR excpt_code IN ('BQ','BG','BM','BR','FA','FE','FT'))
    GROUP BY period_id,rbate_id,extnl_src_code,extnl_lvl_id1,extnl_lvl_id2,extnl_lvl_id3,lcm_code,pico_no,ndc,SUBSTR(ndc,1,5),substr(ndc,6,4),substr(ndc,10,2),pmt_sys_elig_cd;
EOF

print " *** sql being used is: "                                     >> $LOG_FILE  
print `cat $DCSQL`                                                   >> $LOG_FILE  
print " *** end of sql display.                   "                  >> $LOG_FILE  


#
# extract to file
#
if [[ $RETCODE == 0 ]]; then 
   db2 -tvf $DCSQL 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "aborting script - error extracting data " 
      print "aborting script - error extracting data "               >> $LOG_FILE  
   fi
fi


#
# chmod it so db2 load can see it 
#
if [[ $RETCODE == 0 ]]; then 
   chmod 777 $DCDATA                                                 >> $LOG_FILE
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "aborting script - cant chmod " $DCDATA 
      print "aborting script - cant chmod " $DCDATA                  >> $LOG_FILE  
   fi
fi


#
# load db2
#
if [[ $RETCODE == 0 ]]; then 
   print " Starting db2 load " `date`                              
   print " Starting db2 load " `date`                                >> $LOG_FILE
   db2 "import from $DCDATA of del modified by coldel| commitcount 5000  messages $DBMSG_FILE insert into rps.tapc_drug_client_sum_$YEAR "   >> $LOG_FILE  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "aborting script - error loading db2 with " $DCDATA " return code: "  $RETCODE 
      print "aborting script - error loading db2 with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE  
      print " WARNING - LOAD TERMINATE ACTION IS REQUIRED!!! "           >> $LOG_FILE  
   fi 
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

