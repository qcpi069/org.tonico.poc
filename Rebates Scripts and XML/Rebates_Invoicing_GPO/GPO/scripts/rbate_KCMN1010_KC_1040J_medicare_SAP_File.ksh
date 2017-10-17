#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCMN1010_KC_1040J_medicare_SAP_File.ksh   
# Title         : Medicare Rebates SAP Extract.
#
# Description   : Extract Medicare Rebates Financial records into an 
#                 SAP layout and FTP to the SAP machine.
#                 
# Maestro Job   : KCMN1010 KC_1040J
#
# Parameters    : N/A - Can be a months_back value to get different 
#                 quarters of data.
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 05-20-2004  K. Gries    Initial Creation.
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
     if [[ $QA_REGION = "true" ]]; then
        SAP_DIR="/PCSdrop/PQA"
        FTP_IP=sapqd1
     else
        SAP_DIR="/PCSdrop/PPR"
        FTP_IP=sappdb
     fi 
   else  
     SAP_DIR="/PCSdrop/PQA"
     FTP_IP=sapqd1
fi

SCHEDULE="KCMN1010"
JOB="KC_1040J"
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_medicare_SAP_File"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$FILE_BASE".log"
SQL_FILE=$FILE_BASE".sql"
SQL_PIPE_FILE=$FILE_BASE"_pipe.lst"
FTP_CMDS=$FILE_BASE"_ftpcommands.txt"

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/$FTP_CMDS

export DATE_CNTRL_FILE="rbate_KCMN1000_KC_1000J_medicare_date_control_file.dat"

export FTP_NT_IP=AZSHISP00 

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
#
# Values are set at the beginning of the Medicare Invoicing process in
# KCMN1000_KC_1000J.
#
# Read the date control values for use in the claims selection
# SQL.
#-------------------------------------------------------------------------#

export FIRST_READ=1
while read rec_BEG_DATE rec_END_DATE rec_CYCLE_GID ; do
  if [[ $FIRST_READ != 1 ]]; then
    print 'Finishing control file read' >> $OUTPUT_PATH/$LOG_FILE
  else
    export FIRST_READ=0
    print 'read record from control file' >> $OUTPUT_PATH/$LOG_FILE
    print 'rec_BEG_DATE ' $rec_BEG_DATE >> $OUTPUT_PATH/$LOG_FILE
    print 'rec_END_DATE ' $rec_END_DATE >> $OUTPUT_PATH/$LOG_FILE
    print 'rec_CYCLE_GID ' $rec_CYCLE_GID >> $OUTPUT_PATH/$LOG_FILE
    export BEGIN_DATE=$rec_BEG_DATE
    export END_DATE=$rec_END_DATE
    ##############rec_CYCLE_GID=200404
    export CYCLE_GID=$rec_CYCLE_GID
  fi
done < $INPUT_PATH/$DATE_CNTRL_FILE

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`


#-------------------------------------------------------------------------#
# Read the Sequence Number values for use in the File.
#-------------------------------------------------------------------------#

print ' '                                                        >> $OUTPUT_PATH/$LOG_FILE
print `date` 'Getting SAP records'                          >> $OUTPUT_PATH/$LOG_FILE

DAT_FILE=$FILE_BASE"_"$CYCLE_GID".dat"
rm -f $OUTPUT_PATH/$DAT_FILE

rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
mkfifo $OUTPUT_PATH/$SQL_PIPE_FILE
    
dd if=$OUTPUT_PATH/$SQL_PIPE_FILE of=$OUTPUT_PATH/$DAT_FILE bs=100k &

cat > $INPUT_PATH/$SQL_FILE << EOF
set LINESIZE 401
set TERMOUT OFF
set PAGESIZE 0
set NEWPAGE 0
set SPACE 0
set ECHO OFF
set FEEDBACK OFF
set HEADING OFF
set WRAP off
set verify off
set trimspool on
alter session enable parallel dml;
spool $OUTPUT_PATH/$SQL_PIPE_FILE;

select outter.BLDAT||
       outter.BLART||
       outter.BUKRS||
       outter.BUDAT||
       outter.XBLNR||
       outter.NEWBS||
       outter.NEWKO||
       outter.WRBTR||
       outter.ZUONR||
       outter.SGTXT||
       outter.NEWBS2||
       outter.NEWKO2||
       outter.WRBTR2||
       outter.NEWBS3||
       outter.NEWKO3||
       outter.WMWST||
       outter.FLAG
from(
select
     to_char(sysdate,'mmddyyyy') as BLDAT --date invoiced
    ,'FE' as BLART
    ,'301 ' as BUKRS
    ,to_char(sysdate,'mmddyyyy') as BUDAT --posting date
    ,substrb('$CYCLE_GID',5,2)||'M'||substrb('$CYCLE_GID',3,2)||'/Rebates   ' as XBLNR
    ,case when sum(a.admin_fee_rbate_amt) >= 0 then '01'
          else                                      '11'
      end as NEWBS
    ,rpad(rtrim(NVL(b.ar_nbr,'0000000000000000')),17,' ') as NEWKO
    ,substrb(to_char(sum(a.admin_fee_rbate_amt),'00000000000v00'),2,13) as WRBTR
    ,substrb('$CYCLE_GID',5,2)||'M'||substrb('$CYCLE_GID',3,2)||'/Rebates     ' as ZUONR
    ,rpad(' ',50,' ') as SGTXT
    ,case when sum(a.admin_fee_rbate_amt) >= 0 then '50'
          else                                      '40'
      end as NEWBS2
    ,'6231003          ' as NEWKO2
    ,substrb(to_char(sum(a.admin_fee_rbate_amt),'00000000000v00'),2,13) as WRBTR2
    ,'  ' as NEWBS3
    ,rpad(' ',17,' ') as NEWKO3
    ,rpad(' ',13,' ') as WMWST
    ,'R'  as FLAG
 from dma_rbate2.h_claim_rbate_medicare a
     ,dma_rbate2.t_rbate_mfg b
where a.pico = b.pico_no(+)
  and a.cycle_gid = $CYCLE_GID
  and a.excpt_id   IN (93,94)
group by   
     to_char(sysdate,'mmddyyyy') --date invoiced
    ,'FE'
    ,'301 '
    ,to_char(sysdate,'mmddyyyy') --posting date
    ,substrb('$CYCLE_GID',5,2)||'M'||substrb('$CYCLE_GID',3,2)||'/Rebates   '
    ,rpad(rtrim(NVL(b.ar_nbr,'0000000000000000')),17,' ')
    ,substrb('$CYCLE_GID',5,2)||'M'||substrb('$CYCLE_GID',3,2)||'/Rebates     '
    ,rpad(' ',50,' ')
    ,'6231003          '
    ,'  '
    ,rpad(' ',17,' ')
    ,rpad(' ',13,' ')
    ,'R'   
union
select 
     to_char(sysdate,'mmddyyyy')  as BLDAT --date invoiced
    ,'RB' as BLART
    ,'301 ' as BUKRS
    ,to_char(sysdate,'mmddyyyy')  as BUDAT --posting date
    ,substrb('$CYCLE_GID',5,2)||'M'||substrb('$CYCLE_GID',3,2)||'/Rebates   ' as XBLNR
    ,case when sum(a.mdcr_mfr_rspnb_amt) >= 0 then '01'
          else                                     '11'
      end as NEWBS
    ,rpad(rtrim(NVL(b.ar_nbr,'0000000000000000')),17,' ') as NEWKO
    ,substrb(to_char(sum(a.mdcr_mfr_rspnb_amt),'00000000000v00'),2,13) as WRBTR
    ,substrb('$CYCLE_GID',5,2)||'M'||substrb('$CYCLE_GID',3,2)||'/Rebates     ' as ZUONR
    ,rpad(' ',50,' ') as SGTXT
    ,case when sum(a.mdcr_mfr_rspnb_amt) >= 0 then '50'
          else                                     '40'
      end as NEWBS2
    ,'1232009          ' as NEWKO2
    ,substrb(to_char(sum(a.mdcr_mfr_rspnb_amt),'00000000000v00'),2,13) as WRBTR2
    ,'  ' as NEWBS3
    ,rpad(' ',17,' ') as NEWKO3
    ,rpad(' ',13,' ') as WMWST
    ,'R'  as FLAG 
 from dma_rbate2.h_claim_rbate_medicare a
     ,dma_rbate2.t_rbate_mfg b
where a.pico = b.pico_no(+)
  and a.cycle_gid = $CYCLE_GID
  and a.excpt_id   IN (93,94)
group by 
     to_char(sysdate,'mmddyyyy') --date invoiced
    ,'RB'
    ,'301 '
    ,to_char(sysdate,'mmddyyyy') --posting date
    ,substrb('$CYCLE_GID',5,2)||'M'||substrb('$CYCLE_GID',3,2)||'/Rebates   '
    ,rpad(rtrim(NVL(b.ar_nbr,'0000000000000000')),17,' ')
    ,substrb('$CYCLE_GID',5,2)||'M'||substrb('$CYCLE_GID',3,2)||'/Rebates     '
    ,rpad(' ',50,' ')
    ,'1232009          '
    ,'  '
    ,rpad(' ',17,' ')
    ,rpad(' ',13,' ')
    ,'R'   
union
select 
     to_char(sysdate,'mmddyyyy')  as BLDAT --date invoiced
    ,'RB' as BLART
    ,'301 ' as BUKRS
    ,to_char(sysdate,'mmddyyyy')  as BUDAT --posting date
    ,substrb('$CYCLE_GID',5,2)||'M'||substrb('$CYCLE_GID',3,2)||'/Rebates   ' as XBLNR
    ,case when sum(a.flat_fee_rbate_amt) >= 0 then '01'
          else                                     '11'
      end as NEWBS
    ,rpad(rtrim(NVL(b.ar_nbr,'0000000000000000')),17,' ') as NEWKO
    ,substrb(to_char(sum(a.flat_fee_rbate_amt),'00000000000v00'),2,13) as WRBTR
    ,substrb('$CYCLE_GID',5,2)||'M'||substrb('$CYCLE_GID',3,2)||'/Rebates     ' as ZUONR
    ,rpad(' ',50,' ') as SGTXT
    ,case when sum(a.flat_fee_rbate_amt) >= 0 then '50'
          else                                     '40'
      end as NEWBS2
    ,'1326002          ' as NEWKO2
    ,substrb(to_char(sum(a.flat_fee_rbate_amt),'00000000000v00'),2,13) as WRBTR2
    ,'  ' as NEWBS3
    ,rpad(' ',17,' ') as NEWKO3
    ,rpad(' ',13,' ') as WMWST
    ,'R'   as FLAG
 from dma_rbate2.h_claim_rbate_medicare a
     ,dma_rbate2.t_rbate_mfg b
where a.pico = b.pico_no(+)
  and a.cycle_gid = $CYCLE_GID
  and a.excpt_id   IN (93,94)
group by  
     to_char(sysdate,'mmddyyyy') --date invoiced
    ,'RB'
    ,'301 '
    ,to_char(sysdate,'mmddyyyy') --posting date
    ,substrb('$CYCLE_GID',5,2)||'M'||substrb('$CYCLE_GID',3,2)||'/Rebates   '
    ,rpad(rtrim(NVL(b.ar_nbr,'0000000000000000')),17,' ')
    ,substrb('$CYCLE_GID',5,2)||'M'||substrb('$CYCLE_GID',3,2)||'/Rebates     '
    ,rpad(' ',50,' ')
    ,'1326002          '
    ,'  '
    ,rpad(' ',17,' ')
    ,rpad(' ',13,' ')
    ,'R'       
 ) outter
 where outter.WRBTR <> '0000000000000'
;
                    
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE

ORA_RETCODE=$?
print `date` 'Completed select of SAP file for ' $CYCLE_GID >> $OUTPUT_PATH/$LOG_FILE

if [[ $ORA_RETCODE = 0 ]]; then
   print `date` 'Completed select of SAP for ' $CYCLE_GID >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   SAP_FILE="Rebates_Medicare_SAP_"$CYCLE_GID".txt"
   TRG_FILE="Rebates_Medicare_SAP_data.trg"
   print 'Trigger file for Rebates Medicare load to SAP for Cycle_Gid ' $CYCLE_GID > $OUTPUT_PATH/$TRG_FILE
   print 'FTPing ' $OUTPUT_PATH/$DAT_FILE ' to '                                 >> $OUTPUT_PATH/$LOG_FILE
   print '       ' $FTP_IP $SAP_DIR $SAP_FILE                                    >> $OUTPUT_PATH/$LOG_FILE
   print 'cd '$SAP_DIR                                                           >> $INPUT_PATH/$FTP_CMDS
   print 'put ' $OUTPUT_PATH/$DAT_FILE $SAP_FILE ' (replace'                     >> $INPUT_PATH/$FTP_CMDS
   print 'put ' $OUTPUT_PATH/$TRG_FILE $TRG_FILE ' (replace'                     >> $INPUT_PATH/$FTP_CMDS
   ftp -i  $FTP_IP < $INPUT_PATH/$FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
   FTP_RETCODE=$?
   if [[ $FTP_RETCODE = 0 ]]; then
      print ' ' >> $OUTPUT_PATH/$LOG_FILE
      print `date` 'FTP  of ' $OUTPUT_PATH/$DAT_FILE ' to ' $SAP_FILE ' complete '           >> $OUTPUT_PATH/$LOG_FILE
      RETCODE=$FTP_RETCODE
   else
      RETCODE=$FTP_RETCODE
   fi    
else
   RETCODE=$ORA_RETCODE
fi
    

if [[ $RETCODE != 0 ]]; then
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Failure in Medicare SAP file creation process '       >> $OUTPUT_PATH/$LOG_FILE
   print 'Oracle RETURN CODE is : ' $ORA_RETCODE             >> $OUTPUT_PATH/$LOG_FILE
   print 'FTP RETURN CODE is    : ' $FTP_RETCODE             >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
fi

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " " >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
   print "  Error Executing " $SCRIPTNAME                                    >> $OUTPUT_PATH/$LOG_FILE
   print "  Look in "$OUTPUT_PATH/$LOG_FILE       >> $OUTPUT_PATH/$LOG_FILE
   print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
   
# Send the Email notification 
   export JOBNAME=$SCHEDULE/$JOB
   export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
   export LOGFILE=$OUTPUT_PATH/$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/$LOG_FILE
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/$LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/$LOG_FILE
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/$LOG_FILE
   print "****** end of email parameters ******" >> $OUTPUT_PATH/$LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

rm -f $OUTPUT_PATH/$SQL_PIPE_FILE

print "....Completed executing " $SCRIPTNAME " ...."   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

