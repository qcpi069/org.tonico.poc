#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCMN1010_KC_1020J_Medicare_NCPDP_Creation_asynchronus_module.ksh   
# Title         : Medicare NCPDP extract.
#
# Description   : Extract NCPDP files for Medicare Rebates by calling an
#                 an ASYNCHRONOUS module for each Pico involved in the 
#                 cycle period. The currect ASYNCHRONOUS module can be
#                 run in a prallel of 4 processes.
#
#                 
#                 
# Maestro Job   : KCMN1010 KC_1020J
#
# Parameters    : Values are passed via asynch call from main script.
#                 LOOPCTR=$1
#                 PICO_NO=$2
#                 CYCLE_GID=$3
#                 BEGIN_DATE=$4
#                 END_DATE=$5
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
# 04-19-2005  N. Tucker   Changed NCPDP Heading for Flat Fee to Manufacturer
#                            Rebate Amount
# 05-09-2003  K. Gries    Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
     REBATES_DIR=rebates_integration
     DATA_DIR=rbate2
     NCPDP_DIR=Medicare_NCPDP
   else  
     REBATES_DIR=rebates_integration
     DATA_DIR=rbate2
     NCPDP_DIR=Medicare_NCPDP
fi

LOOPCTR=$1
PICO_NO=$2
CYCLE_GID=$3
BEGIN_DATE=$4
END_DATE=$5

SCHEDULE="KCMN1010"
JOB="KC_1020J"
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_Medicare_NCPDP_Creation_"$CYCLE_GID"_"$PICO_NO"_job"$LOOPCTR
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$FILE_BASE".log"
SQL_FILE=$FILE_BASE".sql"
SQL_PIPE_FILE=$FILE_BASE"_pipe.lst"
FTP_CMDS=$FILE_BASE"_ftpcommands.txt"
MDCR_SEQ_NBR=$FILE_BASE"_sequence_nbr.txt"

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $INPUT_PATH/$FTP_CMDS
rm -f $INPUT_PATH/$SQL_MDCR_SPNSR_CNTRL
rm -f $INPUT_PATH/$MDCR_SEQ_NBR

FTP_NT_IP=AZSHISP00 

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
#
# Values are set at the beginning of the Medicare Invoicing process in
# KCMN1000_KC_1000J.
#
# Read the date control values for use in the claims selection
# SQL.
#-------------------------------------------------------------------------#

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
#
# Values are set at the beginning of the Medicare Invoicing process in
# KCMN1000_KC_1000J.
#
# Read the date control values for use in the claims selection
# SQL.
#-------------------------------------------------------------------------#

print " " >> $OUTPUT_PATH/$LOG_FILE
print "CYCLE_GID parameter being used is: " $CYCLE_GID >> $OUTPUT_PATH/$LOG_FILE
print " " >> $OUTPUT_PATH/$LOG_FILE

cat > $INPUT_PATH/$SQL_FILE << EOF
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
SPOOL $OUTPUT_PATH/$MDCR_SEQ_NBR
alter session enable parallel dml; 

select dma_rbate2.seq_medicare_ncpdp_gid.NEXTVAL
      ,' '
      ,rpad(to_char(sysdate,'YYYYMMDD'),8,' ')
from dual;

quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE
RETCODE=$?

#-------------------------------------------------------------------------#
# Read the Sequence Number values for use in the File.
#-------------------------------------------------------------------------#

print ' '                                                        >> $OUTPUT_PATH/$LOG_FILE
print `date` 'Gertting Sequence number'                          >> $OUTPUT_PATH/$LOG_FILE


while read rec_SEQ_NBR rec_SYS_DATE; do
    SEQ_NBR=$rec_SEQ_NBR
    SYS_DATE=$rec_SYS_DATE
done < $OUTPUT_PATH/$MDCR_SEQ_NBR    

print ' '                                                       >> $OUTPUT_PATH/$LOG_FILE
print `date` 'Beginning select of NCPDP for ' $PICO_NO >> $OUTPUT_PATH/$LOG_FILE

rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
mkfifo $OUTPUT_PATH/$SQL_PIPE_FILE
    
DAT_FILE=$FILE_BASE".dat" 

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
set trimspool off
alter session enable parallel dml;
spool $OUTPUT_PATH/$SQL_PIPE_FILE;

select /*+ full(a) parallel(a,4) full(m) parallel(m,4) */
       rpad('HD',2,' ')
      ,rpad(rtrim('0002.01'),7,' ')
      ,rpad('$SYS_DATE',8,' ')
      ,lpad(rtrim('$SEQ_NBR'),9,'0')
      ,rpad(a.pico_no,15,' ')
      ,lpad(rtrim('$SEQ_NBR'),15,'0')
      ,rpad(a.pico_no,15,' ') --contract number
      ,rpad(to_char(to_date('$BEGIN_DATE','ddmmyyyy'),'yyyymmdd'),8,' ')
      ,rpad(to_char(to_date('$END_DATE','ddmmyyyy'),'yyyymmdd'),8,' ')
      ,rpad('C',1,' ')
      ,rpad(' ',17,' ')
      ,rpad('Caremark',30,' ')
      ,rpad(' ',1,' ')
      ,rpad(' ',17,' ')
      ,rpad(' ',30,' ')
      ,rpad('L',1,' ')
      ,rpad(a.pico_no,17,' ')
      ,rtrim(rpad(NVL(m.mfg_nam,'Unknown'),30,' '),30)
      ,rpad(' ',169,' ')
  from dma_rbate2.v_ncpdp_medicare_detail a
      ,dma_rbate2.t_rbate_mfg m 
 where a.pico_no = m.pico_no(+)
   and a.pico_no = $PICO_NO
   and a.cycle_gid = $CYCLE_GID
   and rownum = 1;

SELECT /*+ full(a) parallel(a,4) */
       record_type||
       substrb(rpad(to_char(rownum),11,' '),1,11)||
          data_level||
          plan_id_qualifier||
          plan_id_code||
          plan_name||
          pharm_id_qualifier||
          pharm_id_code||
          pharm_zip_code||
          product_code_qualifier||
          product_code||
          product_desc||
          daw_selection_code||
          unit_quantity||
          unit_of_measure||
          dsg_form_id_code||
          diagnosis_code||
          rebate_days_supply||
          prescription_type||
          total_num_of_prescriptions||
          prescr_reference_num||
          date_filled||
          reimbursement_date||
          therapeutic_class||
          therapeutic_class_code||
          therapeutic_class_desc||
          plan_reimbursement_qual||
          plan_reimbursement_amt||
          patient_liability_amount||
          refill_code||
          record_purpose_ind||
          rebate_per_unit_amount||
          requested_amount||
          formulary_code||
          prescriber_id_code||
          prescriber_id||
          encrypted_patient_id_code||
          claim_number||
          member_suffix||
          mail_order_code||
          rebate_status_code||
          lcm_or_transitional_assistance||
          basket_name||
          basket_id||
          rebate_level||
          rollup_name||
          admin_fee_amount||
          filler_1||
          market_rebate_code||
   market_code
  from dma_rbate2.v_ncpdp_medicare_detail a
 where pico_no = $PICO_NO
   and cycle_gid = $CYCLE_GID
 order by rownum
;
select /*+ full(a) parallel(a,4) full(m) parallel(m,4) */
       rpad('TR',2,' ')
      ,rpad(rtrim('0002.01'),7,' ')
      ,rpad('$SYS_DATE',8,' ')
      ,lpad(rtrim('$SEQ_NBR'),9,'0')
      ,rpad(a.pico_no,15,' ')
      ,lpad(rtrim('$SEQ_NBR'),15,'0')
      ,rpad(a.pico_no,15,' ') --contract number
      ,rpad(to_char(to_date('$BEGIN_DATE','ddmmyyyy'),'yyyymmdd'),8,' ')
      ,rpad(to_char(to_date('$END_DATE','ddmmyyyy'),'yyyymmdd'),8,' ')
      ,rpad('C',1,' ')
      ,rpad(' ',17,' ')
      ,rpad('Caremark',30,' ')
      ,rpad(' ',1,' ')
      ,rpad(' ',17,' ')
      ,rpad(' ',30,' ')
      ,rpad('L',1,' ')
      ,rpad(a.pico_no,17,' ')
      ,rtrim(rpad(NVL(m.mfg_nam,'Unknown'),30,' '),30)
      ,substrb(NVL(to_char((sum(a.unit_qty_nbr)),'00000000000v000'),' 00000000000v000'),2,14)
      ,(case when sum(a.unit_qty_nbr) >= 0 then substrb(rpad(' ',1,' '),1,1)
                                           else substrb(rpad('-',1,' '),1,1) 
         end)
      ,substrb(NVL(to_char((sum(a.requested_amt_nbr)),'000000000v00'),' 000000000v00'),2,11)
      ,(case when sum(a.requested_amt_nbr) >= 0 then substrb(rpad(' ',1,' '),1,1)
                                                else substrb(rpad('-',1,' '),1,1) 
         end)
      ,substrb(NVL(to_char((count(*)+2),'0000000000'),' 0000000000'),2,10)
      ,' '
      ,substrb(NVL(to_char((sum(a.admin_fee_rbate_amt_nbr)),'000000000v00'),' 000000000v00'),2,11)
      ,(case when sum(a.admin_fee_rbate_amt_nbr) >= 0 then substrb(rpad(' ',1,' '),1,1)
                                                      else substrb(rpad('-',1,' '),1,1) 
         end) 
      ,rpad(rtrim(' '),119,' ')
  from dma_rbate2.v_ncpdp_medicare_detail a  
      ,dma_rbate2.t_rbate_mfg m 
 where a.pico_no = m.pico_no(+)
   and a.pico_no = $PICO_NO
   and a.cycle_gid = $CYCLE_GID
--   and rownum = 1
 group by 
       rpad('TR',2,' ')
      ,rpad(rtrim('0002.01'),7,' ')
      ,rpad('$SYS_DATE',8,' ')
      ,lpad(rtrim('$SEQ_NBR'),9,'0')
      ,rpad(a.pico_no,15,' ')
      ,rpad(' ',15,' ')
      ,rpad(' ',15,' ') --contract number
      ,rpad(to_char(to_date('$BEGIN_DATE','ddmmyyyy'),'yyyymmdd'),8,' ')
      ,rpad(to_char(to_date('$END_DATE','ddmmyyyy'),'yyyymmdd'),8,' ')
      ,rpad('C',1,' ')
      ,rpad(' ',17,' ')
      ,rpad('Caremark',30,' ')
      ,rpad(' ',1,' ')
      ,rpad(' ',17,' ')
      ,rpad(' ',30,' ')
      ,rpad('L',1,' ')
      ,rpad(a.pico_no,17,' ')
      ,rtrim(rpad(NVL(m.mfg_nam,'Unknown'),30,' '),30)
      ,rpad(rtrim(' '),119,' ')  ;
                    
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE

ORA_RETCODE=$?
print `date` 'Completed select of NCPDP for ' $PICO_NO >> $OUTPUT_PATH/$LOG_FILE

if [[ $ORA_RETCODE = 0 && $RETCODE = 0 ]]; then
   print `date` 'Completed select of NCPDP for ' $PICO_NO >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'Zipping file ' $OUTPUT_PATH/$DAT_FILE >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   DAT_FILE_ZIP="MEDICARE_NCPDP_"$CYCLE_GID"_"$PICO_NO".dat"
   ZIP_FILE="MEDICARE_NCPDP_"$CYCLE_GID"_"$PICO_NO".zip" 
   cp $OUTPUT_PATH/$DAT_FILE $OUTPUT_PATH/$DAT_FILE_ZIP
  
   cd $OUTPUT_PATH
   /usr/bin/zip -u $ZIP_FILE $DAT_FILE_ZIP >> $OUTPUT_PATH/$LOG_FILE
   cd $SCRIPT_PATH 
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   
   ZIP_RETCODE=$?
       
   if [[ $ZIP_RETCODE = 0 ]]; then
          
      print `date` 'Completed Zipping of NCPDP for ' $PICO_NO >> $OUTPUT_PATH/$LOG_FILE
      print ' ' >> $OUTPUT_PATH/$LOG_FILE
          
      print 'FTPing ' $OUTPUT_PATH/$ZIP_FILE ' to ' $FTP_NT_IP'/'$REBATES_DIR'/'$DATA_DIR'/'$NCPDP_DIR  >> $OUTPUT_PATH/$LOG_FILE
      print 'cd /'$REBATES_DIR                                                   >> $INPUT_PATH/$FTP_CMDS
      print 'cd '$DATA_DIR                                                       >> $INPUT_PATH/$FTP_CMDS
      print 'cd '$NCPDP_DIR                                                      >> $INPUT_PATH/$FTP_CMDS
      print 'binary'                                                             >> $INPUT_PATH/$FTP_CMDS
      print 'put ' $OUTPUT_PATH/$ZIP_FILE $ZIP_FILE ' (replace'                  >> $INPUT_PATH/$FTP_CMDS
                
      ftp -i  $FTP_NT_IP < $INPUT_PATH/$FTP_CMDS >> $OUTPUT_PATH/$LOG_FILE
      FTP_RETCODE=$?
      if [[ $FTP_RETCODE = 0 ]]; then
          print `date` 'FTP  of ' $OUTPUT_PATH/$ZIP_FILE  ' complete '           >> $OUTPUT_PATH/$LOG_FILE
      fi    
   fi 
fi
if [[ $ORA_RETCODE = 0 && $ZIP_RETCODE = 0 && $FTP_RETCODE = 0 && $RETCODE = 0 ]]; then
   
 print ' '                                                       >> $OUTPUT_PATH/$LOG_FILE
 print `date` 'Beginning select of NCPDP Email Info for ' $PICO_NO >> $OUTPUT_PATH/$LOG_FILE
 
 rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
 mkfifo $OUTPUT_PATH/$SQL_PIPE_FILE
     
 EMAIL_FILE=$FILE_BASE"_EMAIL_DATA.dat" 
 
 dd if=$OUTPUT_PATH/$SQL_PIPE_FILE of=$OUTPUT_PATH/$EMAIL_FILE bs=100k &
 
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
set trimspool off
alter session enable parallel dml;
spool $OUTPUT_PATH/$SQL_PIPE_FILE;

select /*+ full(a) parallel(a,4) full(m) parallel(m,4) */
       rpad('$SYS_DATE',8,' ')
      ,' '
      ,lpad(rtrim('$SEQ_NBR'),9,'0')
      ,' '
      ,rpad(a.pico_no,15,' ')
      ,' '
      ,rpad(to_char(to_date('$BEGIN_DATE','ddmmyyyy'),'mm/dd/yyyy'),10,' ')
      ,' '
      ,rpad(to_char(to_date('$END_DATE','ddmmyyyy'),'mm/dd/yyyy'),10,' ')
      ,' '
      ,rtrim(rpad(NVL(m.mfg_nam,'Unknown'),30,' '),30)
      ,' '
      ,to_char(sum(a.unit_qty_nbr),'999,999,999,999.999')
      ,' '
      ,to_char(sum(a.requested_amt_nbr),'$999,999,999.99')
      ,' '
      ,to_char(sum(a.mdcr_mfr_rspnb_amt),'$999,999,999.99')
      ,' '
      ,to_char(sum(a.flat_fee_rbate_amt),'$999,999,999.99')
      ,' '
      ,to_char(sum(a.mdcr_rbate_shr_amt),'$999,999,999.99')
      ,' '
      ,to_char((count(*)+2),'999,999,999')
      ,' '
      ,to_char(sum(a.admin_fee_rbate_amt_nbr),'$999,999,999.99')
  from dma_rbate2.v_ncpdp_medicare_detail a  
      ,dma_rbate2.t_rbate_mfg m 
 where a.pico_no = m.pico_no(+)
   and a.pico_no = $PICO_NO
   and a.cycle_gid = $CYCLE_GID
 group by 
             rpad('$SYS_DATE',8,' ')
      ,' '
      ,lpad(rtrim('$SEQ_NBR'),9,'0')
      ,' '
      ,rpad(a.pico_no,15,' ')
      ,' '
      ,rpad(to_char(to_date('$BEGIN_DATE','ddmmyyyy'),'mm/dd/yyyy'),10,' ')
      ,' '
      ,rpad(to_char(to_date('$END_DATE','ddmmyyyy'),'mm/dd/yyyy'),10,' ')
      ,' '
      ,rtrim(rpad(NVL(m.mfg_nam,'Unknown'),30,' '),30)
      ,' ';
                 
quit;

EOF
 
  $ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE
 
  ORA_EMAIL_RETCODE=$?

  if [[ $ORA_EMAIL_RETCODE != 0 ]]; then
      print ' ' >> $OUTPUT_PATH/$LOG_FILE
      print 'Failure in Medicare NCPDP Email creation process ' >> $OUTPUT_PATH/$LOG_FILE
      print 'Oracle RETURN CODE is : ' $ORA_EMAIL_RETCODE       >> $OUTPUT_PATH/$LOG_FILE  
      print ' ' >> $OUTPUT_PATH/$LOG_FILE
      RETCODE=98
  else

      EMAIL_NCPDP_INFO=$FILE_BASE"_EMAIL_TEXT.txt"
      cut -c1,2,3,4,5,6,7,8 $OUTPUT_PATH/$EMAIL_FILE > $OUTPUT_PATH/$FILE_BASE'_TRLR_split01.dat'
      cut -c10,11,12,13,14,15,16,17,18 $OUTPUT_PATH/$EMAIL_FILE > $OUTPUT_PATH/$FILE_BASE'_TRLR_split02.dat'
      cut -c20,21,22,23,24,25,26,27,28,29,30,31,32,33,34 $OUTPUT_PATH/$EMAIL_FILE > $OUTPUT_PATH/$FILE_BASE'_TRLR_split03.dat' 
      cut -c36,37,38,39,40,41,42,43,44,45 $OUTPUT_PATH/$EMAIL_FILE > $OUTPUT_PATH/$FILE_BASE'_TRLR_split04.dat' 
      cut -c47,48,49,50,51,52,53,54,55,56 $OUTPUT_PATH/$EMAIL_FILE > $OUTPUT_PATH/$FILE_BASE'_TRLR_split05.dat' 
      cut -c58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87 $OUTPUT_PATH/$EMAIL_FILE > $OUTPUT_PATH/$FILE_BASE'_TRLR_split06.dat' 
      cut -c89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108 $OUTPUT_PATH/$EMAIL_FILE > $OUTPUT_PATH/$FILE_BASE'_TRLR_split07.dat' 
      cut -c110,111,112,113,114,115,116,117,118,119,120,121,122,123 $OUTPUT_PATH/$EMAIL_FILE > $OUTPUT_PATH/$FILE_BASE'_TRLR_split08.dat'
      cut -c125,126,127,128,129,130,131,132,133,134,135,136,137,138 $OUTPUT_PATH/$EMAIL_FILE > $OUTPUT_PATH/$FILE_BASE'_TRLR_split09.dat'
      cut -c140,141,142,143,144,145,146,147,148,149,150,151,152,153 $OUTPUT_PATH/$EMAIL_FILE > $OUTPUT_PATH/$FILE_BASE'_TRLR_split10.dat'
      cut -c155,156,157,158,159,160,161,162,163,164,165,166,167,168 $OUTPUT_PATH/$EMAIL_FILE > $OUTPUT_PATH/$FILE_BASE'_TRLR_split11.dat'
      cut -c170,171,172,173,174,175,176,177,178,179,180,181 $OUTPUT_PATH/$EMAIL_FILE > $OUTPUT_PATH/$FILE_BASE'_TRLR_split12.dat'
      cut -c183,184,185,186,187,188,189,190,191,192,193,194,195,196 $OUTPUT_PATH/$EMAIL_FILE > $OUTPUT_PATH/$FILE_BASE'_TRLR_split13.dat'
      
      FILE1=$OUTPUT_PATH/$FILE_BASE'_TRLR_split01.dat'
      FILE2=$OUTPUT_PATH/$FILE_BASE'_TRLR_split02.dat'
      FILE3=$OUTPUT_PATH/$FILE_BASE'_TRLR_split03.dat'
      FILE4=$OUTPUT_PATH/$FILE_BASE'_TRLR_split04.dat'
      FILE5=$OUTPUT_PATH/$FILE_BASE'_TRLR_split05.dat'
      FILE6=$OUTPUT_PATH/$FILE_BASE'_TRLR_split06.dat'
      FILE7=$OUTPUT_PATH/$FILE_BASE'_TRLR_split07.dat'
      FILE8=$OUTPUT_PATH/$FILE_BASE'_TRLR_split08.dat'
      FILE9=$OUTPUT_PATH/$FILE_BASE'_TRLR_split09.dat'
      FILE10=$OUTPUT_PATH/$FILE_BASE'_TRLR_split10.dat'
      FILE11=$OUTPUT_PATH/$FILE_BASE'_TRLR_split11.dat'
      FILE12=$OUTPUT_PATH/$FILE_BASE'_TRLR_split12.dat'
      FILE13=$OUTPUT_PATH/$FILE_BASE'_TRLR_split13.dat'
      
      while read -u3 F1 && read -u4 F2 && read -u5 F3 && read -u6 F4 && read -u7 F5 && read -u8 F6 && read -u9 F7 ; do
          SYS_DATE=$F1 
          SEQ_NBR=$F2
          PICO_NO=$F3
          BEGIN_DATE_INFO=$F4
          END_DATE_INFO=$F5 
          MFG_NAM=$F6
          UNIT_QTY=$F7 
          RQSTD_RBATE_AMT=$rec_RQSTD_AMT 
          MFG_RESPBLTY=$rec_MFG_RESPBLTY 
          FLAT_FEE_RBATE=$rec_FLAT_FEE_RBATE 
          RBATE_SHR_AMT=$rec_RBATE_SHR_AMT
          TOT_REC_CNT=$rec_REC_CNT 
          ADMIN_FEE_AMT=$rec_ADMIN_FEE
      done 3<$FILE1 4<$FILE2 5<$FILE3 6<$FILE4 7<$FILE5 8<$FILE6 9<$FILE7  
  
      while read -u3 F8 && read -u4 F9 && read -u5 F10 && read -u6 F11 && read -u7 F12 && read -u8 F13 ; do
  	  RQSTD_RBATE_AMT=$F8
	  MFG_RESPBLTY=$F9
	  FLAT_FEE_RBATE=$F10 
	  RBATE_SHR_AMT=$F11
	  TOT_REC_CNT=$F12
	  ADMIN_FEE_AMT=$F13
      done 3<$FILE8 4<$FILE9 5<$FILE10 6<$FILE11 7<$FILE12 8<$FILE13 
      
    cut -c1,2, $OUTPUT_PATH/$DAT_FILE > $OUTPUT_PATH/$FILE_BASE'_TEMP_split01.dat'
    cut -c140,141,142,143,144,145,146,147,148,149,150,151,152,153 $OUTPUT_PATH/$DAT_FILE > $OUTPUT_PATH/$FILE_BASE'_TEMP_split02.dat'
    cut -c154 $OUTPUT_PATH/$DAT_FILE > $OUTPUT_PATH/$FILE_BASE'_TEMP_split03.dat' 
    cut -c290,291,292,293,294,295,296,297,298,299,300 $OUTPUT_PATH/$DAT_FILE > $OUTPUT_PATH/$FILE_BASE'_TEMP_split04.dat' 
    cut -c301 $OUTPUT_PATH/$DAT_FILE > $OUTPUT_PATH/$FILE_BASE'_TEMP_split05.dat' 
    cut -c392,393,394,395,396 $OUTPUT_PATH/$DAT_FILE > $OUTPUT_PATH/$FILE_BASE'_TEMP_split06.dat' 
    cut -c397 $OUTPUT_PATH/$DAT_FILE > $OUTPUT_PATH/$FILE_BASE'_TEMP_split07.dat' 
    cut -c232,233,234,235,236,237,238,239,240,241,242,243,244,245 $OUTPUT_PATH/$DAT_FILE > $OUTPUT_PATH/$FILE_BASE'_TEMP_split08.dat'
    cut -c246 $OUTPUT_PATH/$DAT_FILE > $OUTPUT_PATH/$FILE_BASE'_TEMP_split09.dat'
    cut -c247,248,249,250,251,252,253,254,255,256,257 $OUTPUT_PATH/$DAT_FILE > $OUTPUT_PATH/$FILE_BASE'_TEMP_split10.dat'
    cut -c258 $OUTPUT_PATH/$DAT_FILE > $OUTPUT_PATH/$FILE_BASE'_TEMP_split11.dat'
    cut -c259,260,261,262,263,264,265,266,267,268 $OUTPUT_PATH/$DAT_FILE > $OUTPUT_PATH/$FILE_BASE'_TEMP_split12.dat'
    cut -c270,271,272,273,274,275,276,277,278,279,280 $OUTPUT_PATH/$DAT_FILE > $OUTPUT_PATH/$FILE_BASE'_TEMP_split13.dat'
    cut -c281 $OUTPUT_PATH/$DAT_FILE > $OUTPUT_PATH/$FILE_BASE'_TEMP_split14.dat'
    
    FILE1=$OUTPUT_PATH/$FILE_BASE'_TEMP_split01.dat'
    FILE2=$OUTPUT_PATH/$FILE_BASE'_TEMP_split02.dat'
    FILE3=$OUTPUT_PATH/$FILE_BASE'_TEMP_split03.dat'
    FILE4=$OUTPUT_PATH/$FILE_BASE'_TEMP_split04.dat'
    FILE5=$OUTPUT_PATH/$FILE_BASE'_TEMP_split05.dat'
    FILE6=$OUTPUT_PATH/$FILE_BASE'_TEMP_split06.dat'
    FILE7=$OUTPUT_PATH/$FILE_BASE'_TEMP_split07.dat'
    FILE8=$OUTPUT_PATH/$FILE_BASE'_TEMP_split08.dat'
    FILE9=$OUTPUT_PATH/$FILE_BASE'_TEMP_split09.dat'
    FILE10=$OUTPUT_PATH/$FILE_BASE'_TEMP_split10.dat'
    FILE11=$OUTPUT_PATH/$FILE_BASE'_TEMP_split11.dat'
    FILE12=$OUTPUT_PATH/$FILE_BASE'_TEMP_split12.dat'
    FILE13=$OUTPUT_PATH/$FILE_BASE'_TEMP_split13.dat'
    FILE14=$OUTPUT_PATH/$FILE_BASE'_TEMP_split14.dat'
    
     let TOT_UNIT_QTY=0
      let TOT_RQSTD_AMT=0
      let TOT_ADMIN=0
      let TOT_REC_CNT_DTL=0
      let TOT_UNIT_QTY_TRLR=0
      let TOT_RQSTD_AMT_TRLR=0
      let TOT_NUM_OF_REC_TRLR=0
      let TOT_ADMIN_TRLR=0
      
      rm -f $OUTPUT_PATH/$FILE_BASE'_CHECKING_OUTPUT.dat'
      
      while read -u3 F1 && read -u4 F2 && read -u5 F3 && read -u6 F4 && read -u7 F5 && read -u8 F6 && read -u9 F7 ; do
      
         print  $F1 $F2 $F3 $F4 $F5 $F6 $F7 $OUTPUT_PATH/$FILE_BASE >> $OUTPUT_PATH/$FILE_BASE'_CHECKING_OUTPUT.dat'
      
         if [[ $F1 = "UD" ]]; then 
            let TOT_REC_CNT_DTL=$TOT_REC_CNT_DTL+1
            let UNIT_QTY_NUM=$F2
            if [[ $F3 = "-" ]]; then
               let TOT_UNIT_QTY=$TOT_UNIT_QTY-$UNIT_QTY_NUM
            else 
               let TOT_UNIT_QTY=$TOT_UNIT_QTY+$UNIT_QTY_NUM
            fi
            let RQSTD_AMT=$F4
            if [[ $F5 = "-" ]]; then
               let TOT_RQSTD_AMT=$TOT_RQSTD_AMT-$RQSTD_AMT
            else 
               let TOT_RQSTD_AMT=$TOT_RQSTD_AMT+$RQSTD_AMT
            fi
            let ADMIN_AMT=$F6
            if [[ $F7 = "-" ]]; then
               let TOT_ADMIN=$TOT_ADMIN-$ADMIN_AMT
            else 
               let TOT_ADMIN=$TOT_ADMIN+$ADMIN_AMT
            fi
         fi 
      
      done 3<$FILE1 4<$FILE2 5<$FILE3 6<$FILE4 7<$FILE5 8<$FILE6 9<$FILE7  
      

      while read -u2 F1 && read -u3 F8 && read -u4 F9 && read -u5 F10 && read -u6 F11 && read -u7 F12 && read -u8 F13 && read -u9 F14; do
      
         print $F1 $F8 $F9 $F10 $F11 $F12 $F13 $F14 $F15 $OUTPUT_PATH/$FILE_BASE >> $OUTPUT_PATH/$FILE_BASE'_CHECKING_OUTPUT.dat'
      
             
         if [[ $F1 = "TR" ]]; then 
            let NEG_NUM=-1
            let TOT_UNIT_QTY_TRLR=$F8
            if [[ $F9 = "-" ]]; then
               let TOT_UNIT_QTY_TRLR=$TOT_UNIT_QTY_TRLR*$NEG_NUM
            fi
            let TOT_RQSTD_AMT_TRLR=$F10
            if [[ $F11 = "-" ]]; then
               let TOT_RQSTD_AMT_TRLR=$TOT_RQSTD_AMT_TRLR*$NEG_NUM
            fi
            let TOT_NUM_OF_REC_TRLR=$F12
            let TOT_ADMIN_TRLR=$F13
            if [[ $F14 = "-" ]]; then
               let TOT_ADMIN_TRLR=$TOT_ADMIN_TRLR*$NEG_NUM
            fi
         fi 
      
      done 2<$FILE1 3<$FILE8 4<$FILE9 5<$FILE10 6<$FILE11 7<$FILE12 8<$FILE13 9<$FILE14 
      

      cat > $OUTPUT_PATH/$EMAIL_NCPDP_INFO << 99999



Pico : $PICO_NO 
Manufacturer : $MFG_NAM
Cycle : $CYCLE_GID
Cycle Period : $BEGIN_DATE_INFO through $END_DATE_INFO
File Control Number : $SEQ_NBR
 
   
   ***** The Medicare NCPDP File information is as follows *****
   

                    Medicare NCPDP Detail Information 
                    
                    
 Total Unit Quantity:
 
 _____From Database : $UNIT_QTY
 _____From DTL Recs : $TOT_UNIT_QTY          (implied 3 decimals)
 _____From TRLR Rec : $TOT_UNIT_QTY_TRLR     (implied 3 decimals)
    
 
 
 Manufacturer Responsibility Rebate Amount : 
 
 _____From Database : $MFG_RESPBLTY
 
 
 
 Manufacturer Rebate Amount : 
 
 _____From Database : $FLAT_FEE_RBATE
 
 
 
 Total Requested Rebate Amount: 
    
 _____From Database : $RQSTD_RBATE_AMT
 _____From DTL Recs : $TOT_RQSTD_AMT          (implied 2 decimals)
 _____From TRLR Rec : $TOT_RQSTD_AMT_TRLR     (implied 2 decimals)
 
 
 
 Total Admin Fee Amount: 
 
 _____From Database : $ADMIN_FEE_AMT
 _____From DTL Recs : $TOT_ADMIN             (implied 2 decimals)
 _____From TRLR Rec : $TOT_ADMIN_TRLR        (implied 2 decimals)   
 
 
 
 Total Detail Records: 
 
 _____From Database : $TOT_REC_CNT           (including header and trailer records)
 _____From DTL Recs : $TOT_REC_CNT_DTL       (detail rec count only)
 _____From TRLR Rec : $TOT_NUM_OF_REC_TRLR   (including header and trailer records)                     
 
 
 
99999
   
      chmod 777 $OUTPUT_PATH/$EMAIL_NCPDP_INFO
   
      export EMAIL_SUBJECT="Medicare_NCPDP_File_Summary_Notification"
   
      mailx -c MMRebInvoiceITD@caremark.com -s $EMAIL_SUBJECT MedicareNCPDP@caremark.com < $OUTPUT_PATH/$EMAIL_NCPDP_INFO
      #mailx  -s $EMAIL_SUBJECT MMRebInvoiceITD@caremark.com < $OUTPUT_PATH/$EMAIL_NCPDP_INFO
      #mailx -c MMRebInvoiceITD@caremark.com -s $EMAIL_SUBJECT MedicareNCPDP@caremark.com < $OUTPUT_PATH/$EMAIL_NCPDP_INFO
      #mailx -s $EMAIL_SUBJECT Kurt.Gries@caremark.com < $OUTPUT_PATH/$EMAIL_NCPDP_INFO
   
   
      print `date` 'Completed NCPDP for ' $PICO_NO >> $OUTPUT_PATH/$LOG_FILE
      print 'creating Trigger file to allow a new parallel process to start' >> $OUTPUT_PATH/$LOG_FILE
      RETCODE=0
    fi
else
   RETCODE=99
fi   
    
if [[ $RETCODE != 0 ]]; then
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Failure in Medicare NCPDP creation process '       >> $OUTPUT_PATH/$LOG_FILE
   print 'Oracle RETURN CODE is : ' $ORA_RETCODE             >> $OUTPUT_PATH/$LOG_FILE
   print 'Oracle Email RETURN CODE is : ' $ORA_EMAIL_RETCODE >> $OUTPUT_PATH/$LOG_FILE
   print 'ZIP RETURN CODE is    : ' $ZIP_RETCODE             >> $OUTPUT_PATH/$LOG_FILE
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
   export EMAILPARM4="MAILPAGER"
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
   
   ### we will create the Trigger file on failure to free up the thread for aother process to start
   print 'Trigger file for completion of Medicare NCPDP for Pico ' $PICO_NO >> $OUTPUT_PATH/"rbate_"$SCHEDULE"_"$JOB"_Medicare_NCPDP_Creation""_ASYCH"$LOOPCTR".TRG"
   exit $RETCODE
fi

rm -f $OUTPUT_PATH/$SQL_PIPE_FILE

rm -f $OUTPUT_PATH/$FILE_BASE'_TRLR_split01.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TRLR_split02.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TRLR_split03.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TRLR_split04.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TRLR_split05.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TRLR_split06.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TRLR_split07.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TRLR_split08.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TRLR_split09.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TRLR_split10.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TRLR_split11.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TRLR_split12.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TRLR_split13.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TEMP_split01.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TEMP_split02.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TEMP_split03.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TEMP_split04.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TEMP_split05.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TEMP_split06.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TEMP_split07.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TEMP_split08.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TEMP_split09.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TEMP_split10.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TEMP_split11.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TEMP_split12.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TEMP_split13.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_TEMP_split14.dat'
rm -f $OUTPUT_PATH/$FILE_BASE'_CHECKING_OUTPUT.dat'
rm -f $OUTPUT_PATH/$FILE_BASE"_EMAIL_TEXT.txt"
rm -f $OUTPUT_PATH/$DAT_FILE_ZIP
rm -f $OUTPUT_PATH/$DAT_FILE

print "....Completed executing " $SCRIPTNAME " ...."   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
print 'Trigger file for completion of Medicare NCPDP for Pico ' $PICO_NO >> $OUTPUT_PATH/"rbate_"$SCHEDULE"_"$JOB"_Medicare_NCPDP_Creation""_ASYCH"$LOOPCTR".TRG"

exit $RETCODE

