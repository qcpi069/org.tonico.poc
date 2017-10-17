#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_DrugClass_MDDY1001_MD_1001J_load_and_report_counts_cls_xmd.ksh   
# Title         : XMD Drug class import process
#
# Description   : Loads XMD drug class data file from QL mainframe into the staging 
#                 table VRAP.TWORK_DRUG_CLS_XMD.
#                 Sends an email to the users with counts in the XMD drug class control report 
#                 from QL mainframe and counts from table VRAP.TWORK_DRUG_CLS_XMD.
#          
#
# Parameters    : None
#                 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ----------  ----------  -------------------------------------------------#
# 01-03-2006  J. Parsin   Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark GDX Application Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/Common_GDX_Environment.ksh


#the variables are exported because called script GDX_DrugClass_load_and_report_counts.ksh 
#needs this variables.
export SCHEDULE="GDDY1001"
export JOB="GD_1001J"
export SUBDIR="DrugClass"
export SUBSYSTEM="GDX_"$SUBDIR"_"
export MODEL="xmd"
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

