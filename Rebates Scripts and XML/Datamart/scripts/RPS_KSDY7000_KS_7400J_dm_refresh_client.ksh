#!/usr/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSDY7000_KS_7400J_dm_refresh_client.ksh
# Title         : Refresh Datamart client reg tables from Oracle Silver
#
# Description   : This script will refresh the Datamart client reg tables 
#                 from Oracle Silver using the SQML utility and db2 LOAD. 
# 
# Abends        : If count parm does not match insert results then set bad 
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
# 11-01-05   qcpi768     Initial Creation.
# 06-23-06   is89501     Added reload of XREF007.
# 07-19-06   is89501     add pos eff trm dates to load of cg_client_nbr_assoc
# 08-03-06   is89501     Added refresh of KSZ6005_PCNTL_TRK
# 01-19-07   is31701     Added refresh of lrbate_id_qtr table 
# 03-02-07   is31701     Added refresh of the rps.t_sl_client_sum and the 
#                          rps.t_sl_client_pico_sum tables.   
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

  cd $SCRIPT_PATH

#####################################################
# begin script functions
#
function Refresh_Table
#   usage: Refresh_Table |tablename|, returns return code 
{       
   typeset RC
   db2 -stvx import from /dev/null of del replace into $CLIENT_SCHEMA.$1  >> $LOG_FILE 
   RC=$?
   if [[ $RC != 0 ]]; then 
	print " db2 import error truncating table "$1 
	print " db2 import error truncating table "$1                  >> $LOG_FILE
	return $RC
   fi
    
   print "start dm_refresh_$1 "  `date` 
   print "start dm_refresh_$1 "  `date`                               >> $LOG_FILE 

   sqml $XML_PATH/dm_refresh_$1.xml                                    >> $LOG_FILE 
   RC=$?
   print "retcode from dm_refresh_$1  " $RC "   "`date` 
   print "retcode from dm_refresh_$1  " $RC "   "`date`              >> $LOG_FILE 
   return $RC
}

function Reload_Table
#   usage: Reload_Table |tablename| returns return code 
#    SEL_STMT=|select stmt|, LOD_STMT=|load stmt|
{       
   typeset RC
   print "start dm_reload_"$1" "`date` 
   print "start dm_reload_"$1" "`date`  >> $LOG_FILE 

#  export from oracle to file
   ORA_SQL_FILE=$TMP_PATH/$JOB.ora
   SQL_DATA_FILE=$TMP_PATH/$JOB.$1.dat
   cat > $ORA_SQL_FILE << EOF
   set LINESIZE 400
   set TERMOUT OFF
   set PAGESIZE 0
   set NEWPAGE 0
   set SPACE 0
   set ECHO OFF
   set FEEDBACK OFF
   set HEADING OFF
   set WRAP off
   set verify off
   whenever sqlerror exit 1
   SPOOL $SQL_DATA_FILE
   alter session enable parallel dml; 
   $SEL_STMT 
   quit;
EOF
   print "********* SQL File for "$1" is **********"  >> $LOG_FILE 
   cat $ORA_SQL_FILE                                  >> $LOG_FILE
   print "********* SQL File for "$1" end *********"  >> $LOG_FILE    
   $ORA_CONNECT_STRING @$ORA_SQL_FILE
   RC=$?
   if [[ $RC != 0 ]] ; then 
       print 'ORACLE SELECTION SQL FAILED - RC is ' $RC ' error message is: ' `tail -20 $SQL_DATA_FILE` 
       print 'ORACLE SELECTION SQL FAILED - RC is ' $RC ' error message is: '  >> $LOG_FILE 
       print ' '                                                >> $LOG_FILE 
       tail -20 $SQL_DATA_FILE                                  >> $LOG_FILE
   else
       print 'ORACLE SELECTION of '$1' successful '`date`  
       print 'ORACLE SELECTION of '$1' successful '`date`      >> $LOG_FILE 
   fi 
#  import to udb from file
   if [[ $RC == 0 ]]; then
      print " starting db2 load of "$1
      print " starting db2 load of "$1                   >> $LOG_FILE
      db2 -stvx load from $SQL_DATA_FILE $LOD_STMT  >> $LOG_FILE 
      RC=$?
      if [[ $RC != 0 ]]; then 
	print " db2 import error on "$1" - retcode: "$RC
	print " db2 import error on "$1" - retcode: "$RC   >> $LOG_FILE
      else
        rm -f $SQL_DATA_FILE
      fi
   fi
   print "end dm_reload_"$1" "`date` 
   print "end dm_reload_"$1" "`date`                            >> $LOG_FILE
   return $RC
}

#
# end script functions
#####################################################

SCRIPT=RPS_KSDY7000_KS_7400J_dm_refresh_client
JOB=ks7400j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
DBMSG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.db2msg.log
TBLNAME=
SEL_STMT=
LOD_STMT=
RETCODE=0

echo $SCRIPT " start time: "`date` 
echo $SCRIPT " start time: "`date`                                     > $LOG_FILE
 
#
# check status of source database before proceeding
#
sqml $XML_PATH/dm_refresh_chkstat.xml                                  >> $LOG_FILE
export RETCODE=$?
print "sqml retcode from dm_refresh_chkstat was " $RETCODE
print "sqml retcode from dm_refresh_chkstat was " $RETCODE             >> $LOG_FILE

if [[ $RETCODE != 0 ]]; then 
   print "aborting dm_refresh due to errors " 
   print "aborting dm_refresh due to errors "                          >> $LOG_FILE 
   exit 12
fi


#
# connect to udb
#
if [[ $RETCODE == 0 ]]; then 
   $UDB_CONNECT_STRING                                                 >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "aborting dm_refresh - cant connect to udb " 
      print "aborting dm_refresh - cant connect to udb "               >> $LOG_FILE  
   fi
fi


#
# refresh client  (do not use db2 import to delete because its a MQT
#
#if [[ $RETCODE == 0 ]]; then    
#   TBLNAME="client"
#   Refresh_Table $TBLNAME
#   export RETCODE=$?
#fi
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="client"
   print "start dm_refresh_$TBLNAME "`date` 
   print "start dm_refresh_$TBLNAME "`date`                              >> $LOG_FILE 
   sqml $XML_PATH/dm_refresh_$TBLNAME.xml                                >> $LOG_FILE 
   RETCODE=$?
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date` 
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date`        >> $LOG_FILE 
fi

#
# refresh broker
#
if [[ $RETCODE == 0 ]]; then 
    TBLNAME="broker"
    Refresh_Table $TBLNAME
    export RETCODE=$?
fi

#refresh client_broker_assoc
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="client_broker_assoc"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh rpt_client
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="rpt_client"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh address
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="address"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh client_model_assoc
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="client_model_assoc"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh rac_client_assoc
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="rac_client_assoc"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh rebate_splits
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="rebate_splits"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh client_master_assoc - 1053 rows
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="client_master_assoc"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh contact
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="contact"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh rac
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="rac"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
 
#
# refresh carrier
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="carrier"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
 
#
# refresh code_desc
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="code_desc"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh master_client
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="master_client"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh system_codes - 292 rows
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="system_codes"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh comments
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="comments"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh pcs_contract
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="pcs_contract"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh enrollment_monthly
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="enrollment_monthly"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh enrollment_quarterly_util
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="enrollment_quarterly_util"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh enrollment_report_audit
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="enrollment_report_audit"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh enrollment_reporting   100,000 rows, 2 min
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="enrollment_reporting"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

 
#
# refresh final_lcm_util
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="final_lcm_util"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

 
#
# refresh mfg_rate - 7517 rows
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="mfg_rate"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
 
#
# refresh pos - 16 rows
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="pos"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
 
#
# refresh rac_contact_assoc
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="rac_contact_assoc"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
 
#
# refresh rac_dspn_fcly_assoc - 5804 rows
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="rac_dspn_fcly_assoc"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh rebate
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="rebate"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
 
#
# refresh rebate_fees
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="rebate_fees"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
 
#
# refresh rebate_invoice
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="rebate_invoice"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh split_level
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="split_level"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh split_tier_assign
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="split_tier_assign"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh mfg_st_excl    107 rows
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="mfg_st_excl"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
 
#
# refresh adv_pmnts
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="adv_pmnts"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh phmcy_excl   0 rows 
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="phmcy_excl"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh mfg_pmcy_excl    41,725 rows
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="mfg_pmcy_excl"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
 
#
# refresh setlmnts
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="setlmnts"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi


#
# refresh carrier_group   13 minutes   1,338,583 rows   4 min to extract, 
#
#if [[ $RETCODE == 0 ]]; then
#   TBLNAME="carrier_group"
#   SEL_STMT="SELECT EXTL_SRC_CD, '|', EXTL_LVL1_ID, '|', EXTL_LVL2_ID, '|', EXTL_LVL3_ID, '|', EXTL_LVL4_ID, '|', EXTL_LVL5_ID, '|', RAC, '|', CLIENT_NBR,'|',PCS_SYSTEM_ID,'|',CARRIER_GROUP_NAME,'|',CG_EFF_DT,'|',CG_TERM_DT,'|',BA_NBR,'|',AR_NBR,'|',PCS_CLIENT_NBR,'|',INSURANCE_CD,'|',EDEN_INDICATOR,'|',ECLIPS_LOAD_DT,'|',GP1,'|',GP2,'|',GP3,'|',GP4,'|',CLIENT_TYPE_ECLIPS,'|',FUNDING_TYPE,'|',LCM,'|',MDO_PHARMACY,'|',coalesce(UPDATE_USERID,'NONE'),'|',INSRT_DATE,'|' FROM "$CLIENT_SCHEMA"."$TBLNAME" order by EXTL_SRC_CD,EXTL_LVL1_ID,EXTL_LVL2_ID, EXTL_LVL3_ID,EXTL_LVL4_ID,EXTL_LVL5_ID,PCS_SYSTEM_ID ; "
#   LOD_STMT=" of del modified by coldel|,usedefaults messages "$DBMSG_FILE" replace into "$CLIENT_SCHEMA"."$TBLNAME" (EXTL_SRC_CD,EXTL_LVL1_ID,EXTL_LVL2_ID,EXTL_LVL3_ID,EXTL_LVL4_ID,EXTL_LVL5_ID,RAC,CLIENT_NBR,PCS_SYSTEM_ID,CARRIER_GROUP_NAME,CG_EFF_DT,CG_TERM_DT,BA_NBR,AR_NBR,PCS_CLIENT_NBR,INSURANCE_CD,EDEN_INDICATOR,ECLIPS_LOAD_DT,GP1,GP2,GP3,GP4,CLIENT_TYPE_ECLIPS,FUNDING_TYPE,LCM,MDO_PHARMACY,UPDATE_USERID,INSRT_DATE) nonrecoverable  "
#   Reload_Table $TBLNAME
#   export RETCODE=$?
#fi 
# refresh carrier_group   13 minutes
#    big one - 1,338,583 rows, using 8 threads
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="carrier_group"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi


#
# refresh cg_rac_assoc  - 4 minutes using LOAD , 1,416,313 rows 
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="cg_rac_assoc"
   SEL_STMT="SELECT EXTL_SRC_CD, '|', EXTL_LVL1_ID, '|', EXTL_LVL2_ID, '|', EXTL_LVL3_ID, '|', EXTL_LVL4_ID, '|', EXTL_LVL5_ID, '|', RAC, '|', RAC_EFF_DT, '|', RAC_TERM_DT, '|',  UPDATE_USERID, '|',  INSRT_DATE, '|' FROM "$CLIENT_SCHEMA"."$TBLNAME" order by EXTL_SRC_CD,EXTL_LVL1_ID,EXTL_LVL2_ID, EXTL_LVL3_ID,EXTL_LVL4_ID,EXTL_LVL5_ID,RAC,RAC_EFF_DT ; "
   LOD_STMT=" of del modified by coldel|,usedefaults messages "$DBMSG_FILE" replace into "$CLIENT_SCHEMA"."$TBLNAME"  (EXTL_SRC_CD, EXTL_LVL1_ID, EXTL_LVL2_ID, EXTL_LVL3_ID, EXTL_LVL4_ID, EXTL_LVL5_ID, RAC, RAC_EFF_DT, RAC_TERM_DT, UPDATE_USERID, INSRT_DATE)  nonrecoverable  "
   Reload_Table $TBLNAME
   export RETCODE=$?
fi

#
# refresh cg_client_nbr_assoc  - 6 minutes  1,421,119 rows 
#
#    07/19/2006
if [[ $RETCODE == 0 ]]; then
   TBLNAME="cg_client_nbr_assoc"
   SEL_STMT="SELECT EXTL_SRC_CD, '|', EXTL_LVL1_ID, '|', EXTL_LVL2_ID, '|', EXTL_LVL3_ID, '|', EXTL_LVL4_ID, '|', EXTL_LVL5_ID, '|', LPAD(TRIM(CLIENT_NBR),8,'0'), '|', CLIENT_NBR_EFF_DT, '|', CLIENT_NBR_TERM_DT, '|',  UPDATE_USERID, '|',  INSRT_DATE, '|',  POS_EFF_DT, '|',  POS_TERM_DT, '|', LAST_UPDATE_DT, '|' FROM "$CLIENT_SCHEMA"."$TBLNAME" order by EXTL_SRC_CD,EXTL_LVL1_ID,EXTL_LVL2_ID, EXTL_LVL3_ID,EXTL_LVL4_ID,EXTL_LVL5_ID,CLIENT_NBR,CLIENT_NBR_EFF_DT ; "
   LOD_STMT=" of del modified by coldel|,usedefaults messages "$DBMSG_FILE" replace into "$CLIENT_SCHEMA"."$TBLNAME"  (EXTL_SRC_CD, EXTL_LVL1_ID, EXTL_LVL2_ID, EXTL_LVL3_ID, EXTL_LVL4_ID, EXTL_LVL5_ID, CLIENT_NBR, CLIENT_NBR_EFF_DT, CLIENT_NBR_TERM_DT, UPDATE_USERID, INSRT_DATE, POS_EFF_DT, POS_TERM_DT, LAST_UPDATE_DT)  nonrecoverable  "
   Reload_Table $TBLNAME
   export RETCODE=$?
fi



##############################################################
#
#               rebuild XREF007 table
#
##############################################################
if [[ $RETCODE == 0 ]]; then 
   print `date`" Reloading xref007 ... "
   print `date`" Reloading xref007 ... "    >> $LOG_FILE  
   db2 -stvx 'declare loadcurs cursor for select CG_NB, EXTL_SRC_CD, EXTL_HRCY_LVL1, EXTL_HRCY_LVL2, EXTL_HRCY_LVL3, EXTL_HRCY_LVL4, EXTL_HRCY_LVL5 FROM '$MF_SCHEMA'.XREF007 ORDER BY 1 '  >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error reloading xref007 create cursor, retcode: "$RETCODE  
      print "!!! error reloading xref007 create cursor, retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi
if [[ $RETCODE == 0 ]]; then 
   print `date`" Starting load of xref007 ... "
   print `date`" Starting load of xref007 ... "    >> $LOG_FILE  
   db2 -stvx 'load from loadcurs of cursor replace into '$SCHEMA'.XREF007 nonrecoverable '  >> $LOG_FILE 
   export RETCODE=$?
   if [[ $RETCODE != 0 ]]; then 
      print "!!! error reloading xref007, load retcode: "$RETCODE  
      print "!!! error reloading xref007, load retcode: "$RETCODE     >> $LOG_FILE  
   fi
fi


#
# PCNTL_TRK  (do not use db2 import to delete )
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
# refresh   trbate_id_qtr table
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="rebate_id_qtr"
   print "start dm_refresh_$TBLNAME "`date` 
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE
   sqml $XML_PATH/dm_refresh_$TBLNAME.xml                                 >> $LOG_FILE
   RETCODE=$?
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date`
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date`         >> $LOG_FILE
fi

#
# truncate RPS.T_SL_CLIENT_PICO_SUM table
#

if [[ $RETCODE == 0 ]]; then
	print "truncating RPS.T_SL_CLIENT_PICO_SUM  "`date`                               >> $LOG_FILE
#	db2 -stvx import from /dev/null of del replace into RPS.T_SL_CLIENT_PICO_SUM      >> $LOG_FILE 
        RETCODE=$?
        print "retcode from RPS.T_SL_CLIENT_PICO_SUM truncate is " $RETCODE "   "`date`
fi

#
# refresh RPS.T_SL_CLIENT_PICO_SUM table
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="t_sl_client_pico_sum"
   print "start dm_refresh_$TBLNAME "`date` 
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE
#   sqml $XML_PATH/dm_refresh_$TBLNAME.xml                                 >> $LOG_FILE
   RETCODE=$?
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date`
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date`         >> $LOG_FILE
fi

#
# truncate RPS.T_SL_CLIENT_SUM table
#

if [[ $RETCODE == 0 ]]; then
	print "truncating RPS.T_SL_CLIENT_SUM  "`date`                               >> $LOG_FILE
	db2 -stvx import from /dev/null of del replace into RPS.T_SL_CLIENT_SUM      >> $LOG_FILE 
        RETCODE=$?
        print "retcode from RPS.T_SL_CLIENT_SUM truncate is " $RETCODE "   "`date`
fi

#
# refresh RPS.T_SL_CLIENT_SUM table
#
if [[ $RETCODE == 0 ]]; then
   TBLNAME="t_sl_client_sum"
   print "start dm_refresh_$TBLNAME "`date` 
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE
   sqml $XML_PATH/dm_refresh_$TBLNAME.xml                                 >> $LOG_FILE
   RETCODE=$?
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date`
   print "retcode from dm_refresh_$TBLNAME " $RETCODE "   "`date`         >> $LOG_FILE
fi



#
# disconnect from udb
#                                                     
db2 -stvx connect reset                                                >> $LOG_FILE 
db2 -stvx quit                                                         >> $LOG_FILE 


echo $SCRIPT " end time: "`date`                                      
echo $SCRIPT " end time: "`date`                                       >> $LOG_FILE 

#
# send email for script errors
#
if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "                          >> $LOG_FILE 
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   exit $RETCODE
fi

rm -f $TMP_PATH/$JOB.ora
rm -f $DBMSG_FILE* 

mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "return_code =" $RETCODE
exit $RETCODE
