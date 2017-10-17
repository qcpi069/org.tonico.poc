#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCWK2300_KC_2300J_claims_extract_to_gdx.ksh
# Title         : Extract Claims to be sent over to GDX system.
#
# Description   : Extract all paid and unmatched reversal Claims
#                 and send them over to GDX system.
#                
#
# Maestro Job   : KC_2300J
#
# Parameters    : None
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-02-2005   GJ        Initial Creation. 
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh
#. /staging/apps/rebates/prod/scripts/rebates_env.ksh

if [[ $REGION = 'prod' ]];   then
    if [[ $QA_REGION = 'true' ]];   then
        # Running in the QA region
        REBATES_DIR=/GDX/$REGION/input     
        ALTER_EMAIL_ADDRESS=''
        ora_schema_owner='DMA_RBATE2'
    ora_schema2_owner='DWCORP'
    FTP_NT_IP=r07prd01
    else
        # Running in Prod region
        REBATES_DIR=/GDX/$REGION/input     
        ALTER_EMAIL_ADDRESS=''
        ora_schema_owner='DMA_RBATE2'
    ora_schema2_owner='DWCORP'
    FTP_NT_IP=r07prd01
    fi
else
    # Running in Development region
    # REBATES_DIR=/GDX/$REGION/input     
    ora_schema_owner='DMA_RBATE2'
    ora_schema2_owner='DWCORP'   
    REBATES_DIR=/datar1/test    
    ALTER_EMAIL_ADDRESS='Ganapathi.jayaraman@caremark.com' 
    FTP_NT_IP=dwhtest1
fi

SCHEDULE='KCWK2300'
JOB='KC_2300J'
FILE_BASE='rbate_'$SCHEDULE'_'$JOB'_claims_extract_to_gdx'
SCRIPTNAME=$FILE_BASE'.ksh'
LOG_FILE=$OUTPUT_PATH/$FILE_BASE'.log'
ARCH_LOG_FILE=$FILE_BASE'.log.'`date +'%Y%j%H%M'`
SQL_FILE=$FILE_BASE'.sql'
SQL_FILE_DATE_CNTRL=$FILE_BASE'_date_cntrl.sql'
SQL_PIPE_FILE=$FILE_BASE'_pipe'
DAT_FILE=$FILE_BASE'.dat.'`date +'%Y%j%H%M'`
DATE_CNTRL_FILE=$FILE_BASE'_date_control_file.dat'
FTP_CMDS=$INPUT_PATH/$FILE_BASE'_ftpcommands.txt'

rm -f $LOG_FILE
rm -f $OUTPUT_PATH/$FILE_BASE.dat.*
rm -f $OUTPUT_PATH/$DATE_CNTRL_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $INPUT_PATH/$SQL_FILE_DATE_CNTRL
rm -f $FTP_CMDS

print ' '                                             >> $LOG_FILE
print `date` ' starting ' $SCRIPTNAME                 >> $LOG_FILE
print 'executing Cycle selection SQL'                 >> $LOG_FILE

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`


#-------------------------------------------------------------------------#
# Read Oracle to get the cycle_range for claims pull.                
#                                                                         
#-------------------------------------------------------------------------#

cat > $INPUT_PATH/$SQL_FILE_DATE_CNTRL << EOF
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
SPOOL $OUTPUT_PATH/$DATE_CNTRL_FILE
alter session enable parallel dml; 

SELECT MIN (rbate_cycle_gid), ' ', MAX (rbate_cycle_gid), ' ',
       MIN (cycle_start_date), ' ', MAX (cycle_end_date)
 from $ora_schema_owner.T_RBATE_CYCLE
where rbate_cycle_type_id = '2'
 and rbate_cycle_status = 'A'
;

quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE_DATE_CNTRL

RETCODE=$?
if [[ $RETCODE != 0 ]] ; then
    print 'CYCLE SELECTION SQL FAILED - error message is: ' >> $LOG_FILE 
      print ' '                                                   >> $LOG_FILE 
      tail -20 $OUTPUT_PATH/$DATE_CNTRL_FILE                      >> $LOG_FILE
else
    FIRST_READ=1
    while read cycle_min cycle_max cycle_start_dt cycle_end_dt; do
     if [[ $FIRST_READ != 1 ]]; then
            print 'Finishing control file read'                     >> $LOG_FILE
     else
            export FIRST_READ=0
            print 'read record from control file'                   >> $LOG_FILE
            if [[ -z $cycle_min || -z $cycle_max || -z $cycle_start_dt || -z $cycle_end_dt ]] ; then
                RETCODE=1
                print ' '                                                   >> $LOG_FILE
                print `date`                                                >> $LOG_FILE
                print 'No cycle data returned from Oracle.'                 >> $LOG_FILE
                print ' '                                                   >> $LOG_FILE
                print 'min cycle Gid from Oracle is      >'$cycle_min'<'    >> $LOG_FILE
            print 'max cycle Gid from Oracle is      >'$cycle_max'<'    >> $LOG_FILE
            print 'Start Date from Oracle is    >'$cycle_start_dt'<'    >> $LOG_FILE
            print 'End Date from  Oracle is       >'$cycle_end_dt'<'    >> $LOG_FILE
            print ' '                                                   >> $LOG_FILE
            else 
            print 'Oracle Cycle data read completed.'               >> $LOG_FILE
            print 'min cycle gid is' $cycle_min                 >> $LOG_FILE
            print 'max cycle gid is' $cycle_max                 >> $LOG_FILE
                print 'min cycle start date is' $cycle_start_dt         >> $LOG_FILE
                print 'max cycle end date is' $cycle_end_dt         >> $LOG_FILE
            begin_date=$cycle_start_dt
                end_date=$cycle_end_dt  
            cycle_low=$cycle_min
            cycle_high=$cycle_max       
            fi                  
       fi 
     done < $OUTPUT_PATH/$DATE_CNTRL_FILE           
fi

#-------------------------------------------------------------------------#
# If the cycle gid is read from the above sucessfully then build and EXEC 
# the following SQL.               
# The cycle Gid pulled from above sql will be used to query the appropriate
# scrc claims table partition.                                                                        
#-------------------------------------------------------------------------#

if [[ $RETCODE = 0 ]] ; then
print '  '                                  >> $LOG_FILE
print `date` ' starting  claims extract SQL '               >> $LOG_FILE    
print '  '                             >> $LOG_FILE

#---------------------------------------------------
# HARD CODED DATES  INSERTED FOR SIT - Q1/2005
#--------------------------------------------------
begin_date=2005-01-01
end_date=2005-03-31     
cycle_low=200541
cycle_high=200541
#----------------------------------------------------
# HARD CODE COMPLETE
#----------------------------------------------------

rm -f $OUTPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
mkfifo $OUTPUT_PATH/$SQL_PIPE_FILE
dd if=$OUTPUT_PATH/$SQL_PIPE_FILE of=$OUTPUT_PATH/$DAT_FILE bs=100k &

cat > $SCRIPT_PATH/$SQL_FILE << EOF
set LINESIZE 700
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
set timing off
spool $OUTPUT_PATH/$SQL_PIPE_FILE
alter session enable parallel dml;

SELECT /*+ ORDERED DRIVING_SITE(SCRC) PARALLEL(MF,8) PARALLEL(VP,8) PARALLEL(VCS,8) PARALLEL(SCRC,8)
        USE_HASH (SCRC) PQ_DISTRIBUTE(SCRC, HASH, HASH)
        PQ_DISTRIBUTE(VCS, HASH, HASH)
        PQ_DISTRIBUTE(VP, HASH, HASH)*/
          scrc.claim_gid
       || '|'
       || scrc.extnl_src_code
       || '|'
       || DECODE (scrc.extnl_src_code, 'RECAP', 'int', 'RXC', 'int', 'QLC', 'int', 'ext')
       || '|'
       || scrc.extnl_claim_id
       || '|'
       || NULL
       || '|'
       || NULL
       || '|'
       || scrc.nabp_code
       || '|'
       || scrc.dspnd_date
       || '|'
       || scrc.rx_nbr
       || '|'
       || scrc.new_refil_code
       || '|'
       || scrc.batch_date
       || '|'
       || scrc.ndc_code
       || '|'
       || 1
       || '|'
       || 0
       || '|'
       || 0
       || '|'
       || NULL
       || '|'
       || NULL
       || '|'
       || scrc.unit_qty
       || '|'
       || scrc.days_sply
       || '|'
       || DECODE (scrc.mail_order_code, '1', '2', '3')
       || '|'
       || NULL
       || '|'
       || scrc.claim_type
       || '|'
       || vcs.awp_unit_cst
       || '|'
       || scrc.cntrc_fee_paid
       || '|'
       || scrc.ingrd_cst
       || '|'
       || scrc.amt_paid
       || '|'
       || NULL
       || '|'
       || scrc.amt_copay
       || '|'
       || vcs.copay_src_code
       || '|'
       || NULL
       || '|'
       || vp.addr_zip_code
       || '|'
       || NULL
       || '|'
       || NULL
       || '|'
       || NULL
       || '|'
       || mf.drug_list_extnl_type
       || '|'
       || scrc.frmly_id
       || '|'
       || NULL
       || '|'
       || NULL
       || '|'
       || NULL
       || '|'
       || NULL
       || '|'
       || NULL
       || '|'
       || NULL
       || '|'
       || NULL
       || '|'
       || scrc.rbate_id
       || '|'
       || 'G'
       || '|'
       || scrc.extnl_lvl_id1
       || '|'
       || scrc.extnl_lvl_id2
       || '|'
       || scrc.extnl_lvl_id3
       || '|'
       || scrc.extnl_lvl_id4
       || '|'
       || scrc.extnl_lvl_id5
       || '|'
       || scrc.feed_id
       || '|'
       || scrc.mbr_gid
       || '|'
       || scrc.prior_athzn_flag
       || '|'
       || scrc.lcm_code
       || '|'
       || NULL
       || '|'
       || NULL
       || '|'
       || NULL
       || '|'
       || NULL
       || '|'
       || NULL
       || '|'
       || NULL
       || '|'
       || SYSDATE
  FROM $ora_schema2_owner.mv_frmly mf, 
     $ora_schema_owner.s_claim_rbate_cycle scrc,
       $ora_schema_owner.v_phmcy vp,
       $ora_schema_owner.v_combined_scr vcs       
 WHERE scrc.cycle_gid  BETWEEN $cycle_low and $cycle_high
   AND scrc.batch_date BETWEEN TO_DATE ('$begin_date', 'YYYY-MM-DD')
                           AND TO_DATE ('$end_date', 'YYYY-MM-DD')
   AND scrc.claim_status_flag IN (0, 26)
   AND scrc.batch_date = vcs.batch_date   
   AND scrc.claim_gid = vcs.claim_gid
   AND scrc.frmly_gid = mf.drug_list_gid
   AND scrc.phmcy_gid = vp.phmcy_gid
   ;
quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SCRIPT_PATH/$SQL_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]] ; then
       print 'claims select failed.Check log file for errors'       >> $LOG_FILE
       print 'return code is : ' $RETCODE                               >> $LOG_FILE   
       tail -20 $OUTPUT_PATH/$DAT_FILE                              >> $LOG_FILE
else   
       print `date` 'Completed extract of all claims     '          >> $LOG_FILE
       print ' '                                        >> $LOG_FILE
       print `date` 'staring process to create trigger file'            >> $LOG_FILE
       print                                        >> $LOG_FILE
       print ' ... Starting  common_ftp_trigger.ksh ... '           >> $LOG_FILE
       print ' ... Input  data file is ' $DAT_FILE                  >> $LOG_FILE
   
       MODEL_TYP='G'
       FTP_DATA_FILE=$OUTPUT_PATH/$DAT_FILE
       FTP_UD1=$MODEL_TYP
       FTP_UD2=$begin_date
       FTP_UD3=$end_date
   
       . $SCRIPT_PATH/Common_Ftp_Trigger.ksh

       RETCODE=$?
   
       if [[ $RETCODE != 0 ]] ; then
           print ' *** common_ftp_trigger.ksh returned return code ' $RETCODE   >> $LOG_FILE
       else
           print ' ... output Trigger file is ' $FTP_TRG_FILE...        >> $LOG_FILE
           print ' ... output datafile file is ' $FTP_DATA_FILE...      >> $LOG_FILE       
           print `date` ' ... Completed common_ftp_trigger.ksh '        >> $LOG_FILE
#------------------------------------------------------------------------------------------
#          FTP both data and trigger file to target directory.
#-------------------------------------------------------------------------------------------     
           print ' '                                      >> $LOG_FILE
       print `date` 'staring ftp process '                              >> $LOG_FILE
           print 'target directory is :'  $REBATES_DIR                    >> $LOG_FILE     
       print '  '                                     >> $LOG_FILE
           print 'cd '$REBATES_DIR                                        >> $FTP_CMDS
           print 'put ' $FTP_DATA_FILE ${FTP_DATA_FILE##/*/} ' (replace'  >> $FTP_CMDS
           print 'put ' $FTP_TRG_FILE ${FTP_TRG_FILE##/*/} ' (replace'    >> $FTP_CMDS
           print 'quit'                                                   >> $FTP_CMDS

           ftp -i $FTP_NT_IP < $FTP_CMDS                                >> $LOG_FILE
           
       print '  '                                     >> $LOG_FILE
           print ' ... transmitted Data file is ' $FTP_DATA_FILE...       >> $LOG_FILE
           print ' ... transmitted Trigger file is ' $FTP_TRG_FILE ...    >> $LOG_FILE
       print ' '                                      >> $LOG_FILE
       print `date` 'completed ftp process '                      >> $LOG_FILE
       print '  '                                     >> $LOG_FILE
          
       fi   
fi  
fi

###################################################################################
#
# Send Rmail to the core team if the process ended with non zero return code.              
#
###################################################################################

if [[ $RETCODE != 0 ]] ; then   
   JOBNAME=$JOB/$SCHEDULE 
   SCRIPTNAME=$SCRIPTNAME
   LOGFILE=$LOG_FILE
   EMAILPARM4='  '
   EMAILPARM5='  '      

   print 'Sending email notification with the following parameters' >> $LOG_FILE

   print 'JOBNAME is '  $JOB/$SCHEDULE                              >> $LOG_FILE 
   print 'SCRIPTNAME is ' $SCRIPTNAME                               >> $LOG_FILE
   print 'LOGFILE is ' $LOGFILE                                     >> $LOG_FILE
   print 'EMAILPARM4 is ' $EMAILPARM4                               >> $LOG_FILE
   print 'EMAILPARM5 is ' $EMAILPARM5                               >> $LOG_FILE

   print '****** end of email parameters ******'                    >> $LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh

   cp -f $LOG_FILE $LOG_ARCH_PATH/$ARCH_LOG_FILE

   exit  
fi

print `date` ' completed executing : ' $SCRIPTNAME                  >> $LOG_FILE                     

rm -f $FTP_TRG_FILE 
mv -f $LOG_FILE $LOG_ARCH_PATH/$ARCH_LOG_FILE

exit $RETCODE
