#!/bin/ksh
#set -x
#--------------------------------------------------------------------------#
#   Date                  Description
# ----------  ----------  -------------------------------------------------#
#
# 09/30/2011   qcoi08g    Change the IP address from 204.99.13.27 to
#                         paz1trendvip.caremarkrx.net.
# 08-01-2009   qcpi08a    Initial Creation.
#
#--------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark GDX Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/Common_GDX_Environment.ksh

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        SYSTEM="UAT"
	export SMTP_HOST="paz1trendvip.caremarkrx.net"
	export TO_MAIL="ITDREBCNTRCTR@caremark.com"
        export TO_MAIL_SUCC="$TO_MAIL"
	export FROM_MAIL="APCToSAP@caremark.com"
    else
        # Running in Prod region
        SYSTEM="PRD"
        export SMTP_HOST="paz1trendvip.caremarkrx.net"
        export TO_MAIL="ITDREBCNTRCTR@caremark.com"
        export TO_MAIL_SUCC="$TO_MAIL" 
        export FROM_MAIL="APCToSAP@caremark.com"
    fi
else
    # Running in Development region
    SYSTEM="DEV"
    export SMTP_HOST="paz1trendvip.caremarkrx.net"
    export TO_MAIL="yanping.zhao@caremark.com"
    export TO_MAIL_SUCC="yanping.zhao@caremark.com, $TO_MAIL" 
    export FROM_MAIL="APCToSAP@caremark.com"
fi

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

function exit_error {
   RETCODE=$1
   ERROR=$2
   #EMAIL_SUBJECT=$FILE_BASE" Abended In "$SYSTEM
   EMAIL_SUBJECT="APC_to_SAP Abended In "$SYSTEM

   if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
   fi

   {
        print " "
   	print $ERROR                                              
   	print " "                                                
   	print "	!!! Aborting !!!" 
        print " "
   	print "return_code = " $RETCODE
        print " "
   }    >> $LOG_FILE

   print " ------ Ending script " $SCRIPT `date` >> $LOG_FILE

#   mailx -s "$EMAIL_SUBJECT" $TO_MAIL                        < $LOG_FILE
   cp -f $LOG_FILE $LOG_FILE_ARCH 
   exit $RETCODE
}

#-------------------------------------------------------------------------#
# Variables
#-------------------------------------------------------------------------#

cd $SCRIPT_PATH

RETCODE=0
SCRIPTNAME=$(basename "$0")
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
LOG_FILE=$LOG_PATH/$FILE_BASE".log"
LOG_FILE_ARCH=$LOG_ARCH_PATH/$FILE_BASE".log."`date +"%Y%j%H%M"`
EMAIL_SUBJECT="APC_TO_SAP_Error_In_"$SYSTEM
CONFIG_PATH=/$GDX_PATH/java/conf
CONFIG_FILE=/$CONFIG_PATH/APCToSAPLog4j.xml
MOD_LIB_PATH="$GDX_PATH/java/lib/mod_lib"

rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the start time.
#-------------------------------------------------------------------------#

   print " ------ Script Started " `date` 
   print " ------ Script " $SCRIPTNAME " Started " `date`   > $LOG_FILE

#------------------------------------------------------------------------#
# Complete scripts part and start java part 
#------------------------------------------------------------------------#
{
    print
    print
    print "...... Start Java Process ......" `date`

} >> $LOG_FILE

#-------------------------------------------------------------------------#
# Set Java Environment
#-------------------------------------------------------------------------#

CLASSPATH=
for j in `ls $MOD_LIB_PATH/*.jar`
do
  CLASSPATH=$j:$CLASSPATH
done

export CLASSPATH=/appl/sap/application/sapjco.jar:$CLASSPATH
export LIBPATH=/appl/sap/application:$LIBPATH

   #JAVA_HOME="/usr/java6_64"
   JAVA_HOME="/usr/java5"
   JAVACMD=$JAVA_HOME/bin/java
   print "----------------------------------------------------------------"    >>$LOG_FILE
   print "$($JAVACMD -version 2>&1)"                                           >>$LOG_FILE
   print "----------------------------------------------------------------"    >>$LOG_FILE

#-------------------------------------------------------------------------#
# Call the Java Process
#-------------------------------------------------------------------------#

   export VM_PARAMS="-Dlog4j.configuration=${CONFIG_FILE} -DlogFile=${LOG_FILE} -Dto.mail=$TO_MAIL -Dfrom.mail=$FROM_MAIL -Dsmtp.host=$SMTP_HOST -Dmail.subject=$EMAIL_SUBJECT -DCONFIG_DIR=$CONFIG_PATH"

   print "$JAVACMD" $VM_PARAMS com.caremark.cash.apctosap.main.APCToSAPMain $CONFIG_PATH $SYSTEM >>$LOG_FILE

   "$JAVACMD" -classpath $CLASSPATH $VM_PARAMS com.caremark.cash.apctosap.main.APCToSAPMain $CONFIG_PATH $SYSTEM >> $LOG_FILE

#-------------------------------------------------------------------------#
# Move the log file to archive.
#-------------------------------------------------------------------------#
   {
      print " "
      print " "
      print "...... End Java Process ......" `date`
      print " "
      print " "
      print " "
      print "return_code = " $RETCODE
      print "  ------ Scripts $SCRIPTNAME completed "`date`
   }  >> $LOG_FILE

   mv -f $LOG_FILE $LOG_FILE_ARCH

exit $RETCODE

