#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KSMM7500_KS_7520J_rxlives_ruc_load.ksh   
# Title         : .
#
# Description   : Load rbate_reg.work_rxlives_ruc with processing months 
#                 Lives file for Rebate Utilities and RxClaim Defaults.
#                 also execute stored procedure prc_up_delete_retro_term.
#                 
#                 
# Maestro Job   : KSDMM7500 KS_7520J
#
# Parameters    : N/A - 
#                
# Input         : ruclives.ctl
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-30-2004  S.Swanson    Initial Creation.
# 04-06-2004  S.Swanson    added procedure executition logic.
# 06-24-2005  is23301     Oracle 10G change to spool to .lst files.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh


if [[ $REGION = "prod" ]];   then
     export REBATES_DIR=rebates_integration
     export ALTER_EMAIL_ADDRESS=''
     export MVS_DSN="PCS.P"
   if [[$QA_REGION = "true"]]; then
     export MVS_DSN="test.x"
     export ALTER_EMAIL_ADDRESS='' 
   fi
else
     export ALTER_EMAIL_ADDRESS=''  
     export REBATES_DIR=rebates_integration
     export MVS_DSN="test.d"
fi

RETCODE=0

SCHEDULE="KSMM7500"
JOB="KS_7520J"
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_rxlives_ruc_load"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$FILE_BASE".log"
PKG_LOG=$FILE_BASE"_PKG_LOG.log"
SQL_FILE=$FILE_BASE".sql"
SQL_PIPE_FILE=$FILE_BASE"_pipe.lst"


rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE
rm -f $OUTPUT_PATH/$PKG_LOG




#----------------------------------
# Oracle userid/password
# specific for rbate_reg database
# ora.user used for rbate invoicing
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script if applicable
#-------------------------------------------------------------------------#

print " " >> $OUTPUT_PATH/$LOG_FILE
print "TODAYS DATE " `date` >> $OUTPUT_PATH/$LOG_FILE
print "Monthly Load ruc Lives to work_rxlives_ruc starting" >> $OUTPUT_PATH/$LOG_FILE
print ' ' >> $OUTPUT_PATH/$LOG_FILE

#------------------------------------------------------------------------#
# Load ruclives.dat to work_rxlives_ruc
# using SQL Loader.               
#                                                                         
#-------------------------------------------------------------------------#
print `date` 'Beginning SQLLOADER Load rbate_reg.work_rxlives_ruc ' >> $OUTPUT_PATH/$LOG_FILE


$ORACLE_HOME/bin/sqlldr $db_user_password $INPUT_PATH/ruclives.ctl
                    
#-----------------------------------------------------------------------------
#check return code  if valid log completion else email error message
#
#-----------------------------------------------------------------------------
RETCODE=$?

if [[ $RETCODE = 0 ]]; then
   print `date` 'Completed SQLLOADER work_rxlives_ruc ' >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'New records loaded for RUC ' >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'Begin process to check for Retro terminated dates' >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   
#--------------------------------------------------------------------------------
#Create stored procedure to be executed
#--------------------------------------------------------------------------------

    Procedure_Name="rbate_reg.prc_up_delete_retroterm"
    PKGEXEC=$Procedure_Name;
    
#--------------------------------------------------------------------------------
#Set up the Pipe file, then build and execute the new SQL
#PRC_UP_DELETE_RETRO_TERM PROCESSING
#--------------------------------------------------------------------------------

    print `date` 'Beginning procedure call of ' $PKGEXEC >> $OUTPUT_PATH/$LOG_FILE

#----------------------------------------------------------------------------------
#Execute the SQL to run the prcedure to eliminate retro terms from work_rxlives_ruc
#----------------------------------------------------------------------------------

    print ' ' >> $OUTPUT_PATH/$LOG_FILE

cat > $INPUT_PATH/$SQL_FILE << EOF
set linesize 5000
set flush off
set TERMOUT OFF
set PAGESIZE 0
set NEWPAGE 0
set SPACE 0
set ECHO OFF
set FEEDBACK OFF
set HEADING OFF
set WRAP on
set verify off
whenever sqlerror exit 1
spool $OUTPUT_PATH/$PKG_LOG;

EXEC $PKGEXEC; 
quit;
EOF

    $ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE

    export RETCODE=$?

    cat $OUTPUT_PATH/$PKG_LOG >> $OUTPUT_PATH/$LOG_FILE


    if [[ $RETCODE = 0 ]]; then
     print `date` 'Completed Procedure call of ' $PKGEXEC >> $OUTPUT_PATH/$LOG_FILE
     print ' ' >> $OUTPUT_PATH/$LOG_FILE
    else
     print ' ' >> $OUTPUT_PATH/$LOG_FILE
     print 'Failure in procedure call of ' $PKGEXEC >> $OUTPUT_PATH/$LOG_FILE
     print 'Procedure call RETURN CODE is : ' $RETCODE >> $OUTPUT_PATH/$LOG_FILE
     print ' '
#--------------------------------------------------
#END OF RETURN CODE CHECKING FOR PROCEDURE PROCESSING
#----------------------------------------------------
    fi
   
else
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'Failure in work_rxlives_ruc load. ' >> $OUTPUT_PATH/$LOG_FILE
   export RETCODE=$RETCODE
   print 'SQLLOADER - Load of work_rxlives_ruc failed : ' $RETCODE >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
#------------------------------------------------------
#END OF RETURN CODE CHECKING FOR SQLLOADER
#------------------------------------------------------
fi

if [[ $RETCODE != 0 ]]; then

#-------------------------------------------------------------------------#
# Send email describing error                  
#-------------------------------------------------------------------------#

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
rm -f $OUTPUT_PATH/$PKG_LOG
rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$SQL_PIPE_FILE

#--------------------------------------------------------------
# remove trigger file ruclives load process
#--------------------------------------------------------------
print "Removing trigger file $INPUT_PATH/ruclives.trigger" >> $OUTPUT_PATH/$LOG_FILE
rm -f $INPUT_PATH/'ruclives.trigger'

print "....Completed executing " $SCRIPTNAME " ...."   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

