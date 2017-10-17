#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KC_2325J_GPO_Crossover_Process.ksh   
# Title         : .
#
# Description   : Executes PK_GPO_Crossover_Driver to acquire the 
#                 GPO Crossover claims for claim processing within the 
#                 GDX system.
#                 
#                 
#                 
# Maestro Job   : KC_2325J
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 09-09-2005  K. Gries    Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh
 

RETCODE=0
SCHEDULE=
JOB="KC_2325J"
FILE_BASE="rbate"$SCHEDULE"_"$JOB"_GPO_Crossover_Process"
SCRIPTNAME=$SCRIPT_PATH/$FILE_BASE".ksh"
LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
LOG_ARCH_FILE=$LOG_ARCH_PATH/$FILE_BASE".log."`date +"%Y%j%H%M"`
PKG_LOG=$OUTPUT_PATH/$FILE_BASE"_PKG_LOG.lst"
SQL_FILE=$INPUT_PATH/$FILE_BASE".sql"
DAT_FILE=$OUTPUT_PATH/$FILE_BASE".dat"

rm -f $LOG_FILE
rm -f $DAT_FILE
rm -f $SQL_FILE
rm -f $SQL_PIPE_FILE
rm -f $PKG_LOG

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        print " " >> $LOG_FILE
        print " *** $REGION execution for $SCRIPTNAME *** " >> $LOG_FILE
    else
        # Running in Prod region
        print " " >> $LOG_FILE
        print " *** $REGION execution for $SCRIPTNAME *** " >> $LOG_FILE
    fi
else
    # Running in Development region
    print " " >> $LOG_FILE
    print " *** $REGION execution for $SCRIPTNAME *** " >> $LOG_FILE
fi


#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script
#-------------------------------------------------------------------------#

print " " >> $LOG_FILE

#----------------------------------
# Create the Package to be executed
#----------------------------------

Package_Name="dma_rbate2.pk_gpo_crossover_driver.prc_gpo_crossover_driver"
PKGEXEC=$Package_Name;

#-------------------------------------------------------------------------#
# Set up the Pipe file, then build and EXEC the new SQL.               
#-------------------------------------------------------------------------#
print `date` 'Beginning Package call of ' $PKGEXEC >> $LOG_FILE

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Execute the SQL run the Package 
#-------------------------------------------------------------------------#

print ' ' >> $LOG_FILE

cat > $SQL_FILE << EOF
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
SPOOL $PKG_LOG

EXEC $PKGEXEC; 

quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE

RETCODE=$?

cat $PKG_LOG >> $LOG_FILE


if [[ $RETCODE = 0 ]]; then
   print `date` 'Completed Package call of ' $PKGEXEC >> $LOG_FILE
   print ' ' >> $LOG_FILE
fi

if [[ $RETCODE != 0 ]]; then
   print ' ' >> $LOG_FILE
   print 'Failure in Package call of ' $PKGEXEC >> $LOG_FILE
   print 'Package call RETURN CODE is : ' $RETCODE >> $LOG_FILE
   print ' ' >> $LOG_FILE
fi

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " " >> $LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $LOG_FILE
   print "  Error Executing " $SCRIPTNAME                                    >> $LOG_FILE
   print "  Look in "$LOG_FILE       >> $LOG_FILE
   print "=================================================================" >> $LOG_FILE
   
# Send the Email notification 
   export JOBNAME=$SCHEDULE/$JOB
   export SCRIPTNAME=$SCRIPTNAME
   export LOGFILE=$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $LOG_FILE
   print "JOBNAME is " $JOBNAME >> $LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME >> $LOG_FILE
   print "LOGFILE is " $LOGFILE >> $LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4 >> $LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5 >> $LOG_FILE
   print "****** end of email parameters ******" >> $LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $LOG_FILE $LOG_ARCH_FILE
   exit $RETCODE
fi

rm -f $PKG_LOG
rm -f $SQL_FILE

print "....Completed executing " $SCRIPTNAME " ...."   >> $LOG_FILE
mv -f $LOG_FILE $LOG_ARCH_FILE

exit $RETCODE

