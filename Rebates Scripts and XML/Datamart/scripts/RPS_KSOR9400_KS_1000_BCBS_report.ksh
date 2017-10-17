#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR9400_KS_1000_BCBS_report.ksh
# Title         : BCBS AR Med D Rebate files
# Description   : This script will pull lookup info from EDW and Payments,
#                 use apc data to generate client requested rebate files.
#                 the following tables will be updated:
#                       rps.BCBS_REPORT
#           		rps.BCBS_LOOKUP
#           		rps.BCBS_control
#           		rps.BCBS_adjust_pct
#         	  Up to 17 quarters of rebated claims will be stored in 
#         	  table rps.BCBS_REPORT with client requested additional info.
#
#         	  This script will be kicked off at the end of the APC load 
#                 process.
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
# 07/26/12   qcpy987     Heat 8075442 - uncomment code for getting align-
#                        lvl-gid
# 04/26/12   qcpy987     IM695281 - fixed divide by zero problem in xml
#                                   added restart capabilities
# 06-09-11   qcpi03o     BSRFC002  - BCBSAR Add admin fee amount
# 09-08-10   qcpi03o     BSR 59697 - BCBSAR Add New Rebate IDs
# 05-17-10   qcpi03o     BSR 56039 - allocate collection amount by weight
#                                    of claim invoice amount
# 07-29-09   qcpi733     Added GDX APC status update
# 03-20-08   qcpi03o     Initial Creation.
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

RBATE_CNT=$TMP_PATH/BCBS.rebate
PERIOD_CNT=$TMP_PATH/BCBS.period
ALGN_GID_LIST=$TMP_PATH/BCBS.algn

MEMBER_FILE=$TMP_PATH/BCBS.MemberLevel.
DRUG_FILE=$TMP_PATH/BCBS.DrugLevel.

FILE_TRL=`date +"%Y%m%d"`

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                                       > $LOG_FILE

#Call the APC status update
. `dirname $0`/RPS_GDX_APC_Status_update.ksh 350 STRT                          >> $LOG_FILE

################################################################
# 1) examine input parameter  yyyyQn
################################################################
read INQPARM < $SCRIPT_PATH/APC.init
print " input parm was: " $INQPARM
print " input parm was: " $INQPARM   >> $LOG_FILE

#   edit supplied parameter
    YEAR=`echo $INQPARM |cut -c 1-4`
    QTR=`echo $INQPARM |cut -c 6-6`
    if (( $YEAR > 1990 && $YEAR < 2050 )); then
      print ' using parameter YEAR of ' $YEAR
    else
      print ' !!! invalid parameter YEAR = ' $YEAR ' !!! Parm format is yyyyQn.  Terminating script '
      print ' !!! invalid parameter YEAR = ' $YEAR ' !!! Parm format is yyyyQn.  Terminating script '  >> $LOG_FILE
      RETCODE=12
    fi
    if (( $QTR > 0 && $QTR < 5 )); then
      print ' using parameter QUARTER of ' $QTR
    else
      print ' !!! invalid parameter QUARTER = ' $QTR ' !!! Parm format is yyyyQn. Terminating script '
      print ' !!! invalid parameter QUARTER = ' $QTR ' !!! Parm format is yyyyQn. Terminating script ' >> $LOG_FILE
      RETCODE=12
    fi

INQPARM=$YEAR"Q"$QTR

print ' qparm is ' $INQPARM                     >> $LOG_FILE

################################################################
# 2) connect to udb
################################################################
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING                                                         >> $LOG_FILE 
   RETCODE=$?
   print "Step 2 completed - connect to db "                                   >> $LOG_FILE
   if [[ $RETCODE != 0 ]]; then 
      print "!!! terminating script - cant connect to udb " 
      print "!!! terminating script - cant connect to udb "                    >> $LOG_FILE  
   fi
fi

################################################################
# 2) read Rebate ID from control table
#    read algn_lvl_gid from control table
################################################################


if [[ $RETCODE == 0 ]]; then 
    db2 -px "select distinct REBATE_ID from rps.bcbs_control" > $RBATE_CNT
RETCODE=$?
fi


if [[ $RETCODE == 0 ]]; then 
    db2 -px "select distinct algn_lvl_gid from rps.bcbs_algn_gid" > $ALGN_GID_LIST
RETCODE=$?
fi

ALGN_GID=0
while read ALGN; do
	ALGN_GID=$ALGN_GID,$ALGN
done <$ALGN_GID_LIST

################################################################
# 3)  for the current quarter, extract claims from APC detail table
#     clear out the tables for restartability
################################################################

if [[ $RETCODE == 0 ]]; then
    sql="delete from rps.BCBS_report where inv_qtr = '$INQPARM'"
    db2 -px "$sql"  
    export RETCODE=$?
fi

if [[ $RETCODE == 0 || $RETCODE == 1 ]]; then
    sql="delete from rps.bcbs_control where inv_qtr = '$INQPARM'"
    db2 -px "$sql" 
    export RETCODE=$?
fi

# if the table is empty the return code will be 1
# set it to 0 to continue processing

if [[ $RETCODE == 1 ]]; then
    RETCODE=0
fi

while read RBATE; do

if [[ $RETCODE == 0 ]]; then
sqml --QPARM $INQPARM --RBATE $RBATE $XML_PATH/BCBS_apc_extract.xml            >> $LOG_FILE
RETCODE=$?
fi

if [[ $RETCODE == 0 ]]; then 
    db2 -px "insert into rps.bcbs_control values('$RBATE','$INQPARM',0)" 
RETCODE=$?
fi

done <$RBATE_CNT


   print "Step 3 completed - extract the current qtr APC into bcbs_report "    >> $LOG_FILE

################################################################
# 4) for the current quarter, extrct EDW data and update mbr/plan
################################################################

if [[ $RETCODE == 0 ]]; then 

   if [[ $RETCODE == 0 ]]; then 
    db2 -px "import from /dev/null of del replace into rps.BCBS_lookup" 
   RETCODE=$?
   fi

   if [[ $QTR = '1' ]]; then
                PARTITION_1=$YEAR"01"
                PARTITION_2=$YEAR"02"
                PARTITION_3=$YEAR"03"
   fi

   if [[ $QTR = '2' ]]; then
                PARTITION_1=$YEAR"04"
                PARTITION_2=$YEAR"05"
                PARTITION_3=$YEAR"06"
   fi

   if [[ $QTR = '3' ]]; then
                PARTITION_1=$YEAR"07"
                PARTITION_2=$YEAR"08"
                PARTITION_3=$YEAR"09"
   fi

   if [[ $QTR = '4' ]]; then
                PARTITION_1=$YEAR"10"
                PARTITION_2=$YEAR"11"
                PARTITION_3=$YEAR"12"
   fi

   sqml  --QPART $PARTITION_1 --ALGN_GID $ALGN_GID $XML_PATH/BCBS_EDW_lookup.xml                    >> $LOG_FILE
   sqml  --QPART $PARTITION_2 --ALGN_GID $ALGN_GID $XML_PATH/BCBS_EDW_lookup.xml                    >> $LOG_FILE
   sqml  --QPART $PARTITION_3 --ALGN_GID $ALGN_GID $XML_PATH/BCBS_EDW_lookup.xml                    >> $LOG_FILE

RETCODE=$?
fi


if [[ $RETCODE == 0 ]]; then 
   sqml  $XML_PATH/BCBS_report_lkp_mbr.xml                                     >> $LOG_FILE
RETCODE=$?
fi


   print "Step 4 completed - pull EDW info into bcbs_lookup "                  >> $LOG_FILE

################################################################
# 5) for each inv_qtr, extract ksrb221
################################################################
if [[ $RETCODE == 0 ]]; then
        db2 -px "select distinct INV_QTR from rps.bcbs_control where inv_qtr>'2007Q2'" > $PERIOD_CNT
RETCODE=$?
fi

#   if [[ $RETCODE == 0 ]]; then 
#    db2 -px "import from /dev/null of del replace into rps.BCBS_ksrb221" 
#   RETCODE=$?
#   fi

#while read QPARM; do
#if [[ $RETCODE == 0 ]]; then
#     sqml --QPARM $QPARM $XML_PATH/BCBS_ksrb221.xml                           >> $LOG_FILE
#RETCODE=$?
#fi
#done <$PERIOD_CNT

   print "Step 5 completed - pull Payments ksrb221 into bcbs_ksrb221 "        >> $LOG_FILE

################################################################
# 6) for each rbate_id/inv_qtr, update BCBS_report
################################################################
while read RBATE; do

   while read QPARM; do

    if [[ $RETCODE == 0 ]]; then
    print "running step 6 - update lkp_dt in bcbs_report for $RBATE/$QPARM"   >> $LOG_FILE

    sqml --QPARM $QPARM --RBATE $RBATE $XML_PATH/BCBS_report_lkp_dt.xml        >> $LOG_FILE
    RETCODE=$?
    fi

if [[ $RETCODE == 0 ]];then
  sql="select count(*) from rps.L_splits where REBATE_ID='$RBATE' and INV_QTR='$QPARM' and PRICING_TYPE_CD='A'"
  db2 -stx "$sql" | read ADMIN_PRC
  export RETCODE=$?
fi


if [[ $RETCODE == 0 ]];then
if [[ $ADMIN_PRC == 0 ]];then
#####################################inv_qtr without admin fee pricing
    print "running step 6 - update amounts in bcbs_report for $RBATE/$QPARM"   >> $LOG_FILE
    if [[ $RETCODE == 0 ]]; then
    sqml --QPARM $QPARM --RBATE $RBATE $XML_PATH/BCBS_report_upd_adj.xml       >> $LOG_FILE
    RETCODE=$?
    fi

    if [[ $RETCODE == 0 ]]; then
    sqml --QPARM $QPARM --RBATE $RBATE $XML_PATH/BCBS_report_lkp_clamt.xml     >> $LOG_FILE
    RETCODE=$?
    fi

else
#####################################inv_qtr WITH admin fee pricing
    print "running step 6 - update amounts with admin in bcbs_report for $RBATE/$QPARM"   >> $LOG_FILE
    if [[ $RETCODE == 0 ]]; then
    sqml --QPARM $QPARM --RBATE $RBATE $XML_PATH/BCBS_report_upd_amt_w_adm.xml       >> $LOG_FILE
    RETCODE=$?
    fi

    if [[ $RETCODE == 0 ]]; then
    sqml --QPARM $QPARM --RBATE $RBATE $XML_PATH/BCBS_report_lkp_clamt.xml     >> $LOG_FILE
    RETCODE=$?
    fi


fi
fi

   done <$PERIOD_CNT
done <$RBATE_CNT

   print "Step 6 completed - update lkp_dt, adjustment and collect amt in bcbs_report"   >> $LOG_FILE

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

   #Call the APC status update
   . `dirname $0`/RPS_GDX_APC_Status_update.ksh 350 ERR                        >> $LOG_FILE

   exit $RETCODE
fi

print " Script " $SCRIPT " completed successfully on " `date`                              
print " Script " $SCRIPT " completed successfully on " `date`                  >> $LOG_FILE 

#Call the APC status update
. `dirname $0`/RPS_GDX_APC_Status_update.ksh 350 END                           >> $LOG_FILE

#################################################################
# cleanup from successful run
#################################################################
mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "return_code =" $RETCODE
exit $RETCODE
