#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_DrugClass_MDDY1001_MD_1001J_load_and_report_counts.ksh   
# Title         : <MOD> (MOD = GPO or XMD or AET, based on the parameter) Drug class import process
#
# Description   : Loads <MOD> drug class data file from QL mainframe into the staging 
#                 table VRAP.TWORK_DRUG_CLS_<MOD>.
#                 Sends an email to the users with counts in the <MOD> drug class control report 
#                 from QL mainframe and counts from table VRAP.TWORK_DRUG_CLS_<MOD>.
#          
#
# Parameters    : model_name: gpo, xmd or aet
#                 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-05-2005  S. Antari   Initial Creation.
# 08-13-2012  As. Venkat  Modified script to expect model as parameter.
#                         Same script will be scheduled with different model parameters
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark GDX Application Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/Common_GDX_Environment.ksh

if [[ $# != 1 ]] then
    echo "Usage GDX_DrugClass_MDDY1001_MD_1001J_load_and_report_counts.ksh <model name>"
    exit 1
fi

#the variables are exported because called script GDX_DrugClass_load_and_report_counts.ksh 
#needs this variables.
export SCHEDULE="GDDY1001"
export JOB="GD_1001J"
export SUBDIR="DrugClass"
export SUBSYSTEM="GDX_"$SUBDIR"_"
export MODEL=$(echo $1 |dd conv=lcase 2>/dev/null)
export FILE_BASE=$SUBSYSTEM$SCHEDULE"_"$JOB"_""load_and_report_counts_"$MODEL

###########################################################################
# This script call create the following common named variable:
#            SCRIPTNAME
#            LOG_FILE
#            LOG_FILE_ARCH
#            OUTPUT_FILE
#            SQL_FILE_NAME
###########################################################################
. $SCRIPT_PATH/Common_GDX_Env_File_Names.ksh

print "Starting " $SCRIPTNAME  >> $LOG_FILE
print `date` >> $LOG_FILE

###########################################################################
# This script call will load the drug class data into the staging table 
# and sends an email to the users with counts from the staging table 
# and control file for the specific model based on the MODEL variable.
###########################################################################
. $SCRIPT_PATH/GDX_DrugClass_load_and_report_counts.ksh 

RETCODE=$?

if [[ $RETCODE != 0  ]]; then
   
# Send the Email notification
   ##No need to set JOBNAME & SCRIPTNAME email script can figure it out. 
   ##JOBNAME=$SCHEDULE/$JOB
   ##SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
   ##LOG_FILE is assigned above

   EMAILPARM4="  "
   EMAILPARM5="  "
   
   . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh
   cp -f $LOG_FILE $LOG_FILE_ARCH.$TIME_STAMP
   exit $RETCODE
fi

print `date` >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."   >> $LOG_FILE
mv -f $LOG_FILE $LOG_FILE_ARCH.$TIME_STAMP

exit $RETCODE


