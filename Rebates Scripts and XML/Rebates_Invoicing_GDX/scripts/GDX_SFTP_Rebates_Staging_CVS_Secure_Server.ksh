#!/usr/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_SFTP_Rebates_Staging_CVS_Secure_Server.ksh
# Title         : Secure File Transfer from Rebate Staging Server to
#                  CVS/Caremark Secure File Transport Server
#
# Description   : This script will run periodically and pick up all files from
#                  Rebate Staging Server with specific directories and the push
#                  them to the corresponding directories on the CVS/Caremark
#                  Secure File Transport Server.
#
# Note          : This script is executed from a unix cron job and the frequency is 2 hours.
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date     Author      Description
# ---------  ----------  -------------------------------------------------#
# 01-27-2017 qcpvg80a    Modified to support Gateway file transfers 
#			 is compressed already otherwise compress and archive
# 04-03-2014 qcpi733     Added call to Common_GDX_Environment script because
#                        the GDX_ENV_SETTING logic used to be duplicated
#                        inside the Common_SFTP_Environment.  
# 05-01-2013 QCPI0V5     Added Logic to replace & with _ for TargetFileName
# 01-24-2012 QCPUE98U    Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
CORP=$1

. `dirname $0`/Common_GDX_Environment.ksh
. `dirname $0`/Common_SFTP_Environment.ksh $CORP 

#-------------------------------------------------------------------------#

FILE_BASE="GDX_SFTP_Rebates_Staging_CVS_Secure_Server"
SCRIPTNAME=$FILE_BASE".ksh"
FTP_CMD_FILE=$OUT_PATH"/"$CORP"_"$FILE_BASE"_ftpcmds.txt"
MVE_CMD_FILE=$OUT_PATH"/"$CORP"_"$FILE_BASE"_mvecmds.txt"
LOG_FILE="$LOG_PATH/$CORP"_"$FILE_BASE.log"
LOG_FILE_ARCH="$LOG_PATH/archive/$CORP"_"$FILE_BASE.log.`date +"%Y%m%d%H%M%S"`"
export SFTP_USER="rebates_sftp"

RETCODE=0

if [[ $REGION = prod &&  $QA_REGION = FALSE ]]
then
   export SFTP_SERVER="webtransport.caremark.com"
else
   export SFTP_SERVER="tstwebtransport.caremark.com"
fi

#-------------------------------------------------------------------------#
# Function to check the file size for before File Transfer.
#-------------------------------------------------------------------------#
function CheckFileSize {
     CheckDir=$1
     RET_STATUS=0


find $CheckDir  -name '* *' | while read file;
do
target=`echo "$file" | sed 's/ /_/g'`;
echo "Renaming '$file' to '$target'";
mv "$file" "$target";
done;

     FileCNT=`ls -p $CheckDir | grep -v / | wc -l`

if [ $FileCNT == 0 ]
    then
      print " ZERO Files Available for Size Check -- $FileCNT" >> $LOG_FILE
      FileCNT_status=1
    # echo $FileCNT
    else
      FileCNT_status=0
    fi




    for FleNme in `ls -p $CheckDir | grep -v /`
     do
        FileSizeOld=`ls -la $CheckDir/$FleNme | awk '{print $5}'`

        while [ $RET_STATUS -eq 0 ]
         do
             FileSizeNew=`ls -la $CheckDir/$FleNme | awk '{print $5}'`

             if [ $FileSizeOld -ne $FileSizeNew ]
             then
                  print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
                  print `date` " File Size is changing and File Name : " $CheckDir/$FleNme " "         >> $LOG_FILE
                  print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
                  sleep 10
             else
                  RET_STATUS=1
             fi
         done
     done


     print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
     print `date` " Check File Size for " $CheckDir " is Successful     "                 >> $LOG_FILE
     print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
     return $RET_STATUS
}

function GenFTP_ARCH {

     FileSourceDir=$1
     FileRemoteDir=$2
     FileArchivDir=$3

    rm -f $FileSourceDir/*.ok

  if [ $FileCNT_status == 0 ]
  then

     print "cd " $FileRemoteDir      >> $FTP_CMD_FILE
     print "cd " $FileSourceDir      >> $MVE_CMD_FILE

    for FileName in `ls -p $FileSourceDir | grep -v /`
    do
    TgtFileName=`echo "${FileName}" | sed  's/\&/_/g'`

        touch $FileSourceDir/${FileName}.ok

        print "put " ${FileSourceDir}"/"${FileName} ${TgtFileName} >> $FTP_CMD_FILE
        print "put " ${FileSourceDir}"/"${FileName}".ok" ${TgtFileName}".ok" >> $FTP_CMD_FILE

        extension=$(echo ${FileName}|awk -F\. '{print $4}')
           if [ ${extension} == "gz" ]; then

                print "mv " ${FileSourceDir}"/"${FileName}  ${FileArchivDir}/${FileName}".`date +"%Y%m%d%H%M%S"`">> $MVE_CMD_FILE
           else
                print "gzip " ${FileName} >> $MVE_CMD_FILE
                print "mv " ${FileSourceDir}"/"${FileName}."gz"  "${FileArchivDir}/${FileName}."`date +"%Y%m%d%H%M%S"`".gz">> $MVE_CMD_FILE
           fi

 find $FileArchivDir  -ctime +2 -type f -print | xargs -I '{}' rm {}

    done
   else
      print "ZERO Files available to genereate the FTP and Archive commands" >> $LOG_FILE
   fi

 print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
 print `date` " Generating SFTP and Archive command File for -- ["$FileSourceDir"] "  >> $LOG_FILE
 print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
}


function ARCH_FILES {

print " "                                                                            >> $LOG_FILE
print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
print `date` "ARCHIVE PROCESS IN REBATES STAGING SERVER                           "  >> $LOG_FILE
print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
print " "                                                                            >> $LOG_FILE


cat $MVE_CMD_FILE >> $LOG_FILE
cat $MVE_CMD_FILE | while read CMD_LINE
do
    $CMD_LINE
    CMD_RET_CODE=$?

    if [ $CMD_RET_CODE != 0 ]
    then
        echo "UNIX COMMAND [$CMD_LINE] & ERROR CODE [$CMD_RET_CODE] IS FAILED\n" >> $LOG_FILE
        exit $CMD_RET_CODE
    fi

   if [ $CMD_RET_CODE == 0 ]
    then
        echo "FILE ARCHIVE Successful\n" >> $LOG_FILE
    fi
done
mv $LOG_FILE $LOG_FILE_ARCH
}

rm -f $LOG_FILE

print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
print `date` " Started executing " $SCRIPTNAME " "                                   >> $LOG_FILE
print "#-------------------------------------------------------------------------#"  >> $LOG_FILE


>$FTP_CMD_FILE
>$MVE_CMD_FILE


print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
print `date` " Checking File Size and Generating SFTP and ARCHIVE Command File "     >> $LOG_FILE
print "#-------------------------------------------------------------------------#"  >> $LOG_FILE

case $CORP in

AETNA)

CheckFileSize $PLN_SP_STG
GenFTP_ARCH $PLN_SP_STG $PLN_SP_DEST $PLN_SP_ARCH

CheckFileSize $MAN_NCPDP_STG
GenFTP_ARCH $MAN_NCPDP_STG $MAN_NCPDP_DEST $MAN_NCPDP_ARCH

CheckFileSize $MAN_REB_STG
GenFTP_ARCH $MAN_REB_STG $MAN_REB_DEST $MAN_REB_ARCH

CheckFileSize $BUS_RPT_STG
GenFTP_ARCH $BUS_RPT_STG $BUS_RPT_DEST $BUS_RPT_ARCH

CheckFileSize $INV_RPT_STG
GenFTP_ARCH $INV_RPT_STG $INV_RPT_DEST $INV_RPT_ARCH

CheckFileSize $STD_RPT_STG
GenFTP_ARCH $STD_RPT_STG $STD_RPT_DEST $STD_RPT_ARCH

CheckFileSize $IEX_RPT_STG
GenFTP_ARCH $IEX_RPT_STG $IEX_RPT_DEST $IEX_RPT_ARCH
;;

GHP)

CheckFileSize $GHP_RPT_STG
GenFTP_ARCH $GHP_RPT_STG $GHP_RPT_DEST $GHP_RPT_ARCH
;;

esac

print "quit" >> $FTP_CMD_FILE

print " "                                                                            >> $LOG_FILE
print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
print `date` "INVOICED CLAIMS SFTP COMMANDS                                       "  >> $LOG_FILE
print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
print " "                                                                            >> $LOG_FILE

cat $FTP_CMD_FILE >> $LOG_FILE

print " "                                                                            >> $LOG_FILE
print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
print `date` "SFTP-ing Rebates Staging Server to CVS/Caremark Secure FTP Server"     >> $LOG_FILE
print "#-------------------------------------------------------------------------#"  >> $LOG_FILE
print " "                                                                            >> $LOG_FILE


        sftp -b $FTP_CMD_FILE $SFTP_USER@$SFTP_SERVER >> $LOG_FILE
        SFTP_RET_CODE=$?

        echo "SFTP RETURN CODE [$SFTP_RET_CODE]" >> $LOG_FILE
        if [ $SFTP_RET_CODE == 0 ]
        then
           echo "File Transfer is Successful\n" >> $LOG_FILE
            ARCH_FILES
        else
            echo "File Transfer is Failed And Error Code [$SFTP_RET_CODE]\n" >> $LOG_FILE
            echo "Aborting File Archive, since SFTP failed \n" >> $LOG_FILE
            exit $SFTP_RET_CODE
        fi
        
