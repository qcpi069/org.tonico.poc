#!/bin/ksh
#set -x
#--------------------------------------------------------------------------#
#   Date                  Description
# ----------  ----------  -------------------------------------------------#
#
# 08-01-2010   qcpi19v    Initial Creation.
#
#--------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark GDX Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/Common_GDX_Environment.ksh

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        SYSTEM="QA"
        export SMTP_HOST="204.99.13.27"
        export TO_MAIL="ITDREBCNTRCTR@caremark.com"
        
        export FROM_MAIL="bffProcess@caremark.com"
        export MAIL_SUBJ="QAA BFF LOAD"
        export JDBC_URL="jdbc:db2://tstdbs4:50006/GDX"
    else
        # Running in Prod region
        SYSTEM="PRODUCTION"
        export SMTP_HOST="204.99.13.27"
        export TO_MAIL="ITDREBCNTRCTR@caremark.com"
       
        export FROM_MAIL="bffProcess@caremark.com"
    	export MAIL_SUBJ="PROD BFF LOAD"
        export JDBC_URL="jdbc:db2://r07prd01:50000/GDXPRD"
    fi
else
    # Running in Development region
    SYSTEM="DEVELOPMENT"
    export SMTP_HOST="204.99.13.27"
    export TO_MAIL="mark.sabor@caremark.com,vidya.vemula@caremark.com -Dfrom.mail=bffProcess@caremark.com"
    
    export FROM_MAIL="bffProcess@caremark.com"
    export MAIL_SUBJ="DEV BFF LOAD"
    export JDBC_URL="jdbc:db2://TSTUDB4:50006/GDXDEV"
fi

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

function exit_error {
   RETCODE=$1
   ERROR=$2
   EMAIL_SUBJECT=

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

rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the start time.
#-------------------------------------------------------------------------#

   print " ------ Script Started " `date`
   print " ------ Script Started " `date`   > $LOG_FILE

BFF_INPUT_DIR=$INPUT_PATH/CaRe_BFF
VM_ARGS=" -server -Xms512m -Xmx1g -Dlog4j.configuration=bffLog4j.xml -DJDBC_URL=$JDBC_URL -DbffDir=$BFF_INPUT_DIR -Dlog.dir=$LOG_PATH -Dto.mail=$TO_MAIL -Dfrom.mail=$FROM_MAIL -Dsmtp.host=$SMTP_HOST -Dmail.subject=TEST_BFF_LOAD "
JAVA_HOME="/usr/java6_64"
BFF_LIB_DIR="$GDX_PATH/java/lib/mod_lib"
DATA_FILES=`ls $BFF_INPUT_DIR|egrep ".TRG$`
#DATA_FILES=`ls $BFF_INPUT_DIR/*.TRG`
INPUT_DAT_FILES=

echo "DATA FILES"
echo $DATA_FILES

CLASSPATH=

for j in `ls $BFF_LIB_DIR/*.jar`
do
  CLASSPATH=$j:$CLASSPATH
done

#export CLASSPATH=/GDX/test/java/lib/cash_bff_load.jar:$CLASSPATH

echo "CLASSPATH"
echo $CLASSPATH

for i in $DATA_FILES
do
  INPUT_DAT_FILES=`echo $i|awk -F. '{print $1".DAT "}'`$INPUT_DAT_FILES
done

echo "INPUT FILES"
echo $INPUT_DAT_FILES
$JAVA_HOME/bin/java -classpath $CLASSPATH $VM_ARGS com.cvs.caremark.rebates.cash.bff.BffLoader $INPUT_DAT_FILES

export RETCODE=$?
#-------------------------------------------------------------------------#
# Check if Java process will fail, java will send email for error.
# If successful, send email from Unix
#-------------------------------------------------------------------------#

   if [[ $RETCODE != 0 ]]; then
      print                                                  >> $LOG_FILE
      print                                                  >> $LOG_FILE
      print "   ------ ERROR: Java code fail ..."            >> $LOG_FILE
      print "JAVA return code is : <" $RETCODE ">"           >> $LOG_FILE
      exit_error $RETCODE
   else
      print                                                  >> $LOG_FILE
      print "...... End Java Process ......"  `date`         >> $LOG_FILE

      print "Moving file to archive" >> $LOG_FILE
		for dat in $DATA_FILES
		do
    		mv $BFF_INPUT_DIR/$dat $BFF_INPUT_DIR/archive
		done

		for trg in $INPUT_DAT_FILES
		do
 			 mv $BFF_INPUT_DIR/$trg $BFF_INPUT_DIR/archive
		done
   fi



