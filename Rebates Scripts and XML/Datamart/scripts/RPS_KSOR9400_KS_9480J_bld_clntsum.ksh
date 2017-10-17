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
# 07-29-09   qcpi733     Added GDX APC status update; removed export command
#                        in front of RETCODE assignments.
# 07-13-09   qcpi19v     Added removal of DBSTAT_FILE
# 10-02-06   is89501     add update of Quarter Summary table
# 03-23-06   is89501     Initial Creation.
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
DCDATA=$TMP_PATH/clsum.tmp
DCSQL=$TMP_PATH/$JOB.sql
APC_INIT=./APC.init
RETCODE=0
DBSTAT_FILE=$INPUT_PATH/runstats.tab

#
#######################################################
#
# Added for BSR 40584
#
#######################################################
#
APC_EMAIL_BODY="You are receiving this email because you are a member of the group APCRO on R07PRD05. This notice is to alert you that the APC files including summary tables have been updated to reflect "
APC_EMAIL_BODY_CONT=" billing information and are available for use.\n\nIf you wish be removed from this group and email distribution, please contact rebates@caremark.com."
APC_EMAIL_DIST_LIST='APCRONOTIFY@caremark.com'

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

#Call the APC status update
. `dirname $0`/RPS_GDX_APC_Status_update.ksh 260 STRT                          >> $LOG_FILE

if [[ -e $DBSTAT_FILE ]];then
    print "Removing file $DBSTAT_FILE"
    print "Removing file $DBSTAT_FILE"          >> $LOG_FILE
    rm $DBSTAT_FILE
fi
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
        SUM(bluerx_admin_fee), pmt_sys_elig_cd,9 
    FROM rps.tapc_drug_client_sum_$YEAR
     WHERE period_id = '$QPARM' 
     GROUP BY period_id, rbate_id, lcm_code, extnl_src_code, extnl_lvl_id1, extnl_lvl_id2, extnl_lvl_id3, pmt_sys_elig_cd,9;
ZZEOF

print " *** sql being used is: "                                     >> $LOG_FILE  
print `cat $DCSQL`                                                   >> $LOG_FILE  
print " *** end of sql display."                                     >> $LOG_FILE  


#
# extract to file
#
if [[ $RETCODE == 0 ]]; then 
   db2 -tvf $DCSQL                                                   >> $LOG_FILE  
   RETCODE=$?
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
   RETCODE=$?
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
   db2 "load from $DCDATA of del modified by coldel|  messages $DBMSG_FILE insert into rps.tapc_client_sum_$YEAR nonrecoverable"   >> $LOG_FILE  
   RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "aborting script - error loading db2 with " $DCDATA " return code: "  $RETCODE 
      print "aborting script - error loading db2 with " $DCDATA " return code: "  $RETCODE         >> $LOG_FILE  
      print " WARNING - LOAD TERMINATE ACTION IS REQUIRED!!! "           >> $LOG_FILE  
   fi 
fi



#
# build tapc_sum for quarter
#
if [[ $RETCODE == 0 ]]; then 
  sqml --QPID $QPARM $XML_PATH/dm_calc_apc_sum.xml                               
  RETCODE=$?
  print `date`"sqml retcode was " $RETCODE " for build of TAPC_SUM period " $QPARM 
  print `date`"sqml retcode was " $RETCODE " for build of TAPC_SUM period " $QPARM  >> $LOG_FILE
fi


#
# update quartery summmary table for quarter
#
if [[ $RETCODE == 0 ]]; then 
  sqml --QPID $QPARM $XML_PATH/dm_calc_qtr_sum.xml                               
  RETCODE=$?
  print `date`"sqml retcode was " $RETCODE " for update of QUARTER_SUMMARY for period " $QPARM 
  print `date`"sqml retcode was " $RETCODE " for update of QUARTER_SUMMARY for period " $QPARM     >> $LOG_FILE 
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
   . `dirname $0`/RPS_GDX_APC_Status_update.ksh 260 ERR                        >> $LOG_FILE

   exit $RETCODE
fi

print " Script " $SCRIPT " completed successfully on " `date`                              
print " Script " $SCRIPT " completed successfully on " `date`                  >> $LOG_FILE 

#Call the APC status update
. `dirname $0`/RPS_GDX_APC_Status_update.ksh 260 END                           >> $LOG_FILE

#################################################################
# Added for BSR 40584 
# Send email for successfull completion of APC process
#################################################################
if [[ $RETCODE == 0 ]]; then 
   print "Sending email for APC success notification"
   print $APC_EMAIL_BODY $QPARM $APC_EMAIL_BODY_CONT | mailx -s "RPS Datamart Alert! - APC File updated" $APC_EMAIL_DIST_LIST
   print "APC return_code =" $RETCODE

fi

#################################################################
# cleanup from successful run
#################################################################

rm -f $DBMSG_FILE* 
rm -f $DCDATA
rm -f $DCSQL

mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "return_code =" $RETCODE
exit $RETCODE

