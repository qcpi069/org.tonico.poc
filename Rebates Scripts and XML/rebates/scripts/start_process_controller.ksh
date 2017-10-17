#!/bin/ksh
#set -x
#--------------------------------------------------------------------------#
#   Date                 Description
# ----------  ----------  -------------------------------------------------#
# 04-15-2010   qcpi08a     add input parameter for PRCS_APPL_ID: RCI or CASH
# 04-01-2009   qcpu70x     Initial Creation.
# 07-30-2013   qcpi2d6     Removed all hardcodes and pull variables from environment scripts
#--------------------------------------------------------------------------#

# Figure out what environment we are in using:
# 1. The host name
# 2. The directory where the script that called this resides.


. `dirname $0`/Common_RCI_Environment.ksh

        export FROM_MAIL="vactuate@dwhtest1.psd.caremark.int"
        export MAIL_SUBJECT="FAILURE:BATCH_PROCESS_ERROR_IN_"$REGION


#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

function exit_error {
   RETCODE=$1
   ERROR=$2
   EMAIL_SUBJECT=$SCRIPTNAME" Abended In "$REGION" "`date`

   if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
   fi

   {
        print " "
        print $ERROR
        print " "
        print " !!! Aborting !!!"
        print " "
        print "return_code = " $RETCODE
        print " "
        print " ------ Ending script " $SCRIPT `date`
   }    >> $LOG_FILE

   mailx -s "$EMAIL_SUBJECT" $TO_MAIL                        < $LOG_FILE
   cp -f $LOG_FILE $LOG_FILE_ARCH
 print "exit Error :$RETCODE"
  exit $RETCODE
}

#------------------------------------------------------------------------#
# Variables
#-------------------------------------------------------------------------#

RETCODE=0

SCRIPTNAME=$(basename "$0")
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
LOG_FILE=$LOG_DIR/$FILE_BASE".log"
LOG_FILE_ARCH=$ARCH_LOG_DIR/$FILE_BASE".log."`date +"%Y%j%H%M"`

rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the start time.
#-------------------------------------------------------------------------#

   print " ------ Script Started " `date`
   print " ------ Script Started " `date` > $LOG_FILE

#------------------------------------------------------------------------#
# Checking input parameter
#------------------------------------------------------------------------#

print " input parameter was: " $1
print " "                           >> $LOG_FILE
print " input parameter was: " $1   >> $LOG_FILE

if [[ $# -ne 1 ]]; then
        print "Usage: $0 <RCI or CASH>"
        RETCODE=99
        export ERROR=" Usage: $0 <RCI or CASH>"
        exit_error $RETCODE "$ERROR"
fi

PRCS_APPL_ID=$(echo $1 | tr '[a-z]' '[A-Z]')
print " PRCS_APPL_ID is: "$PRCS_APPL_ID                 >> $LOG_FILE

#------------------------------------------------------------------------#
# Complete scripts part and start java part
#------------------------------------------------------------------------#
{
    print
    print
    print "....Completed executing $SCRIPTNAME and start java process controller ...."
    date +"%D %r %Z"

} >> $LOG_FILE

mv -f $LOG_FILE $LOG_FILE_ARCH


export VM_PARAMS="$JDBCURL -DRCI_SCRIPT_DIR=$RCI_SCRIPT_DIR -DRCI_LIB_HOME=$RCI_LIB_HOME -DPMCMD_SCRIPT=$PMCMD_SCRIPT -Dlog.dir=$LOG_DIR -Dto.mail=$TO_MAIL -Dfrom.mail=$FROM_MAIL -Dsmtp.host=$SMTP_HOST -Dmail.subject=$MAIL_SUBJECT"

echo "VM_PARAMS are"
echo $VM_PARAMS

CLASSPATH=$JAVA_HOME/lib:$CLASSPATH
CLASSPATH=$LIB_PATH/log4j-1.2.14.jar:$LIB_PATH/processcontroller.jar:$LIB_PATH/spring.jar:$LIB_PATH/commons-logging-1.1.1.jar:$CLASSPATH
CLASSPATH=$LIB_PATH/quartz-all-1.6.1-RC1.jar:$LIB_PATH/commons-collections-3.2.jar:$LIB_PATH/hibernate3.jar:$LIB_PATH/dom4j-1.6.1.jar:$CLASSPATH
CLASSPATH=$LIB_PATH/slf4j-api-1.5.2.jar:$LIB_PATH/slf4j-log4j12-1.5.0.jar:$LIB_PATH/commons-dbcp-1.2.2.jar:$LIB_PATH/commons-pool-1.3.jar:$LIB_PATH/cglib-2.1.3.jar:$CLASSPATH
CLASSPATH=$LIB_PATH/asm.jar:$LIB_PATH/jta.jar:$LIB_PATH/mail.jar:$LIB_PATH/db2jcc.jar:$LIB_PATH/activation.jar:$LIB_PATH/antlr-2.7.6.jar:$LIB_PATH/db2jcc_license_cu.jar:$CLASSPATH
export CLASSPATH


java $VM_PARAMS com.caremark.controller.process.StartController  $CONFIG_DIR $REGION $PRCS_APPL_ID

return $?
