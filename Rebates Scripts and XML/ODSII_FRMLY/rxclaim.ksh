#!/bin/ksh
###################################################################
# NAME: rxclaim.ksh - rxclaim application.
#
# DESCRIPTION:
#   1. ARGS: $1 = Domain (PC, STAGE, QAT, PROD).  Defaults based upon host.
#            
#   2. Create a file with Formulary IDs and send it to RxClaim via secure FTP server.
#   3. FORMULARY_HOME must be set to .../formulary/ directory.
#
# CHANGE LOG:
#   07/31/2006  Shyam Antari    Created.
#   06/22/2015	Hiri K		Converted FTP to SFTP and modified parameters in the sftp call
###################################################################
#set -x

cd $FORMULARY_HOME
DOMAIN=${1:-$(common/bin/getDomain.ksh)}
JAVA_DIR=/usr/java1.4/jre/bin

OUTPUT_FILE=$(common/bin/getPropertyValue.ksh $DOMAIN.OutputFile rxclaim/props/rxclaim.properties)
LOG_FILE=$(common/bin/getPropertyValue.ksh log4j.appender.logfile.File rxclaim/props/rxclaimlog4j.properties)
HOST=$(common/bin/getPropertyValue.ksh $DOMAIN.SecureFtpHost rxclaim/props/rxclaim.properties)
USERID=$(common/bin/getPropertyValue.ksh $DOMAIN.SecureFtpUserId rxclaim/props/rxclaim.properties)
PASSWORD=$(common/bin/getPropertyValue.ksh $DOMAIN.SecureFtpUserIdPasswordFor.$USERID common/props/security.properties)
FROMFILE=$OUTPUT_FILE.zip
TOFILE=$(common/bin/getPropertyValue.ksh $DOMAIN.RxclaimFile rxclaim/props/rxclaim.properties)


####  Delete old output files  ####
rm $OUTPUT_FILE
rm $LOG_FILE

####  Explode formulary info  ####
$JAVA_DIR/java -cp rxclaim/bin/rxclaim.jar:formulary/lib/formulary.jar:common/lib/common.jar:thirdparty/oracle/lib/ojdbc14.jar:thirdparty/apache/lib/log4j-1.2.7.jar\
               -DDOMAIN=$DOMAIN\
               -Xmx256m\
               com.caremark.formulary.rxclaim.Rxclaim
RETURN=$?

if [ $RETURN -ne 0 ]
then
   echo "Error in the Rxclaim.class, error = "  $RETURN
   exit $RETURN
fi


####  zip the output file; it will be sent to RxClaim/AS400 via secure FTP server     ####
####  file is zipped to detect partial file transfers at the receiving end             ####
zip $FROMFILE $OUTPUT_FILE 

common/bin/SftpFile.ksh -h$HOST\
		 -u$USERID\
		 -cput\
		 $FROMFILE $TOFILE >> $LOG_FILE
RETURN=$?

if [ $RETURN -ne 0 ]
then
   echo "Error in sending the file to secure FTP server, error = "  $RETURN
   exit $RETURN
fi


####  Archive files  ####
common/bin/archiveFile.ksh -g10 -r $FROMFILE
common/bin/archiveFile.ksh -g10 $LOG_FILE

exit $RETURN

