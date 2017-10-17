#!/bin/ksh
#set -x
#--------------------------------------------------------------------------#
#   Date                  Description
# ----------  ----------  -------------------------------------------------#
#
# 09/30/2011   qcpi08g    change IP address from 204.99.13.27 to 
#                         paz1trendvip.caremarkrx.net.
# 08-01-2010   qcpi19v    Initial Creation.
# 07-05-2013   qcpi2bc    BFFLoader changes for Aetna File Processing 
# 10/19/2016   qcpue98u   Modified variable settings to support all lower regions,
#			  and calls to process Gateway BFF Files
#--------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark GDX Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/Common_GDX_Environment.ksh

export GDX_ENV_SETTING="$(hostname -s)-$(echo $SCRIPTS_DIR | awk -F/ '{ print $3 }')"

case $GDX_ENV_SETTING in
       tstdbs1*)
	    SYSTEM="DEVELOPMENT"
	    export SMTP_HOST="paz1trendvip.caremarkrx.net"
	    export CVS_MAIL="gdxdevtest@cvscaremark.com"
	    export AETNA_SUCCESS_MAIL="gdxdevtest@cvscaremark.com"
	    export AETNA_FAILURE_MAIL="gdxdevtest@cvscaremark.com"
	    export GHP_SUCCESS_MAIL="gdxdevtest@cvscaremark.com"
	    export GHP_FAILURE_MAIL="gdxdevtest@cvscaremark.com"
	    export FROM_MAIL="bffProcess@caremark.com"
	    export CVS_MAIL_SUBJ="DEV1_CVS_GDX_BFF_LOAD_NOTIFICATION"
	    export AETNA_MAIL_SUBJ="DEV1_AETNA_GDX_BFF_LOAD_NOTIFICATION"
	    export GHP_MAIL_SUBJ="DEV1_GHP_GDX_BFF_LOAD_NOTIFICATION"
	    export JDBC_URL="jdbc:db2://TSTDBS1:50006/GDX"
	;;

       tstdbs2*)
	    SYSTEM="DEVELOPMENT"
	    export SMTP_HOST="paz1trendvip.caremarkrx.net"
	    export CVS_MAIL="gdxdevtest@cvscaremark.com"
	    export AETNA_SUCCESS_MAIL="gdxdevtest@cvscaremark.com"
	    export AETNA_FAILURE_MAIL="gdxdevtest@cvscaremark.com"
	    export GHP_SUCCESS_MAIL="gdxdevtest@cvscaremark.com"
	    export GHP_FAILURE_MAIL="gdxdevtest@cvscaremark.com"
	    export FROM_MAIL="bffProcess@caremark.com"
	    export CVS_MAIL_SUBJ="DEV2_CVS_GDX_BFF_LOAD_NOTIFICATION"
	    export AETNA_MAIL_SUBJ="DEV2_AETNA_GDX_BFF_LOAD_NOTIFICATION"
	    export GHP_MAIL_SUBJ="DEV2_GHP_GDX_BFF_LOAD_NOTIFICATION"
	    export JDBC_URL="jdbc:db2://tstdbs2:50144/GDX"
	;;

       tstdbs4*)
	    SYSTEM="QA"
	    export SMTP_HOST="paz1trendvip.caremarkrx.net"
	    export CVS_MAIL="gdxsittest@cvscaremark.com"
	    export AETNA_SUCCESS_MAIL="gdxsittest@cvscaremark.com"
	    export AETNA_FAILURE_MAIL="gdxsittest@cvscaremark.com"
            export GHP_SUCCESS_MAIL="gdxsittest@cvscaremark.com"
            export GHP_FAILURE_MAIL="gdxsittest@cvscaremark.com"
	    export FROM_MAIL="bffProcess@caremark.com"
	    export CVS_MAIL_SUBJ="SIT1_CVS_GDX_BFF_LOAD_NOTIFICATION"
	    export AETNA_MAIL_SUBJ="SIT1_AETNA_GDX_BFF_LOAD_NOTIFICATION"
	    export GHP_MAIL_SUBJ="SIT1_GHP_GDX_BFF_LOAD_NOTIFICATION"
	    export JDBC_URL="jdbc:db2://tstdbs4:50006/GDX"
	;;

       tstdbs5*)
	    SYSTEM="QA"
	    export SMTP_HOST="paz1trendvip.caremarkrx.net"
	    export CVS_MAIL="gdxsittest@cvscaremark.com"
	    export AETNA_SUCCESS_MAIL="gdxsittest@cvscaremark.com"
	    export AETNA_FAILURE_MAIL="gdxsittest@cvscaremark.com"
	    export GHP_SUCCESS_MAIL="gdxsittest@cvscaremark.com"
	    export GHP_FAILURE_MAIL="gdxsittest@cvscaremark.com"
	    export FROM_MAIL="bffProcess@caremark.com"
	    export CVS_MAIL_SUBJ="SIT2_CVS_GDX_BFF_LOAD_NOTIFICATION"
	    export AETNA_MAIL_SUBJ="SIT2_AETNA_GDX_BFF_LOAD_NOTIFICATION"
	    export GHP_MAIL_SUBJ="SIT2_GHP_GDX_BFF_LOAD_NOTIFICATION"
	    export JDBC_URL="jdbc:db2://tstdbs5:50144/GDX"
	;;

       prdrgd1*)
        SYSTEM="PRODUCTION"
        export SMTP_HOST="paz1trendvip.caremarkrx.net"
        export CVS_MAIL="ITDREBCNTRCTR@caremark.com,GDXBAS@caremark.com"
        export AETNA_FAILURE_MAIL="SETSTeam@caremark.com,AetnaBFF@aetna.com"
        export AETNA_SUCCESS_MAIL="AetnaBFF@aetna.com"
	      export GHP_SUCCESS_MAIL="GatewayBFF@gatewayhealthplan.com"
	      export GHP_FAILURE_MAIL="SETSTeam@caremark.com,GatewayBFF@gatewayhealthplan.com"
        export FROM_MAIL="bffProcess@caremark.com"
        export CVS_MAIL_SUBJ="CVS_GDX_BFF_LOAD_NOTIFICATION"
        export AETNA_MAIL_SUBJ="AETNA_GDX_BFF_LOAD_NOTIFICATION"
        export GHP_MAIL_SUBJ="GATEWAY_GDX_BFF_LOAD_NOTIFICATION"
	      export JDBC_URL="jdbc:db2://prdrgd1:50000/GDX"
	;;

    *)
        echo "Unknown GDX_ENV_SETTING [${GDX_ENV_SETTING}]" >&2
        exit 1
        ;;
esac

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


#   cp -f $LOG_FILE $LOG_FILE_ARCH
#   exit $RETCODE
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

BFF_INPUT_DIR_AET=$INPUT_PATH/CaRe_BFF/AET
BFF_INPUT_DIR_CVS=$INPUT_PATH/CaRe_BFF/CVS
BFF_INPUT_DIR_GHP=$INPUT_PATH/CaRe_BFF/GHP


function processDirectory {

BFF_INPUT_DIR=$1

if [[ $BFF_INPUT_DIR = *AET ]]; then

VM_ARGS=" -server -Xms512m -Xmx1g -Dlog4j.configuration=bffLog4j.xml -DJDBC_URL=$JDBC_URL -DbffDir=$BFF_INPUT_DIR -DbffFileType=AET -Dlog.dir=$LOG_PATH -Dsuccess.mail=$AETNA_SUCCESS_MAIL            
-Dfailure.mail=$AETNA_FAILURE_MAIL -Dfrom.mail=$FROM_MAIL -Dsmtp.host=$SMTP_HOST -Dmail.subject=$AETNA_MAIL_SUBJ -DGDX_UID=$CONNECT_ID -DGDX_PASS=$CONNECT_PWD -DbffErrDir=$BFF_INPUT_DIR/error       
-DbffArchDir=$BFF_INPUT_DIR/archive "
JAVA_HOME="/usr/java6_64"

elif [[ $BFF_INPUT_DIR = *GHP ]]; then


VM_ARGS=" -server -Xms512m -Xmx1g -Dlog4j.configuration=bffLog4j.xml -DJDBC_URL=$JDBC_URL -DbffDir=$BFF_INPUT_DIR -DbffFileType=GHP -Dlog.dir=$LOG_PATH -Dsuccess.mail=$GHP_SUCCESS_MAIL            -Dfailure.mail=$GHP_FAILURE_MAIL -Dfrom.mail=$FROM_MAIL -Dsmtp.host=$SMTP_HOST -Dmail.subject=$GHP_MAIL_SUBJ -DGDX_UID=$CONNECT_ID -DGDX_PASS=$CONNECT_PWD -DbffErrDir=$BFF_INPUT_DIR/error       -DbffArchDir=$BFF_INPUT_DIR/archive "
JAVA_HOME="/usr/java6_64"

else 

VM_ARGS=" -server -Xms512m -Xmx1g -Dlog4j.configuration=bffLog4j.xml -DJDBC_URL=$JDBC_URL -DbffDir=$BFF_INPUT_DIR -DbffFileType=CVS -Dlog.dir=$LOG_PATH -Dto.mail=$CVS_MAIL 
-Dfrom.mail=$FROM_MAIL
-Dsmtp.host=$SMTP_HOST -Dmail.subject=$CVS_MAIL_SUBJ -DGDX_UID=$CONNECT_ID -DGDX_PASS=$CONNECT_PWD -DbffErrDir=$BFF_INPUT_DIR/error -DbffArchDir=$BFF_INPUT_DIR/archive "
JAVA_HOME="/usr/java6_64"

fi

echo $VM_ARGS
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

echo "CLASSPATH"
echo $CLASSPATH

#export CLASSPATH=/GDX/test/java/lib/cash_bff_load.jar:$CLASSPATH


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

		
   fi


}

processDirectory $BFF_INPUT_DIR_AET
processDirectory $BFF_INPUT_DIR_CVS
processDirectory $BFF_INPUT_DIR_GHP




