#!/bin/ksh
#-----------------------------------------------------------------------------------#
# Script        : GDX_GDWK8000_GD_8000J_Validate_rbate_claims_extract_to_pds.ksh
# Title         : Validate ftp.
#
# Description   : Validate the record counts received from scottsdale rebates system 
#                 through FTP.
#               
# Parameters    : N/A
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  ------------------------------------------------------------#
# 03-07-2005 G.Jayaraman   Initial Creation.
#
#------------------------------------------------------------------------------------#
#------------------------------------------------------------------------------------#
# Caremark GDX Environment variables
#------------------------------------------------------------------------------------#
. `dirname $0`/Common_GDX_Environment.ksh

SCHEDULE="GDWK8000"
JOB="GD_8000J"
FILE_BASE="GDX_"$SCHEDULE"_"$JOB"_validate_rbate_claims_extract_to_pds"

############################################################################################
#
# This script call create the common named variables:
#
###########################################################################################
. $SCRIPT_PATH/Common_GDX_Env_File_Names.ksh

if [[ $REGION = 'prod' ]];   then
    if [[ $QA_REGION = 'true' ]];   then
        # Running in the QA region
        ALTER_EMAIL_ADDRESS=''   
	DATA_FILE_PATH=$INPUT_PATH
    else
        # Running in Prod region        
        ALTER_EMAIL_ADDRESS=''
	DATA_FILE_PATH=$INPUT_PATH
    fi
else
    # Running in Development region
    DATA_FILE_PATH='/datar1/test'
    ALTER_EMAIL_ADDRESS='Ganapathi.jayaraman@caremark.com'     
fi

FTP_TRG_FILE=$DATA_FILE_PATH/rbate_KCWK2300_KC_2300J_claims_extract_to_gdx
GPO_LOAD_TRIG=$DATA_FILE_PATH/GDX_load_rbate_claims_extract.trg

#rm -f $GPO_LOAD_TRIG.*

print ' *** log file is    ' $LOG_FILE                                         >> $LOG_FILE
print 'executing base script name :' $SCRIPTNAME                               >> $LOG_FILE
print `date` ' .. Now calling common_ftp_validation.ksh ... '                  >> $LOG_FILE

###########################################################################################
#
# Call FTP Validation script
#
###########################################################################################

. $SCRIPT_PATH/Common_Ftp_Validation.ksh $DATA_FILE_PATH

##########################################################################################
#
# Check for return code on FTP Validation
#
##########################################################################################

RETCODE=$?
if [[ $RETCODE != 0 ]] ; then
    print `date` ' *** common_ftp_validation.ksh return code ' $RETCODE	>> $LOG_FILE
else
    if [[ $FTP_VALIDATED != 'Y' ]] ; then
	  print ' *** Counts Mismatch '                               	 >> $LOG_FILE	  
        print `date` ' *** ftp_validation switch is ' $FTP_VALIDATED     >> $LOG_FILE 
	  print ' Setting Return code to 12 to invoke email notification ' >> $LOG_FILE
	  RETCODE=12	  
    else
        print ' *** START load trigger create here'                 	>> $LOG_FILE
        export orig_file=${FTP_DATA_FILE##/*/}   
	  print $FTP_DATA_CNT $FTP_UD1 $FTP_UD2 $FTP_UD3 $orig_file		>> $GPO_LOAD_TRIG	 
	  print ' Load trigger file is : ' $GPO_LOAD_TRIG             	>> $LOG_FILE
        mv -f $GPO_LOAD_TRIG $GPO_LOAD_TRIG.`date +"%Y%j%H%M"`  	 
    fi
fi

###################################################################################
#
# Send Email notification if the process failed with a bad return code              
#
###################################################################################

if [[ $RETCODE != 0 ]]; then
   print " "                                                                   >> $LOG_FILE
   EMAILPARM4="  "
   EMAILPARM5="  "
   
   . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh
   cp -f $LOG_FILE $LOG_FILE_ARCH.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

##########################################################################################
#
# Remove the trigger file that kicked off this process and archive the log.
#
##########################################################################################

print `date` ' Completed executing  ' $SCRIPTNAME                             >> $LOG_FILE

rm -f $FTP_TRG_FILE 
mv -f $LOG_FILE $LOG_FILE_ARCH.`date +"%Y%j%H%M"`

exit $RETCODE


