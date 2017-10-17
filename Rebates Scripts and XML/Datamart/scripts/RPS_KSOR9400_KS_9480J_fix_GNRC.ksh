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
cat > $DCSQL << ZZEOF
export to $DCDATA of del modified by coldel| messages $DBMSG_FILE SELECT PERIOD_ID, 
            rbate_id, 
            lcm_code, 
            extnl_src_code,
            extnl_lvl_id1, 
            extnl_lvl_id2, 
            extnl_lvl_id3,
            SUM(claims_physical_cnt),  
            SUM(claims), 
            SUM(retail_claims), 
            SUM(mail_claims),
            SUM(rbate_claims), 
	    SUM(retail_rbate_claims), 
	    SUM(mail_rbate_claims),
            SUM(admin_claims),
	    SUM(retail_admin_claims),
	    SUM(mail_admin_claims),
            SUM(units),
	    SUM(retail_units),
	    SUM(mail_units),
            SUM(rbate_units),
	    SUM(retail_rbate_units),
	    SUM(mail_rbate_units),             
	    SUM(admin_units),
	    SUM(retail_admin_units),
	    SUM(mail_admin_units),
            SUM(ingrd_cst),
	    SUM(retail_ingrd_cst),
	    SUM(mail_ingrd_cst),
            SUM(rbate_ingrd_cst),
	    SUM(retail_rbate_ingrd_cst),
	    SUM(mail_rbate_ingrd_cst),
            SUM(admin_ingrd_cst),
	    SUM(retail_admin_ingrd_cst),
	    SUM(mail_admin_ingrd_cst),
            SUM(awp_cst),
	    SUM(retail_awp_cst),
	    SUM(mail_awp_cst),
            SUM(rbate_awp_cst),
	    SUM(retail_rbate_awp_cst),
	    SUM(mail_rbate_awp_cst),
            SUM(admin_awp_cst),
	    SUM(retail_admin_awp_cst),
	    SUM(mail_admin_awp_cst),
	    SUM(access_rbate),
	    SUM(retail_access_rbate),
	    SUM(mail_access_rbate),
            SUM(mrktshr_rbate),
	    SUM(retail_mrktshr_rbate),
	    SUM(mail_mrktshr_rbate),
            SUM(admin_fee),
	    SUM(retail_admin_fee),
	    SUM(mail_admin_fee),
            SUM(rbat_brnd_clm_cnt),
	    SUM(brand_claims),
	    SUM(srx_rbat_brnd_clm_cnt),
            SUM(srx_sbmttd_brnd_cnt),
	    SUM(bluerx_rbat_brnd_clm_cnt), 
            SUM(bluerx_submttd_brnd_cnt),
	    SUM(srx_rbat_clm_cnt),
	    SUM(srx_claims),
            SUM(bluerx_rbat_clm_cnt),
	    SUM(bluerx_claims),
	    SUM(retail_brand_claims),
            SUM(mail_brand_claims),
	    SUM(srx_rbates),
	    SUM(bluerx_rbates),
            SUM(srx_admin_fee),
	    SUM(bluerx_admin_fee), pmt_sys_elig_cd 
    FROM rps.tapc_drug_client_sum_$YEAR
     WHERE period_id = '$QPARM' and extnl_src_code='QLC'
     GROUP BY period_id, rbate_id, lcm_code, extnl_src_code, extnl_lvl_id1, extnl_lvl_id2, extnl_lvl_id3, pmt_sys_elig_cd;
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE  
print `cat $DCSQL`                                                   >> $LOG_FILE  
print " *** end of sql display."                                     >> $LOG_FILE  


#
# extract to file
#
if [[ $RETCODE == 0 ]]; then 
   db2 -tvf $DCSQL                                                   >> $LOG_FILE  
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
   db2 "import from $DCDATA of del modified by coldel| commitcount 5000  messages $DBMSG_FILE insert into rps.tapc_client_sum_$YEAR "   >> $LOG_FILE  
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

