#!/usr/bin/ksh

echo "File is getting transferred to chetser...."

HOME_DIR="/vradfo/prod"

THIS_TIMESTAMP="T`date +"%Y%m%d%H%M%S"`"
THIS_PROCESS_NO="_P$$"

TEMP_DIR="$HOME_DIR/temp/$THIS_TIMESTAMP$THIS_PROCESS_NO"
TEMP_DIR="$HOME_DIR/temp/T20020408131711_P37862"
mkdir -p $TEMP_DIR

REF_DIR="$HOME_DIR/control/reffile"
CHESTER_PASSWORD_FILE="$REF_DIR/chester_password.ref"

THIS_DIR="$PWD"
cd $TEMP_DIR

FTP_LOG=$TEMP_DIR/ftp.log 
FTP_ERROR_LOG=$TEMP_DIR/ftp_error.log

CHESTER_USER="vraadmin"
CHESTER_PASSWORD=`cat $CHESTER_PASSWORD_FILE`

ftp -n 141.2.1.167 <<-DELIM >$FTP_LOG 2>$FTP_ERROR_LOG
   user $CHESTER_USER $CHESTER_PASSWORD
   cd /user/vraadmin/DFO/MEIJR
   ascii
   prompt off
   mput claimcnt*
   mput rejtdcnt*
   quit
DELIM

if [[ -s $FTP_ERROR_LOG ]] then
   cat $FTP_ERROR_LOG
else
   echo "File was succussfully transferred to chetser...."
fi
cd $THIS_DIR
#rm -rf $TEMP_DIR
