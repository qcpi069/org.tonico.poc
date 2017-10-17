#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_RIOR4500_RI_4506J_client_lcm_cnts.ksh   
# Title         : LCM Claim Count Feed
#
# Description   : Create a summary file of Client claim counts by LCM/Revenue Type.
# Maestro Sched : RIOR4500
# Maestro Job   : RI_4506J
#
# Parameters    : CYCLE_GID
#
# Output        : Log file as $OUTPUT_PATH/rbate_RIQT4500_RI_4506J_client_lcm_cnts.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Parte    Description
# ---------  ----------  -------  -------------------------------------------------#
# 06-28-04    IS73701    5994785  Initial Creation.
# 03-18-05    IS23301    6002298  Add changes for new LCM splits for brand/generic
# 06-24-2005  is23301             Oracle 10G change to spool to .lst files.
# 06-02-2006  is23301             Changed to send to KSZ4970J extension instead of KSZ4800J.
#                                    This is to allow for an audit to occur on MVS prior to load.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

#Always build these variables/values

if [[ $REGION = "prod" ]];   then
  if [[ $QA_REGION = "true" ]];   then
    # Running in the QA region
    export ALTER_EMAIL_ADDRESS='kurt.gries@caremark.com'
    export MVS_FTP_PREFIX='TEST.X'
    export SCHEMA_OWNER="dma_rbate2"
  else
    # Running in Prod region
    export ALTER_EMAIL_ADDRESS=''
    export MVS_FTP_PREFIX='PCS.P'
    export SCHEMA_OWNER="dma_rbate2"
  fi
else
  # Running in Development region
  export ALTER_EMAIL_ADDRESS='kurt.gries@caremark.com'
  export MVS_FTP_PREFIX='TEST.X'
  export SCHEMA_OWNER="dma_rbate2"
fi

#Export the variables needed for the source file location and the NT Server
export FTP_IP='204.99.4.30'
export SCHEDULE="RIOR4500"
export JOB="RI_4506J"
export LCM_OUTPUT_DIR=$OUTPUT_PATH/lcm
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_client_lcm_cnts"
export SCRIPTNAME=$FILE_BASE".ksh"
export LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
export LOG_ARCH=$FILE_BASE".log"
export SQL_FILE=$LCM_OUTPUT_DIR/$FILE_BASE".sql"
export SQL_PIPE_FILE=$LCM_OUTPUT_DIR/$FILE_BASE"_pipe.lst"
export DAT_FILE=$LCM_OUTPUT_DIR/$FILE_BASE".dat"
export TRG_FILE=$LCM_OUTPUT_DIR/$FILE_BASE".trg"
export MVS_FTP_COM_FILE=$LCM_OUTPUT_DIR/$FILE_BASE"_ftpcommands.txt" 
export MVS_FTP_TRG=" '"$MVS_FTP_PREFIX".KSZ4970J.LCM.CLAIM.COUNTS.TRIGGER'"
export MVS_FTP_DAT=" '"$MVS_FTP_PREFIX".KSZ4970J.LCM.CLAIM.COUNTS'"

export SQL_FILE_CYCLE_GID=$LCM_OUTPUT_DIR/$FILE_BASE"_cycle_gid.sql"
export CYCLE_GID_FILE=$LCM_OUTPUT_DIR/$FILE_BASE"_cycle_gid_file.dat"


rm -f $LOG_FILE
rm -f $DAT_FILE
rm -f $SQL_FILE
rm -f $SQL_PIPE_FILE
rm -f $TRG_FILE
rm -f $MVS_FTP_COM_FILE
rm -f $SQL_FILE_CYCLE_GID
rm -f $CYCLE_GID_FILE

print "Starting "$SCRIPTNAME >> $LOG_FILE
print `date` >> $LOG_FILE

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
#
# Table_Name ir the table to be refreshed
# Refresh_Type is the type of refresh where C=Complete
# Package_Name is the PL/SQL procedure to call the snapshot
# PKGEXEC is the full SQL command to be executed
#-------------------------------------------------------------------------#

#----------------------------------
# Oracle userid/password
#----------------------------------
db_user_password=`cat $SCRIPT_PATH/ora_user.fil`
#----------------------------------

CYCLE_GID=$1

print " " >> $LOG_FILE
print "CYCLE_GID is " $CYCLE_GID >> $LOG_FILE
print ' ' >> $LOG_FILE

if [ $# -lt 1 ]; then 

   print " " >> $LOG_FILE
   print "Cycle Gid was not passed...retrieving max rbate_cycle_gid from t_rbate_cycle" >> $LOG_FILE
   print " " >> $LOG_FILE

cat > $SQL_FILE_CYCLE_GID << EOF
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
SPOOL $CYCLE_GID_FILE
alter session enable parallel dml; 

Select max(rbate_cycle_gid)
      ,' '
      ,substrb(max(rbate_cycle_gid),1,4)
      ,' '
      ,substrb(max(rbate_cycle_gid),6,1)
      ,' '
      ,substrb(MAX(rbate_cycle_gid),1,4)||decode(substrb(MAX(rbate_cycle_gid),6,1),1,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+1)
                                                                                  ,2,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+1)
                                                                                  ,3,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+1)
                                                                                  ,4,     (((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+1))
      ,' '
      ,substrb(MAX(rbate_cycle_gid),1,4)||decode(substrb(MAX(rbate_cycle_gid),6,1),1,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+2)
                                                                                  ,2,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+2)
                                                                                  ,3,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+2)
                                                                                  ,4,     (((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+2))     
      ,' '
      ,substrb(MAX(rbate_cycle_gid),1,4)||decode(substrb(MAX(rbate_cycle_gid),6,1),1,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+3)
                                                                                  ,2,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+3)
                                                                                  ,3,'0'||(((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+3)
                                                                                  ,4,     (((substrb(MAX(rbate_cycle_gid),6,1)-1)*3)+3))     
From $SCHEMA_OWNER.t_rbate_cycle
Where rbate_cycle_type_id = 2
And rbate_cycle_status = 'C';

quit;   
EOF

   $ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE_CYCLE_GID

   export RETCODE=$?

else

   print " " >> $LOG_FILE
   print "Cycle Gid was passed...calculating MonthGIDs from value " $CYCLE_GID >> $LOG_FILE
   print " " >> $LOG_FILE

cat > $SQL_FILE_CYCLE_GID << EOF
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
SPOOL $CYCLE_GID_FILE
alter session enable parallel dml; 


Select '$CYCLE_GID'
      ,' '
      ,substrb('$CYCLE_GID',1,4)
      ,' '
      ,substrb('$CYCLE_GID',6,1)
      ,' '
      ,substrb($CYCLE_GID,1,4)||decode(substrb($CYCLE_GID,6,1),1,'0'||(((substrb($CYCLE_GID,6,1)-1)*3)+1)
                                                              ,2,'0'||(((substrb($CYCLE_GID,6,1)-1)*3)+1)
                                                              ,3,'0'||(((substrb($CYCLE_GID,6,1)-1)*3)+1)
                                                              ,4,     (((substrb($CYCLE_GID,6,1)-1)*3)+1))
      ,' '
      ,substrb($CYCLE_GID,1,4)||decode(substrb($CYCLE_GID,6,1),1,'0'||(((substrb($CYCLE_GID,6,1)-1)*3)+2)
                                                              ,2,'0'||(((substrb($CYCLE_GID,6,1)-1)*3)+2)
                                                              ,3,'0'||(((substrb($CYCLE_GID,6,1)-1)*3)+2)
                                                              ,4,     (((substrb($CYCLE_GID,6,1)-1)*3)+2))     
      ,' '
      ,substrb($CYCLE_GID,1,4)||decode(substrb($CYCLE_GID,6,1),1,'0'||(((substrb($CYCLE_GID,6,1)-1)*3)+3)
                                                              ,2,'0'||(((substrb($CYCLE_GID,6,1)-1)*3)+3)
                                                              ,3,'0'||(((substrb($CYCLE_GID,6,1)-1)*3)+3)
                                                              ,4,     (((substrb($CYCLE_GID,6,1)-1)*3)+3))     
    From dual;

quit;   
EOF

   $ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE_CYCLE_GID

   export RETCODE=$?
   
fi



   #-------------------------------------------------------------------------#
   # Read the returned cycle_gid
   # SQL.
   #-------------------------------------------------------------------------#
#   while read rec_CYCLE_GID rec_YEAR rec_QTR_IND rec_MTH1 rec_MTH2 rec_MTH3; do#
#      print 'read record from cycle gid file'       >> $LOG_FILE
#      print 'rec_CYCLE_GID is ' $rec_CYCLE_GID      >> $LOG_FILE
#      print 'rec_YEAR is ' $rec_YEAR                >> $LOG_FILE
#      print 'rec_QTR_IND is ' $rec_QTR_IND          >> $LOG_FILE
#      print 'rec_MTH1 is ' $rec_MTH1                >> $LOG_FILE
#      print 'rec_MTH2 is ' $rec_MTH2                >> $LOG_FILE
#      print 'rec_MTH3 is ' $rec_MTH3                >> $LOG_FILE
#   done < $CYCLE_GID_FILE
   
   read rec_CYCLE_GID rec_YEAR rec_QTR_IND rec_MTH1 rec_MTH2 rec_MTH3 < $CYCLE_GID_FILE
    
   print 'read record from cycle gid file'       >> $LOG_FILE
   print 'rec_CYCLE_GID is ' $rec_CYCLE_GID      >> $LOG_FILE
   print 'rec_YEAR is ' $rec_YEAR                >> $LOG_FILE
   print 'rec_QTR_IND is ' $rec_QTR_IND          >> $LOG_FILE
   print 'rec_MTH1 is ' $rec_MTH1                >> $LOG_FILE
   print 'rec_MTH2 is ' $rec_MTH2                >> $LOG_FILE
   print 'rec_MTH3 is ' $rec_MTH3                >> $LOG_FILE
   CYCLE_GID=$rec_CYCLE_GID
   print 'CYCLE_GID is ' $CYCLE_GID >> $LOG_FILE

#-------------------------------------------------------------------------#
# Derive Monthly Cycle Gids from the Quarter Cycle Gid
#-------------------------------------------------------------------------#

MTH1_CYCLE_GID=$rec_MTH1
MTH2_CYCLE_GID=$rec_MTH2 
MTH3_CYCLE_GID=$rec_MTH3 

print '$MTH1_CYCLE_GID ' $MTH1_CYCLE_GID >> $LOG_FILE
print '$MTH2_CYCLE_GID ' $MTH2_CYCLE_GID >> $LOG_FILE
print '$MTH3_CYCLE_GID ' $MTH3_CYCLE_GID >> $LOG_FILE
   
#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script
#-------------------------------------------------------------------------#


print ' ' >> $LOG_FILE
print "Executing LCM Claim Counts Extract SQL" >> $LOG_FILE
print `date` >> $LOG_FILE


#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#

mkfifo $SQL_PIPE_FILE
dd if=$SQL_PIPE_FILE of=$DAT_FILE bs=100k &

cat > $SQL_FILE << EOF
set LINESIZE 184
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
SPOOL $SQL_PIPE_FILE
alter session enable parallel dml; 

Select /*+ 
       ordered 
       parallel(e,8) 
       parallel(q,8) 
       full(e) 
       full(q) 
       use_hash(e)  
       */  
substrb(to_char(nvl(q.rbate_id,0),'00000000'),2,8) rbate_id,
ltrim(rpad(nvl(q.extnl_src_code,' '), 5)) extnl_src_code,
rpad(nvl(q.extnl_lvl_id1,   ' '), 20) extnl_lvl_id1,
rpad(nvl(q.extnl_lvl_id2,   ' '), 20) extnl_lvl_id2,
rpad(nvl(q.extnl_lvl_id3,   ' '), 20) extnl_lvl_id3,
rpad(nvl(q.extnl_lvl_id4,   ' '), 20) extnl_lvl_id4,
rpad(nvl(q.extnl_lvl_id5,   ' '), 20) extnl_lvl_id5,
substrb(q.cycle_gid, 1, 4)||  
decode(substrb(q.cycle_gid,5,2), 
41, 'Q1', 01, 'Q1', 02, 'Q1', 03, 'Q1', 
42, 'Q2', 04, 'Q2', 05, 'Q2', 06, 'Q2', 
43, 'Q3', 07, 'Q3', 08, 'Q3', 09, 'Q3', 
44, 'Q4', 10, 'Q4', 11, 'Q4', 12, 'Q4', 
substrb(q.cycle_gid,5,2)) cycle_gid,
rpad('1',2) REC_TYPE,
rpad(decode(nvl(q.lcm_code,'0'),'4M','3M',nvl(q.lcm_code,'0')),2) lcm_code,
rpad(nvl(q.mail_order_code,'0'), 1) mail_order_code,
substrb(to_char(sum(decode((nvl(q.rbate_access, 0) + nvl(q.rbate_mrkt_shr, 0)), 0, 0, decode(q.claim_type, 1, 1, -1 ))),'S000000000'),1,10) ,
substrb(to_char(sum(decode(q.claim_type,1,(e.rbated_excpt_id + e.submttd_excpt_id),(e.rbated_excpt_id + e.submttd_excpt_id)*-1)), 'S000000000'),1,10) ,
substrb(to_char(sum(case when (nvl(scr.srx_drug_flg,0) = '1' and decode((nvl(q.rbate_access, 0) + nvl(q.rbate_mrkt_shr, 0)), 0, 0, 1) = 1 and nvl(scr.gnrc_ind,1) in (0,1)) 
                          then decode(q.claim_type, 1, 1, -1 )
                          else 0 
					end)
              ,'S000000000'),1,10) ,
substrb(to_char(sum(case when (nvl(scr.srx_drug_flg,0) = '1' and (e.RBATED_EXCPT_ID = 1 or e.SUBMTTD_EXCPT_ID = 1) and nvl(scr.gnrc_ind,1) in (0,1)) 
                         then decode(q.claim_type, 1, 1, -1 )
                         else 0
					end)
              ,'S000000000'),1,10),
substrb(to_char(sum(case when (scr.user_field6_flag = '1' and decode((nvl(q.rbate_access, 0) + nvl(q.rbate_mrkt_shr, 0)), 0, 0, 1) = 1 and nvl(scr.gnrc_ind,1) in (0,1)) 
                         then decode(q.claim_type, 1, 1, -1 )
                         else 0
					end)
              ,'S000000000'),1,10) ,
substrb(to_char(sum(case when (scr.user_field6_flag = '1' and (e.RBATED_EXCPT_ID = 1 or e.SUBMTTD_EXCPT_ID = 1) and nvl(scr.gnrc_ind,1) in (0,1)) 
                         then decode(q.claim_type, 1, 1, -1 )
                         else 0
					end)
              ,'S000000000'),1,10)               
from      dma_rbate2.t_excpt_code e,
      dma_rbate2.tmp_qtr_results q,
      dma_rbate2.V_COMBINED_SCR scr
where q.excpt_id = e.excpt_id
     and q.pymt_sys_elig_cd = '1'
     and q.cycle_gid in ($CYCLE_GID,$MTH1_CYCLE_GID,$MTH2_CYCLE_GID,$MTH3_CYCLE_GID)
     and q.claim_gid = scr.claim_gid
     and scr.excpt_id is null
     and scr.batch_date between 
              (select cycle_start_date from dma_rbate2.t_rbate_cycle where rbate_cycle_gid = $CYCLE_GID) 
          and (select cycle_end_date from dma_rbate2.t_rbate_cycle where rbate_cycle_gid = $CYCLE_GID)  
    group by 
to_char(nvl(q.rbate_id,0),  '00000000'), 
rpad(nvl(q.extnl_src_code,  ' '), 5),
rpad(nvl(q.extnl_lvl_id1,   ' '), 20),
rpad(nvl(q.extnl_lvl_id2,   ' '), 20),
rpad(nvl(q.extnl_lvl_id3,   ' '), 20),
rpad(nvl(q.extnl_lvl_id4,   ' '), 20),
rpad(nvl(q.extnl_lvl_id5,   ' '), 20),
substrb(q.cycle_gid, 1, 4) || 
decode(substrb(q.cycle_gid,5,2), 
41, 'Q1', 01, 'Q1', 02, 'Q1', 03, 'Q1', 
42, 'Q2', 04, 'Q2', 05, 'Q2', 06, 'Q2', 
43, 'Q3', 07, 'Q3', 08, 'Q3', 09, 'Q3', 
44, 'Q4', 10, 'Q4', 11, 'Q4', 12, 'Q4', 
substrb(q.cycle_gid,5,2)),
rpad('1',2),
rpad(decode(nvl(q.lcm_code,'0'),'4M','3M',nvl(q.lcm_code,'0')),2),
rpad(nvl(q.mail_order_code, '0'), 1)
union 
Select /*+ 
       ordered 
       parallel(e,8) 
       parallel(q,8) 
       full(e) 
       full(q) 
       use_hash(e)  
       */  
substrb(to_char(nvl(q.rbate_id,0),'00000000'),2,8) rbate_id,
ltrim(rpad(nvl(q.extnl_src_code,' '), 5)) extnl_src_code,
rpad(nvl(q.extnl_lvl_id1,   ' '), 20) extnl_lvl_id1,
rpad(nvl(q.extnl_lvl_id2,   ' '), 20) extnl_lvl_id2,
rpad(nvl(q.extnl_lvl_id3,   ' '), 20) extnl_lvl_id3,
rpad(nvl(q.extnl_lvl_id4,   ' '), 20) extnl_lvl_id4,
rpad(nvl(q.extnl_lvl_id5,   ' '), 20) extnl_lvl_id5,
substrb(q.cycle_gid, 1, 4)||  
decode(substrb(q.cycle_gid,5,2), 
41, 'Q1', 01, 'Q1', 02, 'Q1', 03, 'Q1', 
42, 'Q2', 04, 'Q2', 05, 'Q2', 06, 'Q2', 
43, 'Q3', 07, 'Q3', 08, 'Q3', 09, 'Q3', 
44, 'Q4', 10, 'Q4', 11, 'Q4', 12, 'Q4', 
substrb(q.cycle_gid,5,2)) cycle_gid,
rpad('2',2) REC_TYPE,
rpad(decode(nvl(q.lcm_code,'0'),'4M','3M',nvl(q.lcm_code,'0')),2) lcm_code,
rpad(nvl(q.mail_order_code,'0'), 1) mail_order_code,
substrb(to_char(sum(case when (decode((nvl(q.rbate_access, 0) + nvl(q.rbate_mrkt_shr, 0)), 0, 0, 1) = 1 and nvl(scr.gnrc_ind,1) in (0)) 
                          then decode(q.claim_type, 1, 1, -1 )
                          else 0 
					end)
              ,'S000000000'),1,10) ,
substrb(to_char(sum(case when ( nvl(scr.gnrc_ind,1) in (0)) 
                          then decode(q.claim_type, 1, (e.rbated_excpt_id + e.submttd_excpt_id), (e.rbated_excpt_id + e.submttd_excpt_id)*(-1) )
                          else 0 
					end)
              ,'S000000000'),1,10) ,
substrb(to_char(sum(case when (nvl(scr.srx_drug_flg,0) = '1' and decode((nvl(q.rbate_access, 0) + nvl(q.rbate_mrkt_shr, 0)), 0, 0, 1) = 1 and nvl(scr.gnrc_ind,1) in (0)) 
                          then decode(q.claim_type, 1, 1, -1 )
                          else 0 
					end)
              ,'S000000000'),1,10) ,
substrb(to_char(sum(case when (nvl(scr.srx_drug_flg,0) = '1' and (e.RBATED_EXCPT_ID = 1 or e.SUBMTTD_EXCPT_ID = 1) and nvl(scr.gnrc_ind,1) in (0)) 
                         then decode(q.claim_type, 1, 1, -1 )
                         else 0
					end)
              ,'S000000000'),1,10) ,
substrb(to_char(sum(case when (scr.user_field6_flag = '1' and decode((nvl(q.rbate_access, 0) + nvl(q.rbate_mrkt_shr, 0)), 0, 0, 1) = 1 and nvl(scr.gnrc_ind,1) in (0)) 
                         then decode(q.claim_type, 1, 1, -1 )
                         else 0
					end)
              ,'S000000000'),1,10) ,
substrb(to_char(sum(case when (scr.user_field6_flag = '1' and (e.RBATED_EXCPT_ID = 1 or e.SUBMTTD_EXCPT_ID = 1) and nvl(scr.gnrc_ind,1) in (0)) 
                         then decode(q.claim_type, 1, 1, -1 )
                         else 0
					end)
              ,'S000000000'),1,10)               
from      dma_rbate2.t_excpt_code e,
      dma_rbate2.tmp_qtr_results q,
      dma_rbate2.V_COMBINED_SCR scr
where q.excpt_id = e.excpt_id
     and q.pymt_sys_elig_cd = '1'
     and q.cycle_gid in ($CYCLE_GID,$MTH1_CYCLE_GID,$MTH2_CYCLE_GID,$MTH3_CYCLE_GID)
     and q.claim_gid = scr.claim_gid
     and scr.excpt_id is null
     and scr.batch_date between 
              (select cycle_start_date from dma_rbate2.t_rbate_cycle where rbate_cycle_gid = $CYCLE_GID) 
          and (select cycle_end_date from dma_rbate2.t_rbate_cycle where rbate_cycle_gid = $CYCLE_GID)  
    group by 
to_char(nvl(q.rbate_id,0),  '00000000'), 
rpad(nvl(q.extnl_src_code,  ' '), 5),
rpad(nvl(q.extnl_lvl_id1,   ' '), 20),
rpad(nvl(q.extnl_lvl_id2,   ' '), 20),
rpad(nvl(q.extnl_lvl_id3,   ' '), 20),
rpad(nvl(q.extnl_lvl_id4,   ' '), 20),
rpad(nvl(q.extnl_lvl_id5,   ' '), 20),
substrb(q.cycle_gid, 1, 4) || 
decode(substrb(q.cycle_gid,5,2), 
41, 'Q1', 01, 'Q1', 02, 'Q1', 03, 'Q1', 
42, 'Q2', 04, 'Q2', 05, 'Q2', 06, 'Q2', 
43, 'Q3', 07, 'Q3', 08, 'Q3', 09, 'Q3', 
44, 'Q4', 10, 'Q4', 11, 'Q4', 12, 'Q4', 
substrb(q.cycle_gid,5,2)),
rpad('1',2),
rpad(decode(nvl(q.lcm_code,'0'),'4M','3M',nvl(q.lcm_code,'0')),2),
rpad(nvl(q.mail_order_code, '0'), 1)
order by 1,2,3,4,5
;
commit;
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE

export RETCODE=$?

print ' ' >> $LOG_FILE
print "Completed SQL call for LCM Claim Counts for Cycle " $CYCLE_GID "." >> $LOG_FILE 
print `date` >> $LOG_FILE

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print "LCM Claim Counts Extract SQL Failed - error message is: " >> $LOG_FILE 
   print ' ' >> $LOG_FILE 
   tail -20 $DAT_FILE >> $LOG_FILE
   print " " >> $LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $LOG_FILE
   print "  Error Executing "$SCRIPTNAME"          " >> $LOG_FILE
   print "  Look in "$LOG_FILE       >> $LOG_FILE
   print "=================================================================" >> $LOG_FILE
   
# Send the Email notification 
   export JOBNAME=$SCHEDULE" / "$JOB
   export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
   export LOGFILE=$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $LOG_FILE
   print "JOBNAME is " $JOBNAME >> $LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME >> $LOG_FILE
   print "LOG_FILE is " $LOG_FILE >> $LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4 >> $LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5 >> $LOG_FILE
   print "****** end of email parameters ******" >> $LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $LOG_FILE $LOG_ARCH_ARCH.`date +"%Y%j%H%M"`
   exit $RETCODE
else
  print ' ' >> $LOG_FILE
  print "FTPing ASCII output to MVS " $FTP_IP >> $LOG_FILE

  # build ftp commands and ftp file here 
  print 'ascii' >> $MVS_FTP_COM_FILE

  print 'put ' $DAT_FILE " " $MVS_FTP_DAT ' (replace'  >> $MVS_FTP_COM_FILE 

  print "Trigger file for " $MVS_FTP_DAT >> $TRG_FILE 
  print 'put ' $TRG_FILE " " $MVS_FTP_TRG ' (replace' >> $MVS_FTP_COM_FILE 

  print 'quit' >> $MVS_FTP_COM_FILE 

  print " " >> $LOG_FILE
  print "Start Concatonating FTP Commands " >> $LOG_FILE
  cat $MVS_FTP_COM_FILE >> $LOG_FILE
  print "End Concatonating FTP Commands " >> $LOG_FILE
  print " " >> $LOG_FILE

  ftp -i  $FTP_IP < $MVS_FTP_COM_FILE >> $LOG_FILE

  print ' ' >> $LOG_FILE
  print "Completed FTP" >> $LOG_FILE
  print `date` >> $LOG_FILE

  print ' ' >> $LOG_FILE
  print "Completed executing LCM Claim Counts Extract " >> $LOG_FILE
  print `date` >> $LOG_FILE
fi

#Clean up files
rm -f $SQL_FILE
rm -f $SQL_PIPE_FILE
rm -f $TRG_FILE
rm -f $MVS_FTP_COM_FILE

print "....Completed executing " $SCRIPTNAME " ...."   >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_ARCH.`date +"%Y%j%H%M"`


exit $RETCODE

