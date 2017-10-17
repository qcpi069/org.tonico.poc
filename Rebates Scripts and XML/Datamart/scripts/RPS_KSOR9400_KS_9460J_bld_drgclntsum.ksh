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
# 02-23-12   qcpy987     update specialty count logic - ITPR002957
#		         for CLM_USE_SPX_CD in ('1','2','3','4'), count as specialty.
# 01-26-11   qcpi03o     update specialty count logic - BSR 57899
#		         for CLM_USE_SPX_CD in ('1','2','3'), count as specialty.
# 07-29-10   qcpi03o     update QLC brand count logic to use field CALC_BRND_XLAT_CD
#                        instead of GNRC_IND.
# 07-29-09   qcpi733     Added GDX APC status updates; removed export command
#                        from RETCODE assignments.
# 03-23-06   is89501     Initial Creation.
#
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
DCDATA=$TMP_PATH/dcsum.tmp
DCSQL=$TMP_PATH/$JOB.sql

APC_INIT=./APC.init

RETCODE=0
 
print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

#Call the APC status update
. `dirname $0`/RPS_GDX_APC_Status_update.ksh 250 STRT                          >> $LOG_FILE

#
# read Quarter parameter  YYYY4Q from APC.init file
#
if [[ ! -f $APC_INIT ]]; then
      print "aborting script - required file " $APC_INIT " is not present " 
      print "aborting script - required file " $APC_INIT " is not present "    >> $LOG_FILE  
      RETCODE=12
else
    read QPARM < $APC_INIT
    YEAR=`echo $QPARM|cut -c 1-4`
fi

#
# connect to udb
#
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING                                             >> $LOG_FILE 
   RETCODE=$?
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
            WHEN claim_type='-1' THEN -1 
            ELSE 0 END),
   SUM(CASE WHEN mail_order_code='0'  
            THEN (CASE WHEN claim_type='+1' THEN 1 
                       WHEN claim_type='-1' THEN -1
                       ELSE 0 END) 
            ELSE 0 END),
   SUM(CASE WHEN mail_order_code='1'  
            THEN (CASE WHEN claim_type='+1' THEN 1 
                       WHEN claim_type='-1' THEN -1
                       ELSE 0 END)
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' 
            THEN (CASE WHEN (rbate_access+rbate_mrkt_shr)>0 THEN (CASE WHEN claim_type='+1' THEN 1 
                                                                       WHEN claim_type='-1' THEN -1
                                                                       ELSE 0 END)
                       WHEN (rbate_access+rbate_mrkt_shr)<0 THEN (CASE WHEN claim_type='+1' THEN 1 
                                                                       WHEN claim_type='-1' THEN -1
                                                                       ELSE 0 END)
                       ELSE 0 END)  
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='0' 
            THEN (CASE WHEN (rbate_access+rbate_mrkt_shr)>0 THEN (CASE WHEN claim_type='+1' THEN 1 
                                                                       WHEN claim_type='-1' THEN -1
                                                                       ELSE 0 END)
                       WHEN (rbate_access+rbate_mrkt_shr)<0 THEN (CASE WHEN claim_type='+1' THEN 1 
                                                                       WHEN claim_type='-1' THEN -1
                                                                       ELSE 0 END)
                       ELSE 0 END)  
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='1' 
            THEN (CASE WHEN (rbate_access+rbate_mrkt_shr)>0 THEN (CASE WHEN claim_type='+1' THEN 1 
                                                                       WHEN claim_type='-1' THEN -1
                                                                       ELSE 0 END)
                       WHEN (rbate_access+rbate_mrkt_shr)<0 THEN (CASE WHEN claim_type='+1' THEN 1 
                                                                       WHEN claim_type='-1' THEN -1
                                                                       ELSE 0 END)
                       ELSE 0 END) 
   ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND rbate_admin_fee>0 THEN (CASE WHEN claim_type='+1' THEN 1 
                                                                 WHEN claim_type='-1' THEN -1
                                                                 ELSE 0 END)
            WHEN excpt_stat='R' AND rbate_admin_fee<0 THEN (CASE WHEN claim_type='+1' THEN 1 
                                                                 WHEN claim_type='-1' THEN -1
                                                                 ELSE 0 END)
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='0' 
            THEN (CASE WHEN rbate_admin_fee>0 THEN (CASE WHEN claim_type='+1' THEN 1 
                                                         WHEN claim_type='-1' THEN -1
                                                         ELSE 0 END)
                       WHEN rbate_admin_fee<0 THEN (CASE WHEN claim_type='+1' THEN 1 
                                                         WHEN claim_type='-1' THEN -1
                                                         ELSE 0 END)
                       ELSE 0 END)  
            ELSE 0 END),
   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='1' 
            THEN (CASE WHEN rbate_admin_fee>0 THEN (CASE WHEN claim_type='+1' THEN 1 
                                                         WHEN claim_type='-1' THEN -1
                                                         ELSE 0 END)
                       WHEN rbate_admin_fee<0 THEN (CASE WHEN claim_type='+1' THEN 1 
                                                         WHEN claim_type='-1' THEN -1
                                                         ELSE 0 END)
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
   SUM(CASE WHEN EXTNL_SRC_CODE='QLC' then
		CASE WHEN CALC_BRND_XLAT_CD='1' AND (rbate_access+rbate_mrkt_shr)>0 THEN 1 
            		WHEN CALC_BRND_XLAT_CD='1' AND (rbate_access+rbate_mrkt_shr)<0 THEN -1 
            		ELSE 0 END
	ELSE
		CASE WHEN gnrc_ind in ('0') AND (rbate_access+rbate_mrkt_shr)>0 THEN 1 
            		WHEN gnrc_ind in ('0') AND (rbate_access+rbate_mrkt_shr)<0 THEN -1 
            		ELSE 0 END
	END),
   SUM(CASE WHEN EXTNL_SRC_CODE='QLC' then
		CASE WHEN CALC_BRND_XLAT_CD='1' AND claim_type='+1' THEN 1 
            		WHEN CALC_BRND_XLAT_CD='1' AND claim_type='-1' THEN -1 
            		ELSE 0 END
	ELSE
		CASE WHEN gnrc_ind in ('0') AND claim_type='+1' THEN 1 
            		WHEN gnrc_ind in ('0') AND claim_type='-1' THEN -1 
            		ELSE 0 END
	END),
   SUM(CASE WHEN EXTNL_SRC_CODE='QLC' then
		CASE WHEN clm_use_srx_cd in ('1','2','3','4') AND CALC_BRND_XLAT_CD='1' AND (rbate_access+rbate_mrkt_shr)>0 
				THEN 1 
            		WHEN clm_use_srx_cd in ('1','2','3','4') AND CALC_BRND_XLAT_CD='1'  AND (rbate_access+rbate_mrkt_shr)<0 
				THEN -1 
            		ELSE 0 END
	ELSE
		CASE WHEN clm_use_srx_cd in ('1','2','3','4') AND gnrc_ind in ('0') AND (rbate_access+rbate_mrkt_shr)>0 THEN 1 
            		WHEN clm_use_srx_cd in ('1','2','3','4') AND gnrc_ind in ('0') AND (rbate_access+rbate_mrkt_shr)<0 THEN -1 
            		ELSE 0 END
	END),
   SUM(CASE WHEN EXTNL_SRC_CODE='QLC' then
		CASE WHEN clm_use_srx_cd in ('1','2','3','4') AND CALC_BRND_XLAT_CD='1' AND claim_type='+1' THEN 1 
            		WHEN clm_use_srx_cd in ('1','2','3','4') AND CALC_BRND_XLAT_CD='1' AND claim_type='-1' THEN -1 
            		ELSE 0 END
	ELSE
		CASE WHEN clm_use_srx_cd in ('1','2','3','4') AND gnrc_ind in ('0') AND claim_type='+1' THEN 1 
            		WHEN clm_use_srx_cd in ('1','2','3','4') AND gnrc_ind in ('0') AND claim_type='-1' THEN -1 
            		ELSE 0 END
	END),
   SUM(CASE WHEN EXTNL_SRC_CODE='QLC' then
		CASE WHEN user_field6_flg='1' AND CALC_BRND_XLAT_CD='1' AND (rbate_access+rbate_mrkt_shr)>0 THEN 1 
            		WHEN user_field6_flg='1' AND CALC_BRND_XLAT_CD='1' AND (rbate_access+rbate_mrkt_shr)<0 THEN -1  
            		ELSE 0 END
	ELSE
		CASE WHEN user_field6_flg='1' AND gnrc_ind in ('0') AND (rbate_access+rbate_mrkt_shr)>0 THEN 1 
            		WHEN user_field6_flg='1' AND gnrc_ind in ('0') AND (rbate_access+rbate_mrkt_shr)<0 THEN -1  
            		ELSE 0 END
	END),
   SUM(CASE WHEN EXTNL_SRC_CODE='QLC' then
		CASE WHEN user_field6_flg='1' AND CALC_BRND_XLAT_CD='1' AND claim_type='+1' THEN 1 
            		WHEN user_field6_flg='1' AND CALC_BRND_XLAT_CD='1' AND claim_type='-1' THEN -1 
            		ELSE 0 END 
	ELSE
		CASE WHEN user_field6_flg='1' AND gnrc_ind in ('0') AND claim_type='+1' THEN 1 
            		WHEN user_field6_flg='1' AND gnrc_ind in ('0') AND claim_type='-1' THEN -1 
            		ELSE 0 END 
	END),
   SUM(CASE WHEN clm_use_srx_cd in ('1','2','3','4') AND (rbate_access+rbate_mrkt_shr)>0 THEN 1
           	WHEN clm_use_srx_cd in ('1','2','3','4') AND (rbate_access+rbate_mrkt_shr)<0 THEN -1 
            	ELSE 0 END),
   SUM(CASE WHEN clm_use_srx_cd in ('1','2','3','4') AND claim_type='+1' THEN 1 
            WHEN clm_use_srx_cd in ('1','2','3','4') AND claim_type='-1' THEN -1 
            ELSE 0 END),
   SUM(CASE WHEN user_field6_flg='1' AND (rbate_access+rbate_mrkt_shr)>0 THEN 1 
            WHEN user_field6_flg='1' AND (rbate_access+rbate_mrkt_shr)<0 THEN -1 
            ELSE 0 END),
   SUM(CASE WHEN user_field6_flg='1' AND claim_type='+1' THEN 1 
            WHEN user_field6_flg='1' AND claim_type='-1' THEN -1 
            ELSE 0 END),
   SUM(CASE WHEN EXTNL_SRC_CODE='QLC' then
		CASE when CALC_BRND_XLAT_CD='1' AND mail_order_code='0' AND claim_type='+1' THEN 1 
            		when CALC_BRND_XLAT_CD='1' AND mail_order_code='0' AND claim_type='-1' THEN -1 
            		ELSE 0 END
	ELSE
		CASE when gnrc_ind in ('0') AND mail_order_code='0' AND claim_type='+1' THEN 1 
            		when gnrc_ind in ('0') AND mail_order_code='0' AND claim_type='-1' THEN -1 
            		ELSE 0 END
	END),
   SUM(CASE WHEN EXTNL_SRC_CODE='QLC' then
		CASE when CALC_BRND_XLAT_CD='1' AND mail_order_code='1' AND claim_type='+1' THEN 1 
            		when CALC_BRND_XLAT_CD='1' AND mail_order_code='1' AND claim_type='-1' THEN -1 
            		ELSE 0 END
	ELSE
		CASE when gnrc_ind in ('0') AND mail_order_code='1' AND claim_type='+1' THEN 1 
            		when gnrc_ind in ('0') AND mail_order_code='1' AND claim_type='-1' THEN -1 
            		ELSE 0 END
	END),
   SUM(CASE when excpt_stat='R' AND clm_use_srx_cd in ('1','2','3','4') THEN (rbate_access+rbate_mrkt_shr) ELSE 0 END),
   SUM(CASE when excpt_stat='R' AND user_field6_flg='1' THEN (rbate_access+rbate_mrkt_shr) ELSE 0 END),
   SUM(CASE when excpt_stat='R' AND clm_use_srx_cd in ('1','2','3','4') THEN rbate_admin_fee ELSE 0 END),
   SUM(CASE when excpt_stat='R' AND user_field6_flg='1' THEN rbate_admin_fee ELSE 0 END),
   pmt_sys_elig_cd, 9
    FROM RPS.TAPC_DETAIL_$QPARM 
    WHERE excpt_stat IN ('P','R') 
    OR excpt_code IN ('BQ','BG','BM','BR','FA','FE','FT')
    GROUP BY period_id,rbate_id,extnl_src_code,extnl_lvl_id1,extnl_lvl_id2,extnl_lvl_id3,lcm_code,pico_no,ndc,SUBSTR(ndc,1,5),substr(ndc,6,4),substr(ndc,10,2),pmt_sys_elig_cd,9;
EOF

print " *** sql being used is: "                                     >> $LOG_FILE  
print `cat $DCSQL`                                                   >> $LOG_FILE  
print " *** end of sql display.                   "                  >> $LOG_FILE  




#   SUM(awp_unit_cst*unit_qty),
#   SUM(CASE WHEN mail_order_code='0' THEN (awp_unit_cst*unit_qty) ELSE 0 END),
#   SUM(CASE WHEN mail_order_code='1' THEN (awp_unit_cst*unit_qty) ELSE 0 END),
#   SUM(CASE WHEN excpt_stat='R' AND (rbate_access+rbate_mrkt_shr)<>0 THEN (awp_unit_cst*unit_qty) 
#            ELSE 0 END),
#   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='0' AND (rbate_access+rbate_mrkt_shr)<>0 THEN (awp_unit_cst*unit_qty) 
#            ELSE 0 END),
#   SUM(CASE WHEN excpt_stat='R' AND mail_order_code='1' AND (rbate_access+rbate_mrkt_shr)<>0 THEN (awp_unit_cst*unit_qty) 
#            ELSE 0 END),
#   SUM(CASE WHEN excpt_stat='R' AND rbate_admin_fee<>0 THEN (awp_unit_cst*unit_qty) 
#            ELSE 0 END),
#   SUM(CASE WHEN excpt_stat='R' AND mail_order_code = '0' AND rbate_admin_fee<>0 THEN (awp_unit_cst*unit_qty) 
#            ELSE 0 END),
#   SUM(CASE WHEN excpt_stat='R' AND mail_order_code = '1' AND rbate_admin_fee<>0 THEN (awp_unit_cst*unit_qty) 
#            ELSE 0 END),
#



#
# extract to file
#
if [[ $RETCODE == 0 ]]; then 
   db2 -tvf $DCSQL 
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "aborting script - error extracting data " 
      print "aborting script - error extracting data "                         >> $LOG_FILE  
   fi
fi


#
# chmod it so db2 load can see it 
#
if [[ $RETCODE == 0 ]]; then 
   chmod 777 $DCDATA                                                           >> $LOG_FILE
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "aborting script - cant chmod " $DCDATA 
      print "aborting script - cant chmod " $DCDATA                            >> $LOG_FILE  
   fi
fi


#
# load db2
#
if [[ $RETCODE == 0 ]]; then 
   db2 "load from $DCDATA of del modified by coldel|  messages $DBMSG_FILE insert into rps.tapc_drug_client_sum_$YEAR nonrecoverable"   >> $LOG_FILE  
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "aborting script - error loading db2 with " $DCDATA " return code: "  $RETCODE 
      print "aborting script - error loading db2 with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE  
      print " WARNING - LOAD TERMINATE ACTION IS REQUIRED!!! "                 >> $LOG_FILE  
   fi 
fi


#################################################################
# send email for script errors
#################################################################
if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "                                     >> $LOG_FILE 
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   print "return_code =" $RETCODE

   #Call the APC status update
   . `dirname $0`/RPS_GDX_APC_Status_update.ksh 250 ERR                        >> $LOG_FILE

   exit $RETCODE
fi

print " Script " $SCRIPT " completed successfully on " `date`                              
print " Script " $SCRIPT " completed successfully on " `date`                  >> $LOG_FILE 

#Call the APC status update
. `dirname $0`/RPS_GDX_APC_Status_update.ksh 250 END                           >> $LOG_FILE

#################################################################
# cleanup from successful run
#################################################################

rm -f $DBMSG_FILE* 
rm -f $DCDATA
rm -f $DCSQL

mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "return_code =" $RETCODE
exit $RETCODE

