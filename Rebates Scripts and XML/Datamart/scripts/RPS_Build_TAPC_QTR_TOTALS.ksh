#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_Build_TAPC_QTR_TOTALS.ksh 
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
# 07-28-09   QCPI733     added GDX APC status updates
# 03-23-06   is89501     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=$(basename "$0")
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
LOG=$FILE_BASE".log"
LOG_FILE="$LOG_PATH/$LOG"
ARCH_LOGFILE="$LOG_ARCH_PATH/$LOG."`date +"%Y%j%H%M"`
MYSQL=$TMP_PATH/$FILE_BASE.sql
QPARM=

rm -f $LOG_FILE
rm -f $MYSQL

RETCODE=0
 
print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

#Call the APC status update
. `dirname $0`/RPS_GDX_APC_Status_update.ksh 220 STRT                          >> $LOG_FILE

#
# connect to udb
#
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING                                             >> $LOG_FILE 
   QPARM=`db2 -x "select min(period_id) from rps.quarter_summary where RPS_ACTIVE_IND='0'"`
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "aborting script - cant connect to udb " 
      print "aborting script - cant connect to udb "               >> $LOG_FILE  
   fi
   QID=`echo $QPARM|sed 's/Q/0/'`
fi


if [[ $RETCODE == 0 ]]; then 
   db2 -x "delete from RPS.TAPC_QTR_TOTALS where quarter_id=$QID"
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
       if [[ $RETCODE = 1 ]]; then 
           RETCODE=0
       else
           print "Error deleting rows from RPS.TAPC_QTR_TOTALS for quarter_id $QID" 
           print "Error deleting rows from RPS.TAPC_QTR_TOTALS for quarter_id $QID"               >> $LOG_FILE  
       fi
   fi
fi
#
# create sql file
#
cat > $MYSQL << EOF

insert into RPS.TAPC_QTR_TOTALS
(
    QUARTER_ID,
    MODEL_TYP_CD,
    AP_COMPNY_CD,
    PICO_NO,
    PMT_SYS_ELIG_CD,
    CREATE_TS,
    GRS_CLM_CNT,
    NET_CLM_CNT,
    GRS_CLM_CNT_SBMD,
    DSPNSD_QTY,
    GRS_CLM_CNT_RBAT,
    DSPNSD_QTY_RBAT,
    DSPNSD_QTY_SBMD,
    NET_CLM_CNT_RBAT,
    NET_CLM_CNT_SBMD,
    RBAT_ACC_DISCNT_AMT,
    RBAT_PRFMC_DISCNT_AMT,
    RBAT_ADMN_DISCNT_AMT,
    RBAT_DISCNT_AMT
)

select 
        $QID AS QUARTER_ID
    ,INV_MODEL AS MODEL_TYP_CD
    ,CNTRL_NO AS AP_COMPNY_CD
    ,INT(PICO_NO)
    ,PMT_SYS_ELIG_CD
    ,current timestamp  as CREATE_TS
    ,count(*) AS GRS_CLM_CNT
    , sum(integer(claim_type)) AS NET_CLM_CNT
    , sum(CASE
        WHEN EXCPT_STAT = 'P' THEN 1
        ELSE 0
        END) as GRS_CLM_CNT_SBDM
    ,SUM(UNIT_QTY) AS DSPND_QTY    
    , SUM(CASE
        WHEN EXCPT_STAT = 'R' THEN 1
        ELSE 0
        END) AS GRS_CLM_CNT_RBAT
    , SUM(CASE
        WHEN EXCPT_STAT = 'R' THEN UNIT_QTY
        ELSE 0
        END) AS DSPND_QTY_RBAT   
    ,SUM(CASE
       WHEN EXCPT_STAT = 'P' THEN UNIT_QTY
        ELSE 0
        END) as DSPND_QTY_SBMD  
        , SUM(CASE
        WHEN EXCPT_STAT = 'R' THEN integer(claim_type)
        ELSE 0
        END) AS NET_CLM_CNT_RBAT
   , SUM(CASE
        WHEN EXCPT_STAT = 'P' THEN integer(claim_type)
        ELSE 0
        END) as NET_CLM_CNT_SBDM
    
    ,SUM(RBATE_ACCESS) AS RBAT_ACC_DISCNT_AMT
    ,SUM(RBATE_MRKT_SHR) AS RBAT_PRFMC_DISCNT_AMT
    ,SUM(RBATE_ADMIN_FEE) AS RBAT_ADMN_DISCNT_AMT
    ,SUM(RBATE_ACCESS+RBATE_ADMIN_FEE+RBATE_MRKT_SHR) AS RBAT_DISCNT_AMT
    
    from rps.tapc_detail_$QPARM
    
    GROUP BY INV_MODEL,CNTRL_NO,PICO_NO,PMT_SYS_ELIG_CD;
EOF

print " *** sql being used is: "                                     >> $LOG_FILE  
print `cat $MYSQL`                                                   >> $LOG_FILE  
print " *** end of sql display.                   "                  >> $LOG_FILE  

#
# extract to file
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stvxwf $MYSQL 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "aborting script - error extracting data " 
      print "aborting script - error extracting data "               >> $LOG_FILE  
   fi
fi

#################################################################
# send email for script errors
#################################################################
if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "                               >> $LOG_FILE 
   EMAIL_SUBJECT=$SCRIPT
   #mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   print "return_code =" $RETCODE

   #Call the APC status update
   . `dirname $0`/RPS_GDX_APC_Status_update.ksh 220 ERR                  >> $LOG_FILE

   cp $LOG_FILE      $ARCH_LOGFILE 
   exit $RETCODE
fi

print " Script " $SCRIPT " completed successfully on " `date`                              
print " Script " $SCRIPT " completed successfully on " `date`            >> $LOG_FILE 

#Call the APC status update
. `dirname $0`/RPS_GDX_APC_Status_update.ksh 220 END                     >> $LOG_FILE

#################################################################
# cleanup from successful run
#################################################################

rm -f $MYSQL

mv $LOG_FILE      $ARCH_LOGFILE 

print "return_code =" $RETCODE
exit $RETCODE

