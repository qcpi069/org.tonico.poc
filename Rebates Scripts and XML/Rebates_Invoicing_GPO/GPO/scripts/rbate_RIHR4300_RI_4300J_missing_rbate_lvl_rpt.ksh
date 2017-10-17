#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_RIHR4300_RI_4300J_missing_rbate_lvl_rpt.ksh   
# Title         : Creates the 'Claims With Missing Rebate Levels' report
#
# Description   : This script creates a file for the new 
#                 'Claims With Missing Rebate Levels' report. The file is ftp'd 
#                  to the Crystal Reports Server where the report is formatted
#                  and sent to OnDemand.    
#
# Maestro Job   : RI_4300J
#
# Parameters    : N/A
#         
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#                 dat file with the records for Crystal reports.  
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 08/18/04  N. Tucker   Initial Creation.
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
      export REBATES_DIR=rebates_integration
      export REPORT_DIR=reporting_prod/rebates/data
else  
     export REBATES_DIR=rebates_integration
     export REPORT_DIR=reporting_test/rebates/data
fi

export SCHEDULE="RIHR4300"
export JOB="RI_4300J"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_missing_rbate_lvl_rpt"
export SCRIPTNAME=$FILE_BASE".ksh"
export LOG_FILE=$FILE_BASE".log"
export SQL_FILE=$FILE_BASE".sql"
export SQL_PIPE_FILE=$FILE_BASE"_pipe.lst"
export SQL_FILE_INV=$FILE_BASE"_inv.sql"
export DAT_FILE=$FILE_BASE".dat"
export FTP_CMDS=$FILE_BASE"_ftpcommands.txt"
export INV_CNTRL_FILE=$FILE_BASE"_inv_cntl.dat"
export INV_CNT_FILE=$FILE_BASE"_inv_cnt.dat"

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $OUTPUT_PATH/$DAT_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/$FTP_CMDS
rm -f $OUTPUT_PATH/$INV_CNTRL_FILE
rm -f $OUTPUT_PATH/$INV_CNT_FILE

print ' ' >> $OUTPUT_PATH/$LOG_FILE
print "executing SQL" >> $OUTPUT_PATH/$LOG_FILE
print `date` >> $OUTPUT_PATH/$LOG_FILE

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

### New Code

#-------------------------------------------------------------------------#
# Write a file out of all the inv_gids we need to process  
# 
#-------------------------------------------------------------------------#
print " " >> $OUTPUT_PATH/$LOG_FILE
print "Building PICO cntl File " >> $OUTPUT_PATH/$LOG_FILE
print " " >> $OUTPUT_PATH/$LOG_FILE

cat > $INPUT_PATH/$SQL_FILE_INV << EOF
set LINESIZE 80
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
SPOOL $OUTPUT_PATH/$INV_CNTRL_FILE
alter session enable parallel dml; 

Select distinct cycle_gid, ' ', inv_gid    
  from dma_rbate2.t_missing_rbate_lvl_rpt
  order by inv_gid; 

quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE_INV

export RETCODE=$?

print " " >> $OUTPUT_PATH/$LOG_FILE
print "Getting Line Count with wc -l command " >> $OUTPUT_PATH/$LOG_FILE
print " " >> $OUTPUT_PATH/$LOG_FILE

wc -l < $OUTPUT_PATH/$INV_CNTRL_FILE  >> $OUTPUT_PATH/$INV_CNT_FILE

print "End Line Count with wc -l command " >> $OUTPUT_PATH/$LOG_FILE
print " " >> $OUTPUT_PATH/$LOG_FILE

## Process the Records

while read CYCLE_GID INV_NB; do


#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#
rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
mkfifo $OUTPUT_PATH/$SQL_PIPE_FILE
export DAT_FILE=$FILE_BASE"_"$INV_NB".dat"
rm -f $OUTPUT_PATH/$DAT_FILE
dd if=$OUTPUT_PATH/$SQL_PIPE_FILE of=$OUTPUT_PATH/$DAT_FILE bs=100k &

cat > $INPUT_PATH/$SQL_FILE << EOF
set LINESIZE 90
set trimspool on
set TERMOUT OFF
set PAGESIZE 0
set NEWPAGE 0
set SPACE 0
set ECHO OFF
set FEEDBACK OFF
set HEADING OFF 
set WRAP off
set serveroutput off
set verify off
whenever sqlerror exit 1
set timing off;

alter session enable parallel dml;

spool $OUTPUT_PATH/$SQL_PIPE_FILE;

-- This is query for frmly_id

select /*+ ordered use_hash(bskt) use_hash(mfg) use_hash(a) full(bskt) full(mfg) full(a)  */ 
       substr(NVL(to_char(a.cycle_gid,'000000'),' 000000'),2,6)
     , substr(NVL(to_char(a.inv_gid,'000000000000'),' 000000000000'),2,12)
     , substr(NVL(to_char(mfg.pico_no,'00000'),' 00000'),2,5)
     , NVL(rpad(substrb(mfg.mfg_nam,1,25),25,' '),'                         ')
     , substr(NVL(to_char(a.bskt_gid,'00000'),' 00000'),2,5)
     , NVL(upper(rpad(substrb(bskt.bskt_nam,1,8),8,' ')),'        ')
     , rpt_id
     , NVL(rpad(substrb(a.rpt_variable,1,5),7,' '),'       ')
     , NVL(to_char(a.unit_qty,'000000000S'),'000000000+')
     , NVL(to_char(a.claim_cnt,'0000000000S'),'000000000+')
from dma_rbate2.h_rbate_mfg mfg, 
     dma_rbate2.h_bskt bskt,
     dma_rbate2.t_missing_rbate_lvl_rpt a 
where mfg.inv_gid   = $INV_NB      -- inv_gid passed in cntl file
  and mfg.cycle_gid = $CYCLE_GID  -- cycle_gid passed in cntl file
  and mfg.cycle_gid = bskt.cycle_gid 
  and mfg.inv_gid = bskt.inv_gid 
  and a.cycle_gid = mfg.cycle_gid
  and a.inv_gid = mfg.inv_gid 
  and a.bskt_gid = bskt.bskt_gid
  and a.rpt_id = '1'
group by 
       substr(NVL(to_char(a.cycle_gid,'000000'),' 000000'),2,6)
     , substr(NVL(to_char(a.inv_gid,'000000000000'),' 000000000000'),2,12)
     , substr(NVL(to_char(mfg.pico_no,'00000'),' 00000'),2,5)
     , NVL(rpad(substrb(mfg.mfg_nam,1,25),25,' '),'                         ')
     , substr(NVL(to_char(a.bskt_gid,'00000'),' 00000'),2,5)
     , NVL(upper(rpad(substrb(bskt.bskt_nam,1,8),8,' ')),'        ')
     , rpt_id
     , NVL(rpad(substrb(a.rpt_variable,1,5),7,' '),'       ')
     , NVL(to_char(a.unit_qty,'000000000S'),'000000000+')
     , NVL(to_char(a.claim_cnt,'0000000000S'),'000000000+')
order by 
       substr(NVL(to_char(a.cycle_gid,'000000'),' 000000'),2,6)
     , substr(NVL(to_char(a.inv_gid,'000000000000'),' 000000000000'),2,12)
     , substr(NVL(to_char(mfg.pico_no,'00000'),' 00000'),2,5)
     , NVL(rpad(substrb(mfg.mfg_nam,1,25),25,' '),'                         ')
     , substr(NVL(to_char(a.bskt_gid,'00000'),' 00000'),2,5)
     , NVL(upper(rpad(substrb(bskt.bskt_nam,1,8),8,' ')),'        ')
     , rpt_id
     , NVL(rpad(substrb(a.rpt_variable,1,5),7,' '),'       '); 

-- This is the query for lcm 
  
select /*+ ordered  use_hash(bskt) use_hash(mfg) use_hash(a) full(bskt) full(mfg) full(a)  */ 
       substr(NVL(to_char(a.cycle_gid,'000000'),' 000000'),2,6)
     , substr(NVL(to_char(a.inv_gid,'000000000000'),' 000000000000'),2,12)
     , substr(NVL(to_char(mfg.pico_no,'00000'),' 00000'),2,5)
     , NVL(rpad(substrb(mfg.mfg_nam,1,25),25,' '),'                         ')
     , substr(NVL(to_char(a.bskt_gid,'00000'),' 00000'),2,5)
     , NVL(upper(rpad(substrb(bskt.bskt_nam,1,8),8,' ')),'        ')
     , rpt_id
     , NVL(rpad(substrb(a.rpt_variable,1,2),7,' '),'       ')
     , NVL(to_char(a.unit_qty,'000000000S'),'000000000+')
     , NVL(to_char(a.claim_cnt,'0000000000S'),'000000000+')
from dma_rbate2.h_rbate_mfg mfg, 
     dma_rbate2.h_bskt bskt,
     dma_rbate2.t_missing_rbate_lvl_rpt a 
where mfg.inv_gid   = $INV_NB      -- inv_gid passed in cntl file
  and mfg.cycle_gid = $CYCLE_GID  -- cycle_gid passed in cntl file
  and mfg.cycle_gid = bskt.cycle_gid 
  and mfg.inv_gid = bskt.inv_gid 
  and a.cycle_gid = mfg.cycle_gid
  and a.inv_gid = mfg.inv_gid 
  and a.bskt_gid = bskt.bskt_gid
  and a.rpt_id = '2'
group by 
       substr(NVL(to_char(a.cycle_gid,'000000'),' 000000'),2,6)
     , substr(NVL(to_char(a.inv_gid,'000000000000'),' 000000000000'),2,12)
     , substr(NVL(to_char(mfg.pico_no,'00000'),' 00000'),2,5)
     , NVL(rpad(substrb(mfg.mfg_nam,1,25),25,' '),'                         ')
     , substr(NVL(to_char(a.bskt_gid,'00000'),' 00000'),2,5)
     , NVL(upper(rpad(substrb(bskt.bskt_nam,1,8),8,' ')),'        ')
     , rpt_id
     , NVL(rpad(substrb(a.rpt_variable,1,2),7,' '),'       ')
     , NVL(to_char(a.unit_qty,'000000000S'),'000000000+')
     , NVL(to_char(a.claim_cnt,'0000000000S'),'000000000+')
order by 
       substr(NVL(to_char(a.cycle_gid,'000000'),' 000000'),2,6)
     , substr(NVL(to_char(a.inv_gid,'000000000000'),' 000000000000'),2,12)
     , substr(NVL(to_char(mfg.pico_no,'00000'),' 00000'),2,5)
     , NVL(rpad(substrb(mfg.mfg_nam,1,25),25,' '),'                         ')
     , substr(NVL(to_char(a.bskt_gid,'00000'),' 00000'),2,5)
     , NVL(upper(rpad(substrb(bskt.bskt_nam,1,8),8,' ')),'        ')
     , rpt_id
     , NVL(rpad(substrb(a.rpt_variable,1,2),7,' '),'       '); 

-- This is query for rebate_id 

select /*+ ordered use_hash(bskt) use_hash(mfg) use_hash(a) full(bskt) full(mfg) full(a)  */ 
       substr(NVL(to_char(a.cycle_gid,'000000'),' 000000'),2,6)
     , substr(NVL(to_char(a.inv_gid,'000000000000'),' 000000000000'),2,12)
     , substr(NVL(to_char(mfg.pico_no,'00000'),' 00000'),2,5)
     , NVL(rpad(substrb(mfg.mfg_nam,1,25),25,' '),'                         ')
     , substr(NVL(to_char(a.bskt_gid,'00000'),' 00000'),2,5)
     , NVL(upper(rpad(substrb(bskt.bskt_nam,1,8),8,' ')),'        ')
     , rpt_id
     , NVL(rpad(substrb(a.rpt_variable,1,7),7,' '),'       ')
     , NVL(to_char(a.unit_qty,'000000000S'),'000000000+')
     , NVL(to_char(a.claim_cnt,'0000000000S'),'000000000+')
from dma_rbate2.h_rbate_mfg mfg, 
     dma_rbate2.h_bskt bskt,
     dma_rbate2.t_missing_rbate_lvl_rpt a 
where mfg.inv_gid   = $INV_NB      -- inv_gid passed in cntl file
  and mfg.cycle_gid = $CYCLE_GID  -- cycle_gid passed in cntl file
  and mfg.cycle_gid = bskt.cycle_gid 
  and mfg.inv_gid = bskt.inv_gid 
  and a.cycle_gid = mfg.cycle_gid
  and a.inv_gid = mfg.inv_gid 
  and a.bskt_gid = bskt.bskt_gid
  and a.rpt_id = '3'
group by 
       substr(NVL(to_char(a.cycle_gid,'000000'),' 000000'),2,6)
     , substr(NVL(to_char(a.inv_gid,'000000000000'),' 000000000000'),2,12)
     , substr(NVL(to_char(mfg.pico_no,'00000'),' 00000'),2,5)
     , NVL(rpad(substrb(mfg.mfg_nam,1,25),25,' '),'                         ')
     , substr(NVL(to_char(a.bskt_gid,'00000'),' 00000'),2,5)
     , NVL(upper(rpad(substrb(bskt.bskt_nam,1,8),8,' ')),'        ')
     , rpt_id
     , NVL(rpad(substrb(a.rpt_variable,1,7),7,' '),'       ')
     , NVL(to_char(a.unit_qty,'000000000S'),'000000000+')
     , NVL(to_char(a.claim_cnt,'0000000000S'),'000000000+')
order by 
       substr(NVL(to_char(a.cycle_gid,'000000'),' 000000'),2,6)
     , substr(NVL(to_char(a.inv_gid,'000000000000'),' 000000000000'),2,12)
     , substr(NVL(to_char(mfg.pico_no,'00000'),' 00000'),2,5)
     , NVL(rpad(substrb(mfg.mfg_nam,1,25),25,' '),'                         ')
     , substr(NVL(to_char(a.bskt_gid,'00000'),' 00000'),2,5)
     , NVL(upper(rpad(substrb(bskt.bskt_nam,1,8),8,' ')),'        ')
     , rpt_id
     , NVL(rpad(substrb(a.rpt_variable,1,7),7,' '),'       '); 

SPOOL OFF;

DELETE 
  FROM dma_rbate2.t_missing_rbate_lvl_rpt
 WHERE inv_gid   = $INV_NB      
   AND cycle_gid = $CYCLE_GID;

COMMIT;


quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE

ORA_RETCODE=$?
print `date` 'Completed select of missing rebate level rpt for ' $CYCLE_GID ' '$INV_NB >> $OUTPUT_PATH/$LOG_FILE
#-------------------------------------------------------------------------#
# If everything is fine FTP the file to the DATA directory on Crystal Server.                  
#-------------------------------------------------------------------------#

if [[ $ORA_RETCODE = 0 ]]; then
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'FTPing files for Invoice '$INV_NB >> $OUTPUT_PATH/$LOG_FILE
   export FTP_NT_IP=AZSHISP00
   export FTP_FILE=$FILE_BASE"_"$INV_NB"_"$CYCLE_GID".txt"
   rm -f $INPUT_PATH/$FTP_CMDS
   print 'cd /'$REBATES_DIR                                          >> $INPUT_PATH/$FTP_CMDS
   print 'cd '$REPORT_DIR                                            >> $INPUT_PATH/$FTP_CMDS
   print 'put ' $OUTPUT_PATH/$DAT_FILE $FTP_FILE ' (replace' >> $INPUT_PATH/$FTP_CMDS
   print 'quit'                                                      >> $INPUT_PATH/$FTP_CMDS
   ftp -i  $FTP_NT_IP < $INPUT_PATH/$FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'FTP complete ' >> $OUTPUT_PATH/$LOG_FILE
   FTP_RETCODE=$?
   if [[ $FTP_RETCODE = 0 ]]; then
      print ' ' >> $OUTPUT_PATH/$LOG_FILE
      print `date` 'FTP  of ' $OUTPUT_PATH/$DAT_FILE ' to ' $FTP_FILE ' complete '           >> $OUTPUT_PATH/$LOG_FILE
      RETCODE=$FTP_RETCODE
   else
      RETCODE=$FTP_RETCODE
   fi    
else
   RETCODE=$ORA_RETCODE
fi   

if [[ $RETCODE != 0 ]]; then
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Failure in Missing Rebate Lvl Rpt file creation process '       >> $OUTPUT_PATH/$LOG_FILE
   print 'Oracle RETURN CODE is : ' $ORA_RETCODE             >> $OUTPUT_PATH/$LOG_FILE
   print 'FTP RETURN CODE is    : ' $FTP_RETCODE             >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   return
fi

done < $OUTPUT_PATH/$INV_CNTRL_FILE

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " " >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
   print "  Error Executing " $SCRIPTNAME                                    >> $OUTPUT_PATH/$LOG_FILE
   print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  >> $OUTPUT_PATH/$LOG_FILE
   print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
   
# Send the Email notification 
   export JOBNAME=$SCHEDULE/$JOB
   export LOGFILE=$OUTPUT_PATH/$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/$LOG_FILE
   print "JOBNAME is " $JOB >> $OUTPUT_PATH/$LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/$LOG_FILE
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/$LOG_FILE
   print "****** end of email parameters ******" >> $OUTPUT_PATH/$LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

print ' ' >> $OUTPUT_PATH/$LOG_FILE
print "Successfully completed job " $JOB >> $OUTPUT_PATH/$LOG_FILE 
print "Script " $SCRIPTNAME >> $OUTPUT_PATH/$LOG_FILE
print `date`  >> $OUTPUT_PATH/$LOG_FILE
mv -f  $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`

exit $RETCODE

