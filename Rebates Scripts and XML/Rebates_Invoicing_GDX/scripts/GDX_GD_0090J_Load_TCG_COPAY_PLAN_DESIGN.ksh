#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GD_0090J_Load_TCG_COPAY_PLAN_DESIGN.ksh
# Title         : vrap.TRECAP_CG_COPAY_PLAN_DESIGN import process
#
# Description   : Loads vrap.TRECAP_CG_COPAY_PLAN_DESIGN from MVS Eclipse file GDX_ECLIPSE_CG_COPAY_PLAN_DESIGN.dat     
#
# Parameters    : None. 
#  
# Input         : GDX_ECLIPSE_CG_COPAY_PLAN_DESIGN.dat
# 
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-13-2008  K. Gries    Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/Common_GDX_Environment.ksh

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
    }                                                                          >> $LOG_FILE

    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...."                                     >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
    exit $RETCODE
}


if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        SYSTEM="QA"
        export ALTER_EMAIL_TO_ADDY=""
        EMAIL_FROM_ADDY="GDXITD@caremark.com"
        EMAIL_TO_ADDY="GDXITD@caremark.com"
    else
        # Running in Prod region
        SYSTEM="PRODUCTION"
        export ALTER_EMAIL_TO_ADDY=""
        EMAIL_FROM_ADDY="GDXITD@caremark.com"
        EMAIL_TO_ADDY="GDXITD@caremark.com"
    fi
else
    # Running in Development region
    SYSTEM="DEVELOPMENT"
    export ALTER_EMAIL_TO_ADDY="nick.tucker@caremark.com"
    EMAIL_FROM_ADDY=$ALTER_EMAIL_TO_ADDY
fi


FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
SCRIPTNAME=$FILE_BASE".ksh"

LOG_FILE="$LOG_PATH/$FILE_BASE.log"

rm -f $LOG_FILE

print "Starting " $SCRIPTNAME                    >> $LOG_FILE

prcs_id=$(. $SCRIPT_PATH/Common_Prcs_Log_Message.ksh "$0" "VRAP.TRECAP_CG_COPAY_PLAN_DESIGN table load" "Starting $SCRIPT_PATH/$SCRIPTNAME UDB Load of VRAP.TRECAP_CG_COPAY_PLAN_DESIGN table ") 
if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi

DAT_FILE="$INPUT_PATH/GDX_ECLIPSE_CG_COPAY_PLAN_DESIGN.dat"
TRIGGER_FILE="$INPUT_PATH/GDX_ECLIPSE_CG_COPAY_PLAN_DESIGN.trigger"

ARCH_FILE=$INPUT_PATH/GDX_ECLIPSE_CG_COPAY_PLAN_DESIGN.old.`date +"%Y%j%H%M"`

print ".............Starting script $SCRIPTNAME........  "     >> $LOG_FILE
print "  "     >> $LOG_FILE
print "Copying  $DAT_FILE to $ARCH_FILE  "     >> $LOG_FILE
cp $DAT_file $ARCH_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "  "     >> $LOG_FILE
   print "..The copy failed continuing to load" >> $LOG_FILE
   print "  "     >> $LOG_FILE
fi   


rm -f $TRIGGER_FILE

#################################################################################
#
# 1.  Check for File Existance 
#
#################################################################################


if [[ ! -s $DAT_FILE ]]; then         # is $myfile a regular file?
  print "Something wrong with/or missing input file $DAT_FILE  "     >> $LOG_FILE
   . $SCRIPT_PATH/Common_Prcs_Error_Message.ksh "$prcs_id" "Something wrong with/or missing input file $DAT_FILE "
     if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
  RETCODE=1
  exit_error $RETCODE
fi
  
#################################################################################
#
# ?.  empty the database table 
#
#################################################################################

SQL_STRING="import from /dev/null of del replace into VRAP.TRECAP_CG_COPAY_PLAN_DESIGN "

print $SQL_STRING  >> $LOG_FILE 
db2 -stvxw $SQL_STRING >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Script " $SCRIPTNAME "failed in the VRAP.TRECAP_CG_COPAY_PLAN_DESIGN EMPTY step." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">" >> $LOG_FILE
   . $SCRIPT_PATH/Common_Prcs_Error_Message.ksh "$prcs_id" "$SCRIPTNAME  failed in the VRAP.TRECAP_CG_COPAY_PLAN_DESIGN EMPTY step.  The DB2 return code is : $RETCODE "
   if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
   exit_error $RETCODE
fi 
  
#################################################################################
#
# ?.  Set up the SQL and Connect to the Database 
#
#################################################################################

SQL_STRING="import from $DAT_FILE of del modified by coldel, usedefaults commitcount 1000 warningcount 1 replace into VRAP.TRECAP_CG_COPAY_PLAN_DESIGN "

###################################################################################
#
# Import GDX_ECLIPSE_CG_COPAY_PLAN_DESIGN data with replace option into table 
# VRAP.TRECAP_CG_COPAY_PLAN_DESIGN
#
#    NOTE:  Please note there is not SQL connect step.  The calls to the common process
#           logging establishes the DB2 connection for this process.  
#
###################################################################################

print $SQL_STRING  >> $LOG_FILE 
db2 -p $SQL_STRING >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Script " $SCRIPTNAME "failed in the VRAP.TRECAP_CG_COPAY_PLAN_DESIGN import step." >> $LOG_FILE
   cp -f $LOG_FILE $LOG_ARCH_PATH/$FILE_BASE.log.`date +"%Y%j%H%M"`
   print "DB2 return code is : <" $RETCODE ">" >> $LOG_FILE
   . $SCRIPT_PATH/Common_Prcs_Error_Message.ksh "$prcs_id" "$SCRIPTNAME  failed in the VRAP.TRECAP_CG_COPAY_PLAN_DESIGN import step.  The DB2 return code is : $RETCODE "
   if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi
   exit_error $RETCODE
fi   

. $SCRIPT_PATH/Common_Prcs_End_Message.ksh "$prcs_id" ""
if [[ $? != 0 ]]; then echo "Error: $LINENO"; exit 1; fi


rm -f $DAT_FILE

print "....Completed executing " $SCRIPTNAME " ...."   >> $LOG_FILE

mv -f $LOG_FILE $LOG_ARCH_PATH/$FILE_BASE.log.`date +"%Y%j%H%M"`

exit $RETCODE
