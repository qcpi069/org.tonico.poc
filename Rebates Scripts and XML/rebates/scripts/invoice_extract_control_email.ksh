#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : invoice_extract_control_email.ksh
#
# Description   : Script to concatenate header and summary control file. 
#									Then email to GDXAETOps@caremark.com, AetnaINV@Aetna.com
#
# Parameters    :
#                -d directory   relative to ${REBATES_HOME} ==> DIRECTORY_NAME
#                (ex: TgtFiles / input / output - directory where source file is kept)
#                -i input file name ==> FILE_NAME without extension (Input_file)
#                -e file extension ==> txt/out/dat or txt_split/out_split/dat_split
#                -t target file name ==> Target File name (Target_file.txt)
#                -r Source File Removal Flag (Y/N)
#
# Output        : Output files will be named based on -t parameter.
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date     User ID     Description
#-----------  --------    -------------------------------------------------#
# 03-10-2015   qcpi2bw    Initial Creation by Michael Jones
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

  . `dirname $0`/Common_RCI_Environment.ksh

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error {
   RETCODE=$1
   ERROR=$2
   EMAIL_SUBJECT=$SCRIPTNAME" Abended in "$REGION" "`date`

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

    mailx -s "$EMAIL_SUBJECT" $TO_MAIL < $LOG_FILE

   exit $RETCODE
}

#-------------------------------------------------------------------------#
# Build Variables
#-------------------------------------------------------------------------#

# Common Variables
RETCODE=0
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
SCRIPTNAME=$FILE_BASE".ksh"

#-------------------------------------------------------------------------#
# LOG FILES
#-------------------------------------------------------------------------#
LOG_FILE_ARCH="${ARCH_LOG_DIR}/${FILE_BASE}.log"`date +"%Y%m%d_%H%M%S"`
LOG_FILE="${LOG_DIR}/${FILE_BASE}.log"
rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# CONTROL FILE
#-------------------------------------------------------------------------#
CSV_TARGET_PATH=$REBATES_HOME/TgtFiles
CONTROL_FILE=$CSV_TARGET_PATH/f_invoice_extract_summary_control.csv
CONTROL_FILE_HDR=$CSV_TARGET_PATH/f_invoice_extract_summary_control_hdr.csv
CONTROL_FILE_CAT=$CSV_TARGET_PATH/f_invoice_extract_summary_control_cat.csv


#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
   {
      print " "
      print "Starting the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "********************************************"
   }                                                                           > $LOG_FILE

#-------------------------------------------------------------------------#
# Region specific variables
#-------------------------------------------------------------------------#
if [[ $REGION = "PROD" ]];   then
        MAIL_DIST="GDXAETOps@caremark.com,AetnaINV@Aetna.com,GDXWIPRO@cvscaremark.com"
        MAIL_SUBJECT="Aetna_Invoice_Adjustment_Control_file"
fi
if [ $REGION = "SIT1"  -o $REGION = "SIT2" ];   then
        MAIL_DIST="gdxsittest@caremark.com,GDXWIPRO@cvscaremark.com"
        MAIL_SUBJECT="SIT-Aetna_Invoice_Adjustment_Control_file"
fi
if [ $REGION = "DEV1"  -o $REGION = "DEV2" ];   then
        MAIL_DIST="michael.jones4@cvscaremark.com,michaelj.jones@cvscaremark.com"
        MAIL_SUBJECT="DEV-Aetna_Invoice_Adjustment_Control_file"
        print $REGION
        print "THIS IS A TEST REGION"
        echo 'LOG FILE and Log Archive'
				echo $LOG_FILE
				echo $LOG_FILE_ARCH
fi

#-------------------------------------------------------------------------#
# Concat Files and Email
# cat file1.txt file2.txt > new.txt
#-------------------------------------------------------------------------#
print ''> $CONTROL_FILE_CAT
# date >> $CONTROL_FILE_CAT >> $CONTROL_FILE_CAT
print '' >> $CONTROL_FILE_CAT
print 'AetnaINV Team,' >> $CONTROL_FILE_CAT
print 'Below is the Aetna Invoice Adjustment Control file.' >> $CONTROL_FILE_CAT
print 'Please review and let our Production Service team know the status.' >> $CONTROL_FILE_CAT
print '' >> $CONTROL_FILE_CAT
print 'Thank you' >> $CONTROL_FILE_CAT
print 'GDX Rebates Production Service Team' >> $CONTROL_FILE_CAT
print 'GDXWIPRO@cvscaremark.com' >> $CONTROL_FILE_CAT
print '' >> $CONTROL_FILE_CAT
print '*********************************************************************' >> $CONTROL_FILE_CAT
print '' >> $CONTROL_FILE_CAT


#-------------------------------------------------------------------------#
# append the Header and Control file into the CAT file
# Send Email
# echo "something" | mailx -s "subject" recipient@somewhere.com
# uuencode file file | mailx -s "subject" recipient@somewhere.com
#-------------------------------------------------------------------------#
cat $CONTROL_FILE_HDR >> $CONTROL_FILE_CAT
cat $CONTROL_FILE >>$CONTROL_FILE_CAT
echo 'Control file'
echo $CONTROL_FILE_CAT
echo 'MAIL_SUBJECT'
echo $MAIL_SUBJECT
echo 'MAIL_DIST'
echo $MAIL_DIST
cat $CONTROL_FILE_CAT | mailx -s $MAIL_SUBJECT $MAIL_DIST
# uuencode $CONTROL_FILE_CAT summary_control.csv | mailx -s $MAIL_SUBJECT $MAIL_DIST


#-------------------------------------------------------------------------#
# move log file to archive 
#-------------------------------------------------------------------------#

mv -f $LOG_FILE $LOG_FILE_ARCH

exit $RETCODE

