#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_Astra_Merk_phmcy_ndc_extract.ksh   
# Title         : Snapshot refresh.
#
# Description   : Extracts Astra_Merk_phmcy_ndc and ftps to the apc data store
# Maestro Job   : RIMN4750/RI_4750J
#
# Parameters    : None required. Job will calculate them. However, for rerun 
#                 purposes, CYCLE_GID and MONTH can be supplied to run for a 
#                 specific month.
#
# Output        : Log file as $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 04-14-2003  K. Gries    Initial Creation.
# 01-12-2004  is45401     added hardcoded ndcs '00378615093','00378521193'
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
# 
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
     export REBATES_DIR=rebates_integration
     export DATA_DIR=rbate2
   else  
     export REBATES_DIR=rebates_integration
     export DATA_DIR=rbate2
fi

rm -f $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
rm -f $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.dat
rm -f $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract_ftpcommands.dat

export EDW_USER="/"

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
#
# If CYCLE_GID and MONTH are passed in then they will be used. Otherwise,
# the script will calculate the dates to be used.
#-------------------------------------------------------------------------#

if [ $# -lt 1 ] 
then
    print " " >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    print "CYCLE_GID parameter not supplied. We will calculate the CYCLE_GID." >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    print "MONTH parameter not supplied. We will calculate the MONTH." >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    print " " >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    print `date` >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    print " " >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    MONTH=`date +"%m"`
    YEAR=`date +"%Y"`
    Q1="41"
    Q2="42"
    Q3="43"
    Q4="44"
    
    print "MONTH is ======" $MONTH "======" >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    print "YEAR is ======" $YEAR "======" >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log

    if [[ $MONTH -eq 04 || $MONTH -eq 03 || $MONTH -eq 02 ]]
      then
        PROCESSMONTH="0"$(($MONTH - 1)) 
        PROCESSYEAR=$YEAR 
        CYCLE_GID=$PROCESSYEAR$Q1
    elif [[ $MONTH -eq 07 || $MONTH -eq 06 || $MONTH -eq 05 ]] 
      then
        PROCESSMONTH="0"$(($MONTH - 1)) 
        PROCESSYEAR=$YEAR 
        CYCLE_GID=$PROCESSYEAR$Q2
    elif [[ $MONTH -eq 10 || $MONTH -eq 09 || $MONTH -eq 08 ]]
      then 
        PROCESSMONTH="0"$(($MONTH - 1)) 
        PROCESSYEAR=$YEAR 
        CYCLE_GID=$PROCESSYEAR$Q3
    elif [[ $MONTH -eq 12 || $MONTH -eq 11 ]]
      then
        PROCESSMONTH=$(($MONTH - 1)) 
        PROCESSYEAR=$YEAR 
        CYCLE_GID=$PROCESSYEAR$Q4
    elif [[ $MONTH -eq 01 ]]
      then
        PROCESSMONTH=12 
        PROCESSYEAR=$(($YEAR - 1))
        CYCLE_GID=$PROCESSYEAR$Q4
    else
        print "Problem calculating YEAR, MONTH and CYCLE_GID" >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
        print "YEAR is " $YEAR >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
        print "MONTH is " $MONTH >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
        print "PROCESSYEAR is " $PROCESSYEAR >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
        print "PROCESSMONTH is " $PROCESSMONTH >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
        print "CYCLE_GID is " $CYCLE_GID >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
        exit 1
    fi

    print "PROCESSMONTH is ======" $PROCESSMONTH "======" >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    print "PROCESSYEAR is ======" $PROCESSYEAR "======" >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log

    print " " >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    print "CYCLE_GID is " $CYCLE_GID >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    print ' ' >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    print `date` >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log

else
    CYCLE_GID=$1
    MONTH=$2
    print " " >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    print "CYCLE_GID parameter supplied. CYCLE_GID is : " $CYCLE_GID >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    print "MONTH parameter supplied. MONTH is : " $MONTH >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    print " " >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    PROCESSMONTH=$MONTH
    print "PROCESSMONTH is ======" $PROCESSMONTH "======" >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    print `date` >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
    print " " >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
fi

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script
#-------------------------------------------------------------------------#

print " " >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
print "CYCLE_GID is " $CYCLE_GID >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
print ' ' >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
print "executing SQL" >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
print `date` >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat /staging/apps/rebates/$REGION/scripts/ora_user.fil`

#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#

export Source_file=$OUTPUT_PATH"/rbate_Astra_Merk_phmcy_ndc_extract"$PROCESSYEAR$PROCESSMONTH".dat"
rm -f $SCRIPT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.sql
rm -f $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract_pipe.lst
mkfifo $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract_pipe.lst
dd if=$OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract_pipe.lst of=$Source_file bs=100k &

cat > $SCRIPT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.sql << EOF
set LINESIZE 323
set trimspool on
set arraysize 100
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
SPOOL $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract_pipe.lst
alter session set optimizer_mode='first_rows';
alter session enable parallel dml;
select /*+ full(scrc) parallel(scrc,12) */
       scrc.rbate_id, '|'
      ,scrc.nabp_code, '|'
      ,scrc.ndc_code, '|'
      ,count(rx_nbr),'|'
      ,sum(scrc.unit_qty)
 from  dma_rbate2.s_claim_rbate_cycle scrc
where scrc.nabp_code in (0129292,4598225,4576902,3980958)
  and ((scrc.excpt_id > 9 and scrc.excpt_id <> 13 and scrc.excpt_id <> 14)
   or scrc.excpt_id is NULL)
  and scrc.ndc_code in (
'00008084181','00008084199','00008084381','00186060628','00186060631','00186060668','00186060682','00186074228','00186074231',
'00186074282','00186074328','00186074331','00186074368','00186074382','00186502031','00186502054','00186502082','00186502228',
'00186504031','00186504054','00186504082','00186504228','00300154111','00300154119','00300154130','00300304611','00300304613',
'00300304619','00300730930','00300731130','00378615093','00378521193','62856024330','62856024341','62856024390','62175011837',
'62175011832'
)
  and scrc.cycle_gid = $CYCLE_GID
  and to_char(scrc.batch_date,'mm') = $PROCESSMONTH
group by 
      scrc.rbate_id
     ,scrc.nabp_code
     ,scrc.ndc_code
order by 
      scrc.rbate_id
     ,scrc.nabp_code
     ,scrc.ndc_code 
;
                    
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SCRIPT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.sql

export RETCODE=$?

if [[ $RETCODE != 0 ]]; then
  print "SQL failed" >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
  print ' ' >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log 
  tail -20 $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.dat >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
else
 # build ftp commands and ftp file here
     
   export FTPCommand_File=$OUTPUT_PATH'/rbate_Astra_Merk_phmcy_ndc_extract_ftpcommands.dat'
   export FtpSrcFile='rbate_Astra_Merk_phmcy_ndc_extract'$PROCESSYEAR$PROCESSMONTH'.dat'
   export FTP_IP=AZSHISP00 

   print 'cd /'$REBATES_DIR                                   >> $FTPCommand_File
   print 'cd '$DATA_DIR                                    >> $FTPCommand_File 
   print 'put ' $Source_file $FtpSrcFile ' (replace' >> $FTPCommand_File 

   print 'quit' >> $FTPCommand_File 

   print "FTPing " $Source_file " to the Rebates Datamart file " $FtpSrcFile  >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log   
   print `date` >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log

ftp -i  $FTP_IP < $FTPCommand_File >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log

fi

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " " >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
   print "  Error Executing rbate_Astra_Merk_phmcy_ndc_extract.ksh          " >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
   print "  Look in "$OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log       >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
   print "=================================================================" >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
   
# Send the Email notification 
   export JOBNAME="RIMN4750 / RI_4750J"
   export SCRIPTNAME=$OUTPUT_PATH"/rbate_Astra_Merk_phmcy_ndc_extract.ksh"
   export LOGFILE=$OUTPUT_PATH"/rbate_Astra_Merk_phmcy_ndc_extract.log"
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
   print "****** end of email parameters ******" >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log $LOG_ARCH_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

print "....Completed executing rbate_Astra_Merk_phmcy_ndc_extract.ksh ...."   >> $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log
mv -f $OUTPUT_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log $LOG_ARCH_PATH/rbate_Astra_Merk_phmcy_ndc_extract.log.`date +"%Y%j%H%M"`


exit $RETCODE

