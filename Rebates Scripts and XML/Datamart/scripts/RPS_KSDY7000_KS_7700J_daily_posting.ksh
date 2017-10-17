#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSDY7000_KS_7700J_daily_posting.ksh
# Title         : Synchronize datamart with mainframe after daily process
#                 Part 1
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
# 12-07-06   qcpi03o	 added refresh of KSZ6000_PERIOD
# 12-15-06   is89501     added refresh of KSRB250_DISTR 
# 01-08-07   qcpi03o     split the load of KSRB222, KSRB223, KSRB103, KSRB250
#                         to a seperate job RPS_KSDY7000_KS_7700J_daily_posting2.ksh 
# 01-14-10   qcpi03o     updated ksrb300 extract to exclude typ 10 rows
#                         updated ksrb300 balance count to exclude typ 10 rows
#                          BSR 52023 RDS change
# 11-03-10   qcpi03o     added Cash Recon tables - ksrb240, ksrb243
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSDY7000_KS_7700J_daily_posting  
JOB=ks7700j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
RETCODE=0

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE


###################################################################
# export records of MVS fesump after daily posting
###################################################################
#
# connect to udb
#
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING                                                 >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! aborting daily posting - cant connect to udb " 
      print "!!! aborting daily posting - cant connect to udb "               >> $LOG_FILE  
   fi
fi


#
# 1) select max timestamp from local fesump as x
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx 'select max(last_updt_ts) from '$SCHEMA'.ksrb222_fesump' > $TMP_PATH/$JOB.xts   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! cant select max timestamp from fesump, retcode: "$RETCODE  
      print "!!! cant select max timestamp from fesump, retcode: "$RETCODE     >> $LOG_FILE  
   fi 
fi


#
# 2) export fesump by timestamp
#
if [[ $RETCODE == 0 ]]; then 
   XTS=`cat $TMP_PATH/$JOB.xts`
   print "fesump selection timestamp is "$XTS             
   print "fesump selection timestamp is "$XTS               >> $LOG_FILE  
   db2 -stvx "export to "$TMP_PATH"/fesump.dat of del modified by coldel| select * from "$MF_SCHEMA".ksrb222_fesump where last_updt_ts > '"$XTS"'"   >> $LOG_FILE  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! cant export from fesump, retcode: "$RETCODE  
      print "!!! cant export from fesump, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi


#
# 3) get MVS fesump amounts
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx 'select sum(fsmp_amt) from '$MF_SCHEMA'.ksrb222_fesump' > $TMP_PATH/$JOB.222MVS   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select sum(fsmp_amt) from mainframe ksrb222_fesump, retcode: "$RETCODE  
      print "!!! error on select sum(fsmp_amt) from mainframe ksrb222_fesump, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi


##############################################################
# export records from MVS FESUMC 
##############################################################
#
# 1) select max timestamp from local fesumc as x
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx 'select max(last_updt_ts) from '$SCHEMA'.ksrb223_fesumc' > $TMP_PATH/$JOB.xts   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! cant select max timestamp from fesumc, retcode: "$RETCODE  
      print "!!! cant select max timestamp from fesumc, retcode: "$RETCODE     >> $LOG_FILE  
   fi 
fi


# use this to fudge a value for catch-up if necessary  
# echo '2006-03-22-01.36.50.547070' >  $TMP_PATH/$JOB.xts 


#
# 2) export fesumc by timestamp
#
if [[ $RETCODE == 0 ]]; then 
   XTS=`cat $TMP_PATH/$JOB.xts`
   print "fesumc selection timestamp is "$XTS             
   print "fesumc selection timestamp is "$XTS               >> $LOG_FILE  
   db2 -stvx "export to "$TMP_PATH"/fesumc.dat of del modified by coldel| select * from "$MF_SCHEMA".ksrb223_fesumc where last_updt_ts > '"$XTS"'"   >> $LOG_FILE  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! cant export from fesumc, retcode: "$RETCODE  
      print "!!! cant export from fesumc, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 2B) get mainframe amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx 'select sum(fsmr_amt) from '$MF_SCHEMA'.ksrb223_fesumc' > $TMP_PATH/$JOB.223MVS   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select sum(fsmr_amt) from mainframe ksrb223_fesumc, retcode: "$RETCODE  
      print "!!! error on select sum(fsmr_amt) from mainframe ksrb223_fesumc, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi
 

##############################################################
# export records from MVS KSRB103_INV_LNAMT
##############################################################
#
# 1) select max timestamp from local ksrb103 as x
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx 'select max(last_updt_ts) from '$SCHEMA'.ksrb103_inv_lnamt' > $TMP_PATH/$JOB.xts   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! cant select max timestamp from ksrb103, retcode: "$RETCODE  
      print "!!! cant select max timestamp from ksrb103, retcode: "$RETCODE     >> $LOG_FILE  
   fi 
fi


#
# 2) export ksrb103 by timestamp
#
if [[ $RETCODE == 0 ]]; then 
   XTS=`cat $TMP_PATH/$JOB.xts`
   print "ksrb103 selection timestamp is "$XTS             
   print "ksrb103 selection timestamp is "$XTS               >> $LOG_FILE  
   db2 -stvx "export to "$TMP_PATH"/ksrb103.dat of del modified by coldel| select * from "$MF_SCHEMA".ksrb103_inv_lnamt where last_updt_ts > '"$XTS"'"   >> $LOG_FILE  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! cant export from ksrb103, retcode: "$RETCODE  
      print "!!! cant export from ksrb103, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 2B) get mainframe amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx 'select sum(net_amt) from '$MF_SCHEMA'.ksrb103_inv_lnamt' > $TMP_PATH/$JOB.103MVS
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select sum(net_amt) from mainframe ksrb103_inv_lnamt, retcode: "$RETCODE  
      print "!!! error on select sum(net_amt) from mainframe ksrb103_inv_lnamt, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi


##############################################################
#
#               sync KSRB250_DISTR
#
##############################################################
#
# 1) select max timestamp from local ksrb250 as x
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx 'select max(last_updt_ts) from '$SCHEMA'.ksrb250_distr' > $TMP_PATH/$JOB.xts   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! cant select max timestamp from ksrb250, retcode: "$RETCODE  
      print "!!! cant select max timestamp from ksrb250, retcode: "$RETCODE     >> $LOG_FILE  
   fi 
fi


#
# 2) export ksrb250 by timestamp
#
if [[ $RETCODE == 0 ]]; then 
   XTS=`cat $TMP_PATH/$JOB.xts`
   print "ksrb250 selection timestamp is "$XTS             
   print "ksrb250 selection timestamp is "$XTS               >> $LOG_FILE  
   db2 -stvx "export to "$TMP_PATH"/ksrb250.dat of del modified by coldel| select * from "$MF_SCHEMA".ksrb250_distr where last_updt_ts > '"$XTS"'"   >> $LOG_FILE  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! cant export from ksrb250, retcode: "$RETCODE  
      print "!!! cant export from ksrb250, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 2B) get mainframe amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx 'select sum(pmt_amt) from '$MF_SCHEMA'.ksrb250_distr' > $TMP_PATH/$JOB.250MVS   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select sum(pmt_amt) from mainframe ksrb250_distr, retcode: "$RETCODE  
      print "!!! error on select sum(pmt_amt) from mainframe ksrb250_distr, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi


##############################################################
#
#               sync KSRB300_COUNT_SUM to TAPC_LCM_SUMMARY
#
##############################################################
#
# 1) select max timestamp from local tapc_lcm_summary as x
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx 'select max(last_updt_ts) from '$SCHEMA'.tapc_lcm_summary' > $TMP_PATH/$JOB.xts   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! cant select max timestamp from tapc_lcm_summary, retcode: "$RETCODE  
      print "!!! cant select max timestamp from tapc_lcm_summary, retcode: "$RETCODE     >> $LOG_FILE  
   fi 
fi


#
# 2) export KSRB300_COUNT_SUM by timestamp
#
if [[ $RETCODE == 0 ]]; then 
   XTS=`cat $TMP_PATH/$JOB.xts`
   print "tapc_lcm_summary selection timestamp is "$XTS             
   print "tapc_lcm_summary selection timestamp is "$XTS               >> $LOG_FILE  
   db2 -stvx "export to "$TMP_PATH"/ksrb300.dat of del modified by coldel| select * from "$MF_SCHEMA".KSRB300_COUNT_SUM where last_updt_ts > '"$XTS"' and CLM_CNT_TYP_CD<>'10'"   >> $LOG_FILE  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! cant export from KSRB300_COUNT_SUM, retcode: "$RETCODE  
      print "!!! cant export from KSRB300_COUNT_SUM, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 2B) get mainframe amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select count(*) from "$MF_SCHEMA".KSRB300_COUNT_SUM where CLM_CNT_TYP_CD<>'10'" > $TMP_PATH/$JOB.300MVS   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select sum(SUBM_CLM_CNT) from mainframe KSRB300_COUNT_SUM, retcode: "$RETCODE  
      print "!!! error on select sum(SUBM_CLM_CNT) from mainframe KSRB300_COUNT_SUM, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi


##############################################################
#
#               sync ksrb240
#
##############################################################
#
# 1) select max timestamp from local ksrb240 as x
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select coalesce(max(UPDT_TS),'2000-01-01-01.00.05.0') from "$SCHEMA".KSRB240_RECN_HDR_STG" > $TMP_PATH/$JOB.xts   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! cant select max timestamp from KSRB240_RECN_HDR_STG, retcode: "$RETCODE  
      print "!!! cant select max timestamp from KSRB240_RECN_HDR_STG, retcode: "$RETCODE     >> $LOG_FILE  
   fi 
fi


#
# 2) export KSRB240_RECN_HDR_STG by timestamp
#
if [[ $RETCODE == 0 ]]; then 
   XTS=`cat $TMP_PATH/$JOB.xts`
   print "KSRB240_RECN_HDR_STG selection timestamp is "$XTS             
   print "KSRB240_RECN_HDR_STG selection timestamp is "$XTS               >> $LOG_FILE  
   db2 -stvx "export to "$TMP_PATH"/ksrb240.dat of del modified by coldel| select * from "$MF_SCHEMA".KSRB240_RECN_HDR_STG where updt_ts > '"$XTS"' "   >> $LOG_FILE  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! cant export from KSRB240_RECN_HDR_STG, retcode: "$RETCODE  
      print "!!! cant export from KSRB240_RECN_HDR_STG, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 2B) get mainframe amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select count(*) from "$MF_SCHEMA".KSRB240_RECN_HDR_STG " > $TMP_PATH/$JOB.240MVS   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select count(*) from mainframe KSRB240_RECN_HDR_STG, retcode: "$RETCODE  
      print "!!! error on select count(*) from mainframe KSRB240_RECN_HDR_STG, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi


##############################################################
#
#               sync ksrb243
#
##############################################################
#
# 1) select max timestamp from local KSRB243_RECN_SUMM as x
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select coalesce(max(UPDT_TS),'2000-01-01-01.00.05.0') from "$SCHEMA".KSRB243_RECN_SUMM" > $TMP_PATH/$JOB.xts   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! cant select max timestamp from KSRB243_RECN_SUMM, retcode: "$RETCODE  
      print "!!! cant select max timestamp from KSRB243_RECN_SUMM, retcode: "$RETCODE     >> $LOG_FILE  
   fi 
fi


#
# 2) export KSRB243_RECN_SUMM by timestamp
#
if [[ $RETCODE == 0 ]]; then 
   XTS=`cat $TMP_PATH/$JOB.xts`
   print "KSRB243_RECN_SUMM selection timestamp is "$XTS             
   print "KSRB243_RECN_SUMM selection timestamp is "$XTS               >> $LOG_FILE  
   db2 -stvx "export to "$TMP_PATH"/ksrb243.dat of del modified by coldel| select * from "$MF_SCHEMA".KSRB243_RECN_SUMM where updt_ts > '"$XTS"' "   >> $LOG_FILE  
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! cant export from KSRB243_RECN_SUMM, retcode: "$RETCODE  
      print "!!! cant export from KSRB243_RECN_SUMM, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi

#
# 2B) get mainframe amount
#
if [[ $RETCODE == 0 ]]; then 
   db2 -stx "select count(*) from "$MF_SCHEMA".KSRB243_RECN_SUMM " > $TMP_PATH/$JOB.243MVS   
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error on select count(*) from mainframe KSRB243_RECN_SUMM, retcode: "$RETCODE  
      print "!!! error on select count(*) from mainframe KSRB243_RECN_SUMM, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi



#    more stuff can go here

#
# refresh PCNTL_TRK  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="ksz6005"
   print "start dm_refresh_$TBLNAME "`date` 
   print "start dm_refresh_$TBLNAME "`date`                              >> $LOG_FILE 
   sqml $XML_PATH/dm_refresh_$TBLNAME.xml                                >> $LOG_FILE 
   RETCODE=$?
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date` 
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date`        >> $LOG_FILE 
fi

#
# refresh   KSZ6000_PERIOD
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="ksz6000"
   print "start dm_refresh_$TBLNAME "`date` 
   print "start dm_refresh_$TBLNAME "`date`                              >> $LOG_FILE 
   sqml $XML_PATH/dm_refresh_$TBLNAME.xml                                >> $LOG_FILE 
   RETCODE=$?
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date` 
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date`        >> $LOG_FILE 
fi


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
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   print "return_code =" $RETCODE
   exit $RETCODE
fi


# create trigger file to kick off the second part of job 7700 - load DM tables
touch $INPUT_PATH/KS7700.ready 
print " Script " $SCRIPT " completed successfully on " `date`                              
print " Script " $SCRIPT " completed successfully on " `date`            >> $LOG_FILE 

mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "return_code =" $RETCODE
exit $RETCODE
