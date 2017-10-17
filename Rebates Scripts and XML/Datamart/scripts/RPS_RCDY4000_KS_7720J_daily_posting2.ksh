#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_RCDY4000_KS_7720J_daily_posting2.ksh
# Title         : Synchronize datamart with mainframe after daily process
#                 Part 2
#
# Description   : This script will synchronize datamart tables with
#                 payment system mainframe tables after daily processsing
#                 is complete.
#                 DM tables import takes a few hours to complete.
#                 To release MVS tables earlier, this job splits into
#                 two parts. The first part export feed files from MVS,
#                 the second part loads DM tables and compare.
#
# Abends        : If select count does not match insert results then set bad
#                 return code.  If summed amounts differ set return code.
#
# Rerun Instruction:   if the output files are not under /RPSPRD/tmp,
#                      run RPS_KSDY7000_KS_7700J_daily_posting.ksh first.
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
# 06-23-06   is89501     added rebuild of F_INV_LNAMT_SUM
# 12-07-06   qcpi03o     added refresh of KSZ6000_PERIOD
# 12-15-06   is89501     added refresh of KSRB250_DISTR
# 01-08-07   qcpi03o     split the load of KSRB222, KSRB223, KSRB103, KSRB250
#                         to a seperate job RPS_KSDY7000_KS_7700J_daily_posting2.ksh
# 09-28-09   qcpi03o     added step to refresh ksz6005, full replace
#                        added step to rebuild t_sl_client_sum, to avoid timing issue
# 01-14-10   qcpi03o     updated ksrb300 balance count to exclude typ 10 rows
#                            BSR 52023
# 10-20-10   qcpi03o     add steps to refresh ksrb240/ksrb243
#                        update ksz6005 refresh
#                        change t_sl_client_sum rebuild to use load
# 03-15-12   qcpy987     added tables KSRB310 and KSRB320.  Added new count
#                        plus amount compare
# 05-31-12   qcpy987     added sql to get MVS amounts.  Removed FTP
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_RCDY4000_KS_7720J_daily_posting2 
JOB=ks7700j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
RETCODE=0

#set -o xtrace

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE


################################################################
# Read workflow timestamp
################################################################
read UPDT_TS < $TMP_PATH/KS_7720_timestamp.dat
print " update timestamp was: " $UPDT_TS
print " update timestamp was: " $UPDT_TS   >> $LOG_FILE

# format timestamp
YEAR=`echo $UPDT_TS |cut -c 7-10`
MM=`echo $UPDT_TS | cut -c 1-2`
DD=`echo $UPDT_TS | cut -c 4-5`
TS=`echo $UPDT_TS | cut -c 12-19`
TSFMT=`echo $TS | sed 'y/-:/../'`
UPDT_TS=$YEAR"-"$MM"-"$DD"-"$TSFMT
print " formatted timestamp is " $UPDT_TS
print " formatted timestamp is " $UPDT_TS  >> $LOG_FILE

###################################################################
# connect to udb
###################################################################
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING                                                 >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! aborting daily posting - cant connect to udb " 
      print "!!! aborting daily posting - cant connect to udb "               >> $LOG_FILE  
   fi
fi

###################################################################
# sync up local copy of fesump with mainframe after daily posting
###################################################################


#
# 1) import/replace fesump
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stvx "import from "$TMP_PATH"/fesump.dat of del modified by coldel| commitcount 5000 insert_update into "$SCHEMA".ksrb222_fesump "   >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on import from fesump, retcode: "$RETCODE  
      print "!!! error on import from fesump, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 2) get DM amounts
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx 'select sum(fsmp_amt) from '$SCHEMA'.ksrb222_fesump' > $TMP_PATH/$JOB.222DM  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select sum(fsmp_amt) from datamart ksrb222_fesump, retcode: "$RETCODE  
      print "!!! error on select sum(fsmp_amt) from datamart ksrb222_fesump, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 3) get MVS fesump amounts
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select sum(fsmp_amt) from "$MF_SCHEMA".ksrb222_fesump where last_updt_ts <= '"$UPDT_TS"'" > $TMP_PATH/$JOB.222MVS   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select sum(fsmp_amt) from mainframe ksrb222_fesump, retcode: "$RETCODE  
      print "!!! error on select sum(fsmp_amt) from mainframe ksrb222_fesump, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 4) compare amounts
#
if [[ $RETCODE == 0 ]]; then 
    SUM1=`cat $TMP_PATH/$JOB.222DM`
    SUM2=`cat $TMP_PATH/$JOB.222MVS`
    if [[ $SUM1 == $SUM2 ]]; then 
      print "fesump sum amounts of "$SUM1" match okay"  
      print "fesump sum amounts of "$SUM1" match okay"      >> $LOG_FILE  
    else
      print "!!! WARNING - fesump sum amount of datamart "$SUM1" does not match mainframe "$SUM2     
      print "!!! WARNING - fesump sum amount of datamart "$SUM1" does not match mainframe "$SUM2      >> $LOG_FILE  
      EMAIL_SUBJECT=$SCRIPT"_out_of_balance!"
      mailx -s $EMAIL_SUBJECT $MONITOR_EMAIL_ADDRESS < $LOG_FILE   
    fi
fi



##############################################################
#               sync FESUMC
##############################################################

#
# 1) import/replace fesumc
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stvx "import from "$TMP_PATH"/fesumc.dat of del modified by coldel| commitcount 5000 insert_update into "$SCHEMA".ksrb223_fesumc "   >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on import from fesumc, retcode: "$RETCODE  
      print "!!! error on import from fesumc, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 2) get datamart amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx 'select sum(fsmr_amt) from '$SCHEMA'.ksrb223_fesumc' > $TMP_PATH/$JOB.223DM  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select sum(fsmr_amt) from datamart ksrb223_fesumc, retcode: "$RETCODE  
      print "!!! error on select sum(fsmr_amt) from datamart ksrb223_fesumc, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 3) get mainframe amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select sum(fsmr_amt) from "$MF_SCHEMA".ksrb223_fesumc where last_updt_ts <= '"$UPDT_TS"'" > $TMP_PATH/$JOB.223MVS   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select sum(fsmr_amt) from mainframe ksrb223_fesumc, retcode: "$RETCODE  
      print "!!! error on select sum(fsmr_amt) from mainframe ksrb223_fesumc, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 4) compare amounts
#
if [[ $RETCODE == 0 ]]; then 
    SUM1=`cat $TMP_PATH/$JOB.223DM`
    SUM2=`cat $TMP_PATH/$JOB.223MVS`
    if [[ $SUM1 == $SUM2 ]]; then 
      print "fesumc sum amounts of "$SUM1" match okay"  
      print "fesumc sum amounts of "$SUM1" match okay"      >> $LOG_FILE  
    else
      print "!!! WARNING - fesumc sum amount of datamart "$SUM1" does not match mainframe "$SUM2     
      print "!!! WARNING - fesumc sum amount of datamart "$SUM1" does not match mainframe "$SUM2      >> $LOG_FILE  
      EMAIL_SUBJECT=$SCRIPT"_out_of_balance!"
      mailx -s $EMAIL_SUBJECT $MONITOR_EMAIL_ADDRESS < $LOG_FILE   
    fi
fi

 
##############################################################
#
#               sync KSRB103_INV_LNAMT
#
##############################################################

#
# 1) import/replace ksrb103
#

if [[ $RETCODE == 0 ]]; then 
   db2 -stvx "import from "$TMP_PATH"/ksrb103.dat of del modified by coldel| commitcount 5000 insert_update into "$SCHEMA".ksrb103_inv_lnamt "   >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on import from ksrb103, retcode: "$RETCODE  
      print "!!! error on import from ksrb103, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 2) get datamart amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx 'select sum(net_amt) from '$SCHEMA'.ksrb103_inv_lnamt' > $TMP_PATH/$JOB.103DM  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select sum(net_amt) from datamart ksrb103_inv_lnamt, retcode: "$RETCODE  
      print "!!! error on select sum(net_amt) from datamart ksrb103_inv_lnamt, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 3) get mainframe amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select sum(net_amt) from "$MF_SCHEMA".ksrb103_inv_lnamt where last_updt_ts <= '"$UPDT_TS"'" > $TMP_PATH/$JOB.103MVS
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select sum(net_amt) from mainframe ksrb103_inv_lnamt, retcode: "$RETCODE  
      print "!!! error on select sum(net_amt) from mainframe ksrb103_inv_lnamt, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 4) compare amounts
#
if [[ $RETCODE == 0 ]]; then 
    SUM1=`cat $TMP_PATH/$JOB.103DM`
    SUM2=`cat $TMP_PATH/$JOB.103MVS`
    if [[ $SUM1 == $SUM2 ]]; then 
      print "ksrb103 sum amounts of "$SUM1" match okay"  
      print "ksrb103 sum amounts of "$SUM1" match okay"      >> $LOG_FILE  
    else
      print "!!! WARNING - ksrb103 sum amount of datamart "$SUM1" does not match mainframe "$SUM2     
      print "!!! WARNING - ksrb103 sum amount of datamart "$SUM1" does not match mainframe "$SUM2      >> $LOG_FILE  
      EMAIL_SUBJECT=$SCRIPT"_out_of_balance!"
      mailx -s $EMAIL_SUBJECT $MONITOR_EMAIL_ADDRESS < $LOG_FILE   
    fi
fi
 
##############################################################
#
#               sync KSRB250_DISTR
#
##############################################################

#
# 1) import/replace ksrb250
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stvx "import from "$TMP_PATH"/ksrb250.dat of del modified by coldel| commitcount 2500 insert_update into "$SCHEMA".ksrb250_distr "   >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on import from ksrb250, retcode: "$RETCODE  
      print "!!! error on import from ksrb250, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 2) get datamart amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx 'select sum(pmt_amt) from '$SCHEMA'.ksrb250_distr' > $TMP_PATH/$JOB.250DM  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select sum(pmt_amt) from datamart ksrb250_distr, retcode: "$RETCODE  
      print "!!! error on select sum(pmt_amt) from datamart ksrb250_distr, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 3) get mainframe amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select sum(pmt_amt) from "$MF_SCHEMA".ksrb250_distr where last_updt_ts <= '"$UPDT_TS"'" > $TMP_PATH/$JOB.250MVS   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select sum(pmt_amt) from mainframe ksrb250_distr, retcode: "$RETCODE  
      print "!!! error on select sum(pmt_amt) from mainframe ksrb250_distr, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 4) compare amounts
#
if [[ $RETCODE == 0 ]]; then 
    SUM1=`cat $TMP_PATH/$JOB.250DM`
    SUM2=`cat $TMP_PATH/$JOB.250MVS`
    if [[ $SUM1 == $SUM2 ]]; then 
      print "ksrb250 sum amounts of "$SUM1" match okay"  
      print "ksrb250 sum amounts of "$SUM1" match okay"      >> $LOG_FILE  
    else
      print "!!! WARNING - ksrb250 sum amount of datamart "$SUM1" does not match mainframe "$SUM2     
      print "!!! WARNING - ksrb250 sum amount of datamart "$SUM1" does not match mainframe "$SUM2      >> $LOG_FILE  

      EMAIL_SUBJECT=$SCRIPT"_out_of_balance!"
      mailx -s $EMAIL_SUBJECT $MONITOR_EMAIL_ADDRESS < $LOG_FILE   

    
    fi
fi

##############################################################
#
#               sync TAPC_LCM_SUMMARY
#
##############################################################

#
# 1) import/replace tapc_lcm_summary
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stvx "import from "$TMP_PATH"/ksrb300.dat of del modified by coldel| commitcount 2500 insert_update into "$SCHEMA".tapc_lcm_summary "   >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on import from TAPC_LCM_SUMMARY, retcode: "$RETCODE  
      print "!!! error on import from TAPC_LCM_SUMMARY, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 2) get datamart amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select count(*) from "$SCHEMA".tapc_lcm_summary where CLM_CNT_TYP_CD<>'10'" > $TMP_PATH/$JOB.300DM  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select sum(SUBM_CLM_CNT) from datamart TAPC_LCM_SUMMARY, retcode: "$RETCODE  
      print "!!! error on select sum(SUBM_CLM_CNT) from datamart TAPC_LCM_SUMMARY, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 3) get mainframe amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select count(*) from "$MF_SCHEMA".KSRB300_COUNT_SUM where CLM_CNT_TYP_CD<>'10' and last_updt_ts <= '"$UPDT_TS"'" > $TMP_PATH/$JOB.300MVS   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select sum(SUBM_CLM_CNT) from mainframe KSRB300_COUNT_SUM, retcode: "$RETCODE  
      print "!!! error on select sum(SUBM_CLM_CNT) from mainframe KSRB300_COUNT_SUM, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 4) compare amounts
#
if [[ $RETCODE == 0 ]]; then 
    SUM1=`cat $TMP_PATH/$JOB.300DM`
    SUM2=`cat $TMP_PATH/$JOB.300MVS`
    if [[ $SUM1 == $SUM2 ]]; then 
      print "ksrb300 sum amounts of "$SUM1" match okay"  
      print "ksrb300 sum amounts of "$SUM1" match okay"      >> $LOG_FILE  
    else
      print "!!! WARNING - ksrb300 sum amount of datamart "$SUM1" does not match mainframe "$SUM2     
      print "!!! WARNING - ksrb300 sum amount of datamart "$SUM1" does not match mainframe "$SUM2      >> $LOG_FILE  

      EMAIL_SUBJECT=$SCRIPT"_out_of_balance!"
      mailx -s $EMAIL_SUBJECT $MONITOR_EMAIL_ADDRESS < $LOG_FILE   

    
    fi
fi

##############################################################
#
#               sync KSRB240_RECN_HDR_STG
#
##############################################################

#
# 1) import into KSRB240_RECN_HDR_STG
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stvx "import from "$TMP_PATH"/ksrb240.dat of del modified by coldel| commitcount 2500 insert_update into "$SCHEMA".KSRB240_RECN_HDR_STG "   >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on import from KSRB240_RECN_HDR_STG, retcode: "$RETCODE  
      print "!!! error on import from KSRB240_RECN_HDR_STG, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 2) get datamart amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select count(*) from "$SCHEMA".KSRB240_RECN_HDR_STG " > $TMP_PATH/$JOB.240DM  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select count(*) from datamart KSRB240_RECN_HDR_STG, retcode: "$RETCODE  
      print "!!! error on select count(*) from datamart KSRB240_RECN_HDR_STG, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 3) get mainframe amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select count(*) from "$MF_SCHEMA".KSRB240_RECN_HDR_STG where updt_ts <= '"$UPDT_TS"'" > $TMP_PATH/$JOB.240MVS   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select count(*) from mainframe KSRB240_RECN_HDR_STG, retcode: "$RETCODE  
      print "!!! error on select count(*) from mainframe KSRB240_RECN_HDR_STG, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 4) compare amounts
#
if [[ $RETCODE == 0 ]]; then 
    SUM1=`cat $TMP_PATH/$JOB.240DM`
    SUM2=`cat $TMP_PATH/$JOB.240MVS`
    if [[ $SUM1 == $SUM2 ]]; then 
      print "ksrb240 sum amounts of "$SUM1" match okay"  
      print "ksrb240 sum amounts of "$SUM1" match okay"      >> $LOG_FILE  
    else
      print "!!! WARNING - ksrb240 sum amount of datamart "$SUM1" does not match mainframe "$SUM2     
      print "!!! WARNING - ksrb240 sum amount of datamart "$SUM1" does not match mainframe "$SUM2      >> $LOG_FILE  

      EMAIL_SUBJECT=$SCRIPT"_out_of_balance!"
      mailx -s $EMAIL_SUBJECT $MONITOR_EMAIL_ADDRESS < $LOG_FILE   
    fi
fi


##############################################################
#
#               sync KSRB243_RECN_SUMM
#
##############################################################

#
# 1) import into KSRB243_RECN_SUMM
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stvx "import from "$TMP_PATH"/ksrb243.dat of del modified by coldel| commitcount 2500 insert_update into "$SCHEMA".KSRB243_RECN_SUMM "   >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on import from KSRB243_RECN_SUMM, retcode: "$RETCODE  
      print "!!! error on import from KSRB243_RECN_SUMM, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 2) get datamart amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select count(*) from "$SCHEMA".KSRB243_RECN_SUMM " > $TMP_PATH/$JOB.243DM  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select count(*) from datamart KSRB243_RECN_SUMM, retcode: "$RETCODE  
      print "!!! error on select count(*) from datamart KSRB243_RECN_SUMM, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 3) get mainframe amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select count(*) from "$MF_SCHEMA".KSRB243_RECN_SUMM where updt_ts <= '"$UPDT_TS"'" > $TMP_PATH/$JOB.243MVS   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select count(*) from mainframe KSRB243_RECN_SUMM, retcode: "$RETCODE  
      print "!!! error on select count(*) from mainframe KSRB243_RECN_SUMM, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 4) compare amounts
#
if [[ $RETCODE == 0 ]]; then 
    SUM1=`cat $TMP_PATH/$JOB.243DM`
    SUM2=`cat $TMP_PATH/$JOB.243MVS`
    if [[ $SUM1 == $SUM2 ]]; then 
      print "ksrb243 sum amounts of "$SUM1" match okay"  
      print "ksrb243 sum amounts of "$SUM1" match okay"      >> $LOG_FILE  
    else
      print "!!! WARNING - ksrb243 sum amount of datamart "$SUM1" does not match mainframe "$SUM2     
      print "!!! WARNING - ksrb243 sum amount of datamart "$SUM1" does not match mainframe "$SUM2      >> $LOG_FILE  

      EMAIL_SUBJECT=$SCRIPT"_out_of_balance!"
      mailx -s $EMAIL_SUBJECT $MONITOR_EMAIL_ADDRESS < $LOG_FILE   
    fi
fi

##############################################################
#
#               sync KSRB320_FEP_GUAR_RATES
#
##############################################################

#
# 1) import into KSRB320_FEP_GUAR_RATES
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stvx "import from "$TMP_PATH"/ksrb320.dat of del modified by coldel| commitcount 2500 insert_update into "$SCHEMA".KSRB320_FEP_GUAR_RATES "   >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on import from KSRB320_FEP_GUAR_RATES, retcode: "$RETCODE  
      print "!!! error on import from KSRB320_FEP_GUAR_RATES, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 2) get datamart amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select count(*) from "$SCHEMA".KSRB320_FEP_GUAR_RATES " > $TMP_PATH/$JOB.320DM 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select count(*) from datamart KSRB320_FEP_GUAR_RATES, retcode: "$RETCODE  
      print "!!! error on select count(*) from datamart KSRB320_FEP_GUAR_RATES, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 3) get mainframe amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select count(*) from "$MF_SCHEMA".KSRB320_GUAR_RATE where last_updt_ts <= '"$UPDT_TS"'" > $TMP_PATH/$JOB.320MVS   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select count(*) from mainframe KSRB320_GUAR_RATE, retcode: "$RETCODE  
      print "!!! error on select count(*) from mainframe KSRB320_GUAR_RATE, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 4) compare amounts
#
if [[ $RETCODE == 0 ]]; then 
    SUM1=`cat $TMP_PATH/$JOB.320DM`
    SUM2=`cat $TMP_PATH/$JOB.320MVS`
    if [[ $SUM1 == $SUM2 ]]; then 
      print "ksrb320 sum amounts of "$SUM1" match okay"  
      print "ksrb320 sum amounts of "$SUM1" match okay"      >> $LOG_FILE  
    else
      print "!!! WARNING - ksrb320 sum amount of datamart "$SUM1" does not match mainframe "$SUM2     
      print "!!! WARNING - ksrb320 sum amount of datamart "$SUM1" does not match mainframe "$SUM2      >> $LOG_FILE  

      EMAIL_SUBJECT=$SCRIPT"_out_of_balance!"
      mailx -s $EMAIL_SUBJECT $MONITOR_EMAIL_ADDRESS < $LOG_FILE   
    fi
fi

##############################################################
#
#               sync KSRB310_NDC_COUNT_SUM
#
##############################################################

#
# 1) import into KSRB310_NDC_COUNT_SUM
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stvx "import from "$TMP_PATH"/ksrb310.dat of del modified by coldel| commitcount 2500 insert_update into "$SCHEMA".KSRB310_NDC_COUNT_SUM "   >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on import from KSRB310_NDC_COUNT_SUM, retcode: "$RETCODE  
      print "!!! error on import from KSRB310_NDC_COUNT_SUM, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 2) get datamart amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select count(*) from "$SCHEMA".KSRB310_NDC_COUNT_SUM " > $TMP_PATH/$JOB.310DM  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select count(*) from datamart KSRB310_NDC_COUNT_SUM, retcode: "$RETCODE  
      print "!!! error on select count(*) from datamart KSRB310_NDC_COUNT_SUM, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 3) get mainframe amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select count(*) from "$MF_SCHEMA".KSRB310_NDC_CNT_SUM where last_updt_ts <= '"$UPDT_TS"'" > $TMP_PATH/$JOB.310MVS   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select count(*) from mainframe KSRB310_NDC_CNT_SUM, retcode: "$RETCODE  
      print "!!! error on select count(*) from mainframe KSRB310_NDC_CNT_SUM, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 4) compare amounts
#
if [[ $RETCODE == 0 ]]; then 
    SUM1=`cat $TMP_PATH/$JOB.310DM`
    SUM2=`cat $TMP_PATH/$JOB.310MVS`
    if [[ $SUM1 == $SUM2 ]]; then 
      print "ksrb310 sum amounts of "$SUM1" match okay"  
      print "ksrb310 sum amounts of "$SUM1" match okay"      >> $LOG_FILE  
    else
      print "!!! WARNING - ksrb310 sum amount of datamart "$SUM1" does not match mainframe "$SUM2     
      print "!!! WARNING - ksrb310 sum amount of datamart "$SUM1" does not match mainframe "$SUM2      >> $LOG_FILE  

      EMAIL_SUBJECT=$SCRIPT"_out_of_balance!"
      mailx -s $EMAIL_SUBJECT $MONITOR_EMAIL_ADDRESS < $LOG_FILE   
    fi
fi

##############################################################
#
#               rebuild F_INV_LNAMT_SUM table
#
##############################################################
if [[ $RETCODE == 0 ]]; then 
   print `date`" Rebuilding f_inv_lnamt_sum ... "
   print `date`" Rebuilding f_inv_lnamt_sum ... "    >> $LOG_FILE  
   db2 -stvx 'declare loadcurs cursor for select pico_id_nb, ctrc_id_nb, NDC_NB, CLIN_CLNT_NB, rtrim(RBAT_BILL_YR_DT) || rtrim(RBAT_BILL_QTR_DT), RBAT_REV_TYPE_CD, sum(BILL_ORIG_AMT), sum(BILL_ADJ_PQS_AMT), sum(BILL_NET_AMT), sum(PD_AMT), sum(NET_AMT) from '$SCHEMA'.ksrb103_inv_lnamt group by pico_id_nb, ctrc_id_nb, NDC_NB, CLIN_CLNT_NB, RBAT_BILL_YR_DT, RBAT_BILL_QTR_DT, RBAT_REV_TYPE_CD  having sum(BILL_ORIG_AMT) <> 0 or sum(BILL_ADJ_PQS_AMT) <> 0 or sum(BILL_NET_AMT) <> 0 or sum(PD_AMT) <> 0 or sum(NET_AMT) <> 0   order by pico_id_nb, ctrc_id_nb, NDC_NB, CLIN_CLNT_NB, RBAT_BILL_YR_DT, RBAT_BILL_QTR_DT, RBAT_REV_TYPE_CD '  >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error rebuilding f_inv_lnamt_sum create cursor, retcode: "$RETCODE  
      print "!!! error rebuilding f_inv_lnamt_sum create cursor, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi
if [[ $RETCODE == 0 ]]; then 
   print `date`" Starting load of f_inv_lnamt_sum ... "
   print `date`" Starting load of f_inv_lnamt_sum ... "    >> $LOG_FILE  
   db2 -stvx 'load from loadcurs of cursor replace into '$SCHEMA'.F_INV_LNAMT_SUM nonrecoverable '  >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error rebuilding f_inv_lnamt_sum, load retcode: "$RETCODE  
      print "!!! error rebuilding f_inv_lnamt_sum, load retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

##############################################################
#
#               rebuild RPS.T_SL_CLIENT_SUM table
#
##############################################################
if [[ $RETCODE == 0 ]]; then 
   print `date`" Rebuilding T_SL_CLIENT_SUM ... "
   print `date`" Rebuilding T_SL_CLIENT_SUM ... "    >> $LOG_FILE  
   db2 -stvx 'declare loadcurs cursor for
        SELECT
         INV_QTR
        ,REBATE_ID
        ,RAC_ID
        ,TRAN_TYPE_CD
        ,STMT_ID
        ,SUM(AMOUNT)
       FROM rps.F_SL_CLIENT
       GROUP BY
         INV_QTR
        ,REBATE_ID
        ,RAC_ID
        ,TRAN_TYPE_CD
        ,STMT_ID
'   >> $LOG_FILE

   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error rebuilding T_SL_CLIENT_SUM create cursor, retcode: "$RETCODE  
      print "!!! error rebuilding T_SL_CLIENT_SUM create cursor, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi
if [[ $RETCODE == 0 ]]; then 
   print `date`" Starting load of T_SL_CLIENT_SUM ... "
   print `date`" Starting load of T_SL_CLIENT_SUM ... "    >> $LOG_FILE  
   db2 -stvx 'load from loadcurs of cursor replace into '$SCHEMA'.T_SL_CLIENT_SUM nonrecoverable '  >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error rebuilding T_SL_CLIENT_SUM, load retcode: "$RETCODE  
      print "!!! error rebuilding T_SL_CLIENT_SUM, load retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

##############################################################
#             disconnect db connection
##############################################################
#
# disconnect from udb
#                                                     
db2 -stvx connect reset                                                >> $LOG_FILE 
db2 -stvx quit                                                         >> $LOG_FILE 


#################################################################
# send email for script errors
#################################################################
if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "                               >> $LOG_FILE 
   EMAIL_SUBJECT=$SCRIPT
#   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   print "return_code =" $RETCODE
   exit $RETCODE
fi


print " Script " $SCRIPT " completed successfully on " `date`                              
print " Script " $SCRIPT " completed successfully on " `date`            >> $LOG_FILE 
#################################################################
# cleanup from successful run
#################################################################
rm -f $TMP_PATH/$JOB.xts 
rm -f $TMP_PATH/fesump.dat
rm -f $TMP_PATH/fesumc.dat
rm -f $TMP_PATH/ksrb103.dat
rm -f $TMP_PATH/ksrb250.dat
rm -f $TMP_PATH/ksrb300.dat
rm -f $TMP_PATH/ksrb240.dat
rm -f $TMP_PATH/ksrb243.dat
rm -f $TMP_PATH/ksrb320.dat
rm -f $TMP_PATH/$JOB.222MVS
rm -f $TMP_PATH/$JOB.222DM
rm -f $TMP_PATH/$JOB.223MVS
rm -f $TMP_PATH/$JOB.223DM
rm -f $TMP_PATH/$JOB.103MVS
rm -f $TMP_PATH/$JOB.103DM
rm -f $TMP_PATH/$JOB.250MVS
rm -f $TMP_PATH/$JOB.250DM
rm -f $TMP_PATH/$JOB.300MVS
rm -f $TMP_PATH/$JOB.300DM
rm -f $TMP_PATH/$JOB.240MVS
rm -f $TMP_PATH/$JOB.240DM
rm -f $TMP_PATH/$JOB.243MVS
rm -f $TMP_PATH/$JOB.243DM
rm -f $TMP_PATH/$JOB.320MVS
rm -f $TMP_PATH/$JOB.320DM
rm -f $TMP_PATH/$JOB.310MVS
rm -f $TMP_PATH/$JOB.310DM

mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "return_code =" $RETCODE
exit $RETCODE
