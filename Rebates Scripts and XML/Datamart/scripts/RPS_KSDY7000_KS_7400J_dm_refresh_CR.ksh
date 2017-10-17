#!/usr/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSDY7000_KS_7400J_dm_refresh_CR.ksh
# Title         : Refresh Datamart client reg tables from GDX
#
# Description   : This script will refresh the Datamart client reg tables 
#                 from GDX using the SQML utility and db2 LOAD. 
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
# 07-06-09   qcpi03o     Initial Creation.
#-------------------------------------------------------------------------#
# ---------  ----------  -------------------------------------------------#
# 02-09-12   qcpi0rb     Rebate changes to add three new table 
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

  cd $SCRIPT_PATH

#####################################################
# begin script functions
#####################################################
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

#  export from UDB table to file
   SEL_SQL_FILE=$TMP_PATH/$JOB.sql
   SQL_DATA_FILE=$TMP_PATH/$JOB.$1.dat
   cat > $SEL_SQL_FILE << EOF
   export to $SQL_DATA_FILE of del 
   $SEL_STMT 
EOF
   print "********* SQL File for "$1" is **********"  >> $LOG_FILE 
   cat $SEL_SQL_FILE                                  >> $LOG_FILE
   print "********* SQL File for "$1" end *********"  >> $LOG_FILE    
   db2 -stvx $SEL_SQL_FILE
   RC=$?
   if [[ $RC != 0 ]] ; then 
       print 'UDB SELECTION SQL FAILED - RC is ' $RC ' error message is: ' `tail -20 $SQL_DATA_FILE` 
       print 'UDB SELECTION SQL FAILED - RC is ' $RC ' error message is: '  >> $LOG_FILE 
       print ' '                                                >> $LOG_FILE 
       tail -20 $SQL_DATA_FILE                                  >> $LOG_FILE
   else
       print 'UDB SELECTION of '$1' successful '`date`  
       print 'UDB SELECTION of '$1' successful '`date`      >> $LOG_FILE 
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

SCRIPT=RPS_KSDY7000_KS_7400J_dm_refresh_CR
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
#sqml $XML_PATH/dm_refresh_chkstat.xml                                  >> $LOG_FILE
export RETCODE=$?
print "sqml retcode from dm_refresh_chkstat was " $RETCODE
print "sqml retcode from dm_refresh_chkstat was " $RETCODE             >> $LOG_FILE

if [[ $RETCODE != 0 ]]; then 
   print "aborting dm_refresh due to errors - db chkstat" 
   print "aborting dm_refresh due to errors - db chkstat"              >> $LOG_FILE 
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
# refresh crt_clnt  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_clnt"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_mstr_clnt  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_mstr_clnt"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_clnt_brkr_assc  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_clnt_brkr_assc"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_brkr
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_brkr"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_rtmd_prc  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_rtmd_prc"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_cdset  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_cdset"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_cdset_vl  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_cdset_vl"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_extl_hrcy  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_extl_hrcy"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_clnt_extl_hrcy_assc  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_clnt_extl_hrcy_assc"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_clnt_rule_assc  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_clnt_rule_assc"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_clnt_prc_pool_assc  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_clnt_prc_pool_assc"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_prc_mstr  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_prc_mstr"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_prc_pool  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_prc_pool"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_prc_rule  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_prc_rule"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_prc_term_adv_pmt  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_prc_term_adv_pmt"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_prc_term_shr  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_prc_term_shr"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_prc_term_guar  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_prc_term_guar"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_prc_tier  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_prc_tier"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi


#
# refresh crt_prd  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_prd"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_prcs  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_prcs"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_prcs_stat  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_prcs_stat"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_addr  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_addr"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_be_addr_assc  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_be_addr_assc"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_extl_hrcy_lcm_assc  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_extl_hrcy_lcm_assc"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_note  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_note"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_load_gl_addr  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_load_gl_addr"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_hold_miss_rbat_id_que  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_hold_miss_rbat_id_que"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_pos_file_xprt  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_pos_file_xprt"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_mfg_load_err  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_mfg_load_err"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_mfg_pmcy_excl  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_mfg_pmcy_excl"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_mfg_pmcy_excl_load  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_mfg_pmcy_excl_load"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_mfg_rate  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_mfg_rate"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_mfg_rate_load  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_mfg_rate_load"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_mfg_st_excl  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_mfg_st_excl"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_mfg_st_excl_load  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_mfg_st_excl_load"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#****** Begin Rebates changes - 02-09-12 #

#
# refresh crt_ct_id  
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_ct_id"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_rbat_id_ct_id_assc   
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_rbat_id_ct_id_assc"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#
# refresh crt_ct_id_char 
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="crt_ct_id_char"
   print "start dm_refresh_$TBLNAME "`date`                               >> $LOG_FILE 
   Refresh_Table $TBLNAME
   RETCODE=$?
fi

#****** End Rebates changes - 02-09-12 #

#
# rebuild base table t_rebate_id_qtr_base
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="t_rebate_id_qtr_base"
   print "start dm_refresh_$TBLNAME "`date`                                       >> $LOG_FILE 
   db2 -stvx import from /dev/null of del replace into $SCHEMA.$TBLNAME    >> $LOG_FILE 
   RETCODE=$?
   if [[ $RETCODE == 0 ]]; then 
   	sqml $XML_PATH/dm_refresh_$TBLNAME.xml                                    >> $LOG_FILE 
   	RETCODE=$?
   else
	print " db2 import error truncating table "$TBLNAME 
	print " db2 import error truncating table "$TBLNAME                       >> $LOG_FILE
   fi
fi

#
# rebuild base table t_rac_qtr_base
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="t_rac_qtr_base"
   print "start dm_refresh_$TBLNAME "`date`                                       >> $LOG_FILE 
   db2 -stvx import from /dev/null of del replace into $SCHEMA.$TBLNAME    >> $LOG_FILE 
   RETCODE=$?
   if [[ $RETCODE == 0 ]]; then 
   	sqml $XML_PATH/dm_refresh_$TBLNAME.xml                                    >> $LOG_FILE 
   	RETCODE=$?
   else
	print " db2 import error truncating table "$TBLNAME 
	print " db2 import error truncating table "$TBLNAME                       >> $LOG_FILE
   fi
fi


#
# rebuild base table t_advance_base
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="t_advance_base"
   print "start dm_refresh_$TBLNAME "`date`                                       >> $LOG_FILE 
   db2 -stvx import from /dev/null of del replace into $SCHEMA.$TBLNAME    >> $LOG_FILE 
   RETCODE=$?
   if [[ $RETCODE == 0 ]]; then 
   	sqml $XML_PATH/dm_refresh_$TBLNAME.xml                                    >> $LOG_FILE 
   	RETCODE=$?
   else
	print " db2 import error truncating table "$TBLNAME 
	print " db2 import error truncating table "$TBLNAME                       >> $LOG_FILE
   fi
fi

#
# rebuild base table t_splits_pricing_base
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="t_splits_pricing_base"
   print "start dm_refresh_$TBLNAME "`date`                                       >> $LOG_FILE 
   db2 -stvx import from /dev/null of del replace into $SCHEMA.$TBLNAME    >> $LOG_FILE 
   RETCODE=$?
   if [[ $RETCODE == 0 ]]; then 
   	sqml $XML_PATH/dm_refresh_$TBLNAME.xml                                    >> $LOG_FILE 
   	RETCODE=$?
   else
	print " db2 import error truncating table "$TBLNAME 
	print " db2 import error truncating table "$TBLNAME                       >> $LOG_FILE
   fi
fi

#
# rebuild base table t_splits_base for business view L_splits
#
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="t_splits_base"
   print "start dm_refresh_$TBLNAME "`date`                                       >> $LOG_FILE 
   db2 -stvx import from /dev/null of del replace into $SCHEMA.$TBLNAME    >> $LOG_FILE 
   RETCODE=$?
   if [[ $RETCODE == 0 ]]; then 
   	sqml $XML_PATH/dm_refresh_L_splits.xml                                    >> $LOG_FILE 
   	RETCODE=$?
   else
	print " db2 import error truncating table "$TBLNAME 
	print " db2 import error truncating table "$TBLNAME                       >> $LOG_FILE
   fi
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



##############################################################
# disconnect from udb
##############################################################
db2 -stvx connect reset                                                >> $LOG_FILE 
db2 -stvx quit                                                         >> $LOG_FILE 


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

rm -f $DBMSG_FILE* 

mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "return_code =" $RETCODE
exit $RETCODE
