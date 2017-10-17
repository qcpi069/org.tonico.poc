#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_missing_rbate_id_sum.ksh  
# Title         : Summary report of claims with missing rebate id's
#
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 05-07-03    N. Tucker  Initial Creation. 
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh

export CTRL_FILE="gdx_pre_gather_rpt_control_file_init.dat"

export FILE_BASE="rbate_missing_rbate_id_sum"
export SCRIPTNAME="rbate_missing_rbate_id_sum.ksh"
export LOG_FILE="rbate_missing_rbate_id_sum.log"
export SQL_FILE="rbate_missing_rbate_id_sum.sql"
export DAT_FILE="rbate_missing_rbate_id_sum.dat"
export FTP_CMDS="rbate_missing_rbate_id_sum_ftpcommands.txt"

export FTP_NT_IP=AZSHISP00

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$DAT_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$FTP_CMDS

#-------------------------------------------------------------------------#
## Set vars from input parameters
#-------------------------------------------------------------------------#
print "==================================================================="     >> $OUTPUT_PATH/$LOG_FILE
print "Starting " $SCRIPTNAME                                                   >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE

if [[ $REGION = "prod" ]];   then
     export REBATES_DIR=rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
else  
     export REBATES_DIR=rebates_integration/gMfrxrel/Y2k_comp/Rebate_Claims/SQL_reports
fi

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#
READ_VARS='
	M_CTRL_CYCLE_GID
	M_CTRL_CYCLE_START_DATE
	M_CTRL_CYCLE_END_DATE
	Q_CTRL_CYCLE_GID
	Q_CTRL_CYCLE_START_DATE
	Q_CTRL_CYCLE_END_DATE
	JUNK
'
while read $READ_VARS; do

   export QTRLY_CYCLE_GID=$Q_CTRL_CYCLE_GID
   export CYCLE_GID=$M_CTRL_CYCLE_GID
   export CYCLE_START_DATE=$M_CTRL_CYCLE_START_DATE
   export CYCLE_END_DATE=$M_CTRL_CYCLE_END_DATE

   print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
   print "Control file record read from " $OUTPUT_PATH/$CTRL_FILE               >> $OUTPUT_PATH/$LOG_FILE
   print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
   print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
   print "Values are:"                                                          >> $OUTPUT_PATH/$LOG_FILE
   print "CYCLE_GID = " $CYCLE_GID                                              >> $OUTPUT_PATH/$LOG_FILE
   print "CYCLE_START_DATE = " $CYCLE_START_DATE                                >> $OUTPUT_PATH/$LOG_FILE
   print "CYCLE_END_DATE = " $CYCLE_END_DATE                                    >> $OUTPUT_PATH/$LOG_FILE

   export DAT_FILE=$FILE_BASE'_'$CYCLE_GID'.dat'
   export FILE_OUT=$DAT_FILE

   rm -f $INPUT_PATH/$SQL_FILE
   rm -f $OUTPUT_PATH/$DAT_FILE

   print "Output file for " $CYCLE_GID " is " $OUTPUT_PATH/$DAT_FILE            >> $OUTPUT_PATH/$LOG_FILE



cat > $INPUT_PATH/rbate_missing_rbate_id_sum.sql << EOF
--alter session enable parallel dml
SET LINESIZE 100
SET TERMOUT OFF
SET PAGESIZE 0
SET NEWPAGE 0
SET SPACE 0
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF 
SET WRAP OFF
set verify off
whenever sqlerror exit 1
SPOOL $OUTPUT_PATH/$DAT_FILE

Select /*+ parallel(scr,12) parallel(scrc,12) full(scr) full(scrc) */
     scr.feed_id
    ,','                        
    ,scr.extnl_src_code
    ,','                 
    ,scr.extnl_lvl_id1
    ,','
    ,count(scr.claim_gid)                   
from 
(select /*+ parallel(alv,15) full(alv) */ *
   from dma_rbate2.s_claim_rbate_alv alv
UNION ALL
 select /*+ parallel(rxc,15) full(rxc) */ *
   from dma_rbate2.s_claim_rbate_rxc rxc
UNION ALL
 select /*+ parallel(ruc,15) full(ruc) */ *
  from dma_rbate2.s_claim_rbate_ruc ruc) scr,
                              dma_rbate2.t_rbate scrc
where scr.excpt_id IS NULL
  and scr.batch_date BETWEEN to_date('$CYCLE_START_DATE','MMDDYYYY') and to_date('$CYCLE_END_DATE','MMDDYYYY')  
  and (scrc.cycle_gid = $QTRLY_CYCLE_GID
   or scrc.cycle_gid IS NULL)
  and scr.extnl_src_code != 'NOREB'   
  and scr.claim_gid = scrc.claim_gid(+)
  and scrc.claim_gid is NULL
group by
     scr.feed_id                        
    ,scr.extnl_src_code                 
    ,scr.extnl_lvl_id1;        

quit; 
 
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE            >> $OUTPUT_PATH/$LOG_FILE

   export RETCODE=$?
   print "SQLPlus complete for " $CYCLE_GID                                     >> $OUTPUT_PATH/$LOG_FILE
   print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# Check for good return from sqlplus.                  
#-------------------------------------------------------------------------#

   if [[ $RETCODE != 0 ]]; then
      print "                                                                 " >> $OUTPUT_PATH/$LOG_FILE
      print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
      print "  Error Executing " $SCRIPT_PATH/$SCRIPTNAME                       >> $OUTPUT_PATH/$LOG_FILE
      print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  >> $OUTPUT_PATH/$LOG_FILE
      print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
            

      cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
      exit $RETCODE
   fi

#-------------------------------------------------------------------------#
# FTP the report to an NT server                  
#-------------------------------------------------------------------------#
 
   print 'Creating FTP command for PUT ' $OUTPUT_PATH/$FILE_OUT ' to ' $FTP_NT_IP >> $OUTPUT_PATH/$LOG_FILE
   print 'cd /'$REBATES_DIR                                                     >> $OUTPUT_PATH/$FTP_CMDS
   print 'put ' $OUTPUT_PATH/$FILE_OUT $FILE_OUT ' (replace'                    >> $OUTPUT_PATH/$FTP_CMDS

done < $OUTPUT_PATH/$CTRL_FILE

print 'quit'                                                                    >> $OUTPUT_PATH/$FTP_CMDS
print " "                                                                       >> $OUTPUT_PATH/$LOG_FILE
print "....Executing FTP  ...."                                                 >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE
ftp -i $FTP_NT_IP < $OUTPUT_PATH/$FTP_CMDS                                      >> $OUTPUT_PATH/$LOG_FILE

print ".... FTP complete   ...."                                                >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE


if [[ $RETCODE != 0 ]]; then
   print "                                                                 "    >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================"    >> $OUTPUT_PATH/$LOG_FILE
   print "  Error in FTP of " $OUTPUT_PATH/$FTP_CMDS                            >> $OUTPUT_PATH/$LOG_FILE
   print "  Look in " $OUTPUT_PATH/$LOG_FILE                                    >> $OUTPUT_PATH/$LOG_FILE
   print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE
            

   cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

#-------------------------------------------------------------------------#
# Copy the log file over and end the job                  
#-------------------------------------------------------------------------#

print " "                                                                       >> $OUTPUT_PATH/$LOG_FILE
print "....Completed executing " $SCRIPT_PATH/$SCRIPTNAME " ...."               >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                    >> $OUTPUT_PATH/$LOG_FILE
print "==================================================================="     >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

