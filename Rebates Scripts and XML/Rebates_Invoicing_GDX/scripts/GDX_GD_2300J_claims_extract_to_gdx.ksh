#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GD_2300J_claims_extract_to_gdx.ksh   
# Title         : Claim extract from GPO to GDX..
#
# Description   : This script will pull claims from the GPO Oracle 
#                 environment for processing into GDX.
#
# Abends        : 
#                 
# Maestro Job   : GD_2300J
#
# Parameters    : N/A 
#
# Output        : Log file as $LOG_FILE, TRIGGER_FILE as ${OUTPUT_PATH}/${FILE_BASE}.trg
#
# Input Files   :
#   (The following file contains portions of the sql to pull claims.)
#   ${SQL_PATH}/GDX_GD_2300J_claims_extract_to_gdx_${PRCS_VAL}
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 07-30-07   qcpi733     changed GPO join table from DWCORP.MV_FRMLY to 
#                        DMA_RBATE2.V_FRMLY_ALL for CVS Integration
# 11-18-06   Gries       Added mv_frmly and AND clause to GPO extract
# 04-25-06   Castillo    1. Added PRCS_VAL to FILE_BASE and adjusted other file names.
#                        2. Added exit_error function and removed nested
#                            error check if blocks.
#                        3. Changed the way the read of cycle parameters was done.
#                        4. Used code blocks for large output redirections.
#                        5. Moved all unchangeable variables to the same place.
#                        6. Removed unused variables.
# 11-01-05   Nandini     Medicare related changes
# 10-27-05   qcpi733     Added quarter cycle gid and changed GPO where 
#                        clause to use SCRC not VCSCRC.
# 09-14-05   Gries       Initial Creation.
#-------------------------------------------------------------------------#


#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error {
    RETCODE=$1
    EMAILPARM4='  '
    EMAILPARM5='  '

    if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
    fi
    
    {
        print 'Sending email notification with the following parameters'
    
        print "JOBNAME is $JOBNAME"
        print "SCRIPTNAME is $SCRIPTNAME"
        print "LOG_FILE is $LOG_FILE"
        print "EMAILPARM4 is $EMAILPARM4"
        print "EMAILPARM5 is $EMAILPARM5"
    
        print '****** end of email parameters ******'
    } >> $LOG_FILE
    
    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...." >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
    exit $RETCODE
}
#-------------------------------------------------------------------------#


#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/Common_GDX_Environment.ksh
#-------------------------------------------------------------------------#
# Call the Common used script functions to make functions available
#-------------------------------------------------------------------------#
. $SCRIPT_PATH/Common_GDX_Script_Functions.ksh

# Region specific variables
if [[ $REGION = "prod" ]]; then
    if [[ $QA_REGION = "true" ]]; then
        ALTER_EMAIL_ADDRESS=""
    else
        ALTER_EMAIL_ADDRESS=""
    fi
else
    ALTER_EMAIL_ADDRESS="nick.tucker@caremark.com"
fi

# Variables
PRCS_VAL=$(echo "$1" | tr 'a-z' 'A-Z')
RETCODE=0
SCHEDULE=
JOB="GD_2300J"
JOBNAME=$JOB
FILE_BASE="GDX${SCHEDULE}_${JOB}_claims_extract_to_gdx_${PRCS_VAL}"
SCRIPTNAME=$(basename "$0")
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}.log"
LOG_FILE="${LOG_PATH}/${FILE_BASE}.log"
SQL_PIPE_FILE="${OUTPUT_PATH}/${FILE_BASE}_pipe.lst"
SQL_DATA_CNTL_FILE="${OUTPUT_PATH}/${FILE_BASE}_cntl.dat"
QTR_CYCLE_GID=
MODEL_TYPE=$(echo "$PRCS_VAL" | cut -c 1)
ORA_SQL_FILE_PV="${SQL_PATH}/${FILE_BASE}.sql"
ORA_SQL_FILE="${SQL_PATH}/${FILE_BASE}_ora.sql"
ORACLE_DB_USER_PASSWORD=$(cat "${SCRIPT_PATH}/ora_user.fil")
TRIGGER_FILE="${OUTPUT_PATH}/${FILE_BASE}.trg"

# SQL Constants
CYCLE_TYPE_MONTHLY="1"
CYCLE_TYPE_QUARTERLY="2"
CYCLE_STATUS_ACTIVE="A"
GPO_CLAIM_STATUS_FLAGS="0,24,26"

rm -f $LOG_FILE
rm -f $ORA_SQL_FILE
rm -f $SQL_PIPE_FILE

{
    date +"%D %r %Z"
    print "Starting the script to load the Claims tables"
    print
    print
    print "=================================================================="
    print "PRCS_VAL           = [$PRCS_VAL]"
    print "MODEL_TYPE         = [$MODEL_TYPE]"
    print "FILE_BASE          = [$FILE_BASE]"
    print "SCRIPTNAME         = [$SCRIPTNAME]"
    print "SQL_PIPE_FILE      = [$SQL_PIPE_FILE]"
    print "SQL_DATA_CNTL_FILE = [$SQL_DATA_CNTL_FILE]"
    print "ORA_SQL_FILE_PV    = [$ORA_SQL_FILE_PV]"
    print "ORA_SQL_FILE       = [$ORA_SQL_FILE]"
    print "TRIGGER_FILE       = [$TRIGGER_FILE]"
    print "=================================================================="
    print
} >> $LOG_FILE

# check arguments
if [[ "$PRCS_VAL" != 'GPO' && "$PRCS_VAL" != 'DSC' && "$PRCS_VAL" != 'XMD' ]]; then
    {
        print "************* S E V E R E  ***  E R R O R *********************"
        print "************* S E V E R E  ***  E R R O R *********************"
        print "************* S E V E R E  ***  E R R O R *********************"
        print
        print "The PRCS_VAL [$PRCS_VAL], supplied to the script is not valid."
        print "This is a major issue. We do not know what to process."
        print
        print "************* S E V E R E  ***  E R R O R *********************"
        print "************* S E V E R E  ***  E R R O R *********************"
        print "************* S E V E R E  ***  E R R O R *********************"
    } >> $LOG_FILE
    exit_error 999
fi


#-------------------------------------------------------------------------#
# Generate the cycle parameters for claims pull.
#-------------------------------------------------------------------------#
{
    date +"%D %r %Z"
    print "Begin building Oracle SQL file for CLAIM Extract TEST"
    print
} >> $LOG_FILE
# generate sql file
cat > $ORA_SQL_FILE << EOF
    set LINESIZE 200
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
    SPOOL $SQL_DATA_CNTL_FILE
    alter session enable parallel dml;

    SELECT 
        MIN(a.rbate_cycle_gid)
        ,' '
        ,MAX(a.rbate_cycle_gid)
        ,' '
        ,b.rbate_cycle_gid qtrly_cycle_gid
        ,' '
        ,TO_CHAR(MIN(a.cycle_start_date),'YYYY-MM-DD')
        ,' '
        ,TO_CHAR(MAX(a.cycle_end_date),'YYYY-MM-DD')
        ,' '
        ,SUBSTRB(MIN(a.rbate_cycle_gid),5,2)
        ,' '
        ,TO_CHAR(MIN(b.cycle_start_date),'YYYY-MM-DD')
        ,' '
        ,TO_CHAR(MAX(b.cycle_end_date),'YYYY-MM-DD')
    FROM dma_rbate2.t_rbate_cycle a
        ,dma_rbate2.t_rbate_cycle b
    WHERE a.rbate_cycle_type_id = '$CYCLE_TYPE_MONTHLY'
        AND a.rbate_cycle_status = '$CYCLE_STATUS_ACTIVE'
        AND a.cycle_start_date BETWEEN b.cycle_start_date AND b.cycle_end_date
        AND a.cycle_end_date BETWEEN b.cycle_start_date AND b.cycle_end_date
        AND b.rbate_cycle_type_id = '$CYCLE_TYPE_QUARTERLY'
    GROUP BY b.rbate_cycle_gid;

    quit;
EOF
{
    print "********* SQL File for Control dates is **********"
    cat $ORA_SQL_FILE
    print "********* SQL File for Control dates end *********"
} >> $LOG_FILE

#-------------------------------------------------------------------------#
# Execute the sql file.
#-------------------------------------------------------------------------#
$ORACLE_HOME/sqlplus -s $ORACLE_DB_USER_PASSWORD @$ORA_SQL_FILE
RETCODE=$?
if [[ $RETCODE != 0 ]] ; then
    {
        print 'CYCLE SELECTION SQL FAILED - error message is: '
        print
        tail -20 $SQL_DATA_CNTL_FILE
    } >> $LOG_FILE
    exit_error $RETCODE
fi
print 'CYCLE SELECTION SUCCESSFUL: ' >> $LOG_FILE 

#-------------------------------------------------------------------------#
# Read in the cycle parameters for claims pull.
#-------------------------------------------------------------------------#
read cycle_low cycle_high QTR_CYCLE_GID begin_date end_date cycle_month qtr_start_date qtr_end_date < $SQL_DATA_CNTL_FILE
{ # output parameters to log file
    print
    date
    print 'Cycle data returned from Oracle.'
    print
    print "  cycle_low      = [$cycle_low]"
    print "  cycle_high     = [$cycle_high]"
    print "  QTR_CYCLE_GID  = [$QTR_CYCLE_GID]"
    print "  begin_date     = [$begin_date]"
    print "  end_date       = [$end_date]"
    print "  cycle_month    = [$cycle_month]"
    print "  qtr_start_date = [$qtr_start_date]"
    print "  qtr_end_date   = [$qtr_end_date]"
} >> $LOG_FILE

if [[ -z $cycle_low || -z $cycle_high || -z $QTR_CYCLE_GID || -z $begin_date || -z $end_date || -z $end_date || -z $cycle_month || -z $qtr_start_date || -z $qtr_end_date ]]; then
    print '\nNo cycle data returned from Oracle.\n' >> $LOG_FILE
    exit_error 1
fi

SQL_DATA_FILE="${FILE_BASE}_${cycle_month}.dat"
print "\nSQL_DATA_FILE is: $SQL_DATA_FILE\n" >> $LOG_FILE


#-------------------------------------------------------------------------#
# Create Oracle SQL file
#-------------------------------------------------------------------------#
rm -f $SQL_PIPE_FILE
mkfifo $SQL_PIPE_FILE
dd if=$SQL_PIPE_FILE of=$OUTPUT_PATH/$SQL_DATA_FILE bs=100k &

cat > $ORA_SQL_FILE << EOF
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
    SPOOL $SQL_PIPE_FILE
    alter session enable parallel dml;
EOF

cat $ORA_SQL_FILE_PV >> $ORA_SQL_FILE 

if [[ "$PRCS_VAL" = 'GPO' ]]; then
    cat >> $ORA_SQL_FILE << EOF
    FROM  dma_rbate2.v_frmly_all tmfx 
	 ,dma_rbate2.s_claim_rbate_cycle scrc
         ,dma_rbate2.v_combined_scr vcs
    WHERE scrc.cycle_gid  = $QTR_CYCLE_GID
    AND   scrc.batch_date BETWEEN TO_DATE ('$begin_date','YYYY-MM-DD')
                          AND     TO_DATE ('$end_date'  ,'YYYY-MM-DD')
    AND   scrc.claim_status_flag IN ($GPO_CLAIM_STATUS_FLAGS)
    AND   scrc.batch_date = vcs.batch_date
    AND   scrc.claim_gid  = vcs.claim_gid
    AND   scrc.frmly_gid  = tmfx.frmly_gid(+)
    ;
    quit;
EOF
elif [[ "$PRCS_VAL" = 'DSC' ]]; then
    cat >> $ORA_SQL_FILE << EOF
    FROM DMA_RBATE2.s_claim_refresh_dsc scrd
    ;
    quit;
EOF
elif [[ "$PRCS_VAL" = 'XMD' ]]; then
    cat >> $ORA_SQL_FILE << EOF
    FROM DMA_RBATE2.s_claim_refresh_xmd scrd
    ;
    quit;
EOF
fi

{
    print
    print "********* SQL File for Claims Extract is **********"
    cat $ORA_SQL_FILE
    print "********* SQL File for Claims Extract end *********"
    print
    
    print
    date +"%D %r %Z"
    print "Finished building Oracle SQL file, start extracting data "
    print
} >> $LOG_FILE


#-------------------------------------------------------------------------#
# Extract the claims
#-------------------------------------------------------------------------#
START_DATE=`date +"%D %r %Z"`
$ORACLE_HOME/sqlplus -s $ORACLE_DB_USER_PASSWORD @$ORA_SQL_FILE
RETCODE=$?
END_DATE=`date +"%D %r %Z"`
{
    date +"%D %r %Z"
    print "Completed extract of $PRCS_VAL clms."
    print "Started at $START_DATE and completed at $END_DATE"
    print
    print "RETCODE = [${RETCODE}]"
} >> $LOG_FILE

if [[ $RETCODE != 0 ]]; then
    {
        print "Error when extracting $PRCS_VAL claims from Oracle."
        tail -20 $OUTPUT_PATH/$SQL_DATA_FILE
    } >> $LOG_FILE
    exit_error $RETCODE
fi


#-------------------------------------------------------------------------#
# Create the trigger file
#-------------------------------------------------------------------------#
print "$SQL_DATA_FILE $cycle_month $MODEL_TYPE $qtr_start_date $qtr_end_date" > $TRIGGER_FILE


#-------------------------------------------------------------------------#
# Script completed
#-------------------------------------------------------------------------#
{
    date +"%D %r %Z"
    print
    print
    print "....Completed executing $SCRIPTNAME ...."
} >> $LOG_FILE
mv -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
exit $RETCODE

