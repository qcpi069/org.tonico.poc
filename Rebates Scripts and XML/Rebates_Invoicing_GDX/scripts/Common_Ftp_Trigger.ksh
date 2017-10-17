#!/bin/ksh
#=====================================================================
#
# File Name    = Common_Ftp_Trigger.ksh
# Description  = This script will create a trigger record containing
#                the line count of a data file to be transferred. 
# Author       = J Tedeschi
# Date Written = Feb 16, 2005
#
#=====================================================================
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION
#==============================================================================
#  04-12-05  qcpi768     5998053     tweak for data file name with no timestamp
#  04-08-05  qcpi733     5998053     Changed from MDA to GDX
#  02-16-05  is89501     5998053     initial version.
#
#----------------------------------
# Environment variables are inherited from parent. 
# Call not used but shown here for documentation. 
####. `dirname $0`/Common_GDX_Environment.ksh
export CME_SUCCESS=0    
export CME_FATAL_ERROR=12 
 
# initialize output variables
FTP_TRG_FILE=

# make sure a value was passed in LOG_FILE 
if [[ $LOG_FILE = "" ]] ; then
    print `date` ' ! ERROR calling Common_Ftp_Trigger.ksh, LOG_FILE name not set by caller! '
    return $CME_FATAL_ERROR
fi

# begin loggable processing
print `date` ' Starting Common_Ftp_Trigger.ksh with FTP_DATA_FILE=' $FTP_DATA_FILE >> $LOG_FILE
 
# make sure a value was passed in FTP_DATA_FILE
if [[ $FTP_DATA_FILE = "" ]] ; then
    print `date` ' ERROR calling Common_Ftp_Trigger.ksh, FTP_DATA_FILE name not set by caller ' >> $LOG_FILE
    return $CME_FATAL_ERROR
fi

# check if data file exists and is readable by current process
if [[ ! -r $FTP_DATA_FILE ]] ; then
    print `date` ' ERROR in Common_Ftp_Trigger.ksh, file ' $FTP_DATA_FILE ' does not exist ' >> $LOG_FILE
    return $CME_FATAL_ERROR
fi

# check if data file is greater than zero bytes
if [[ ! -s $FTP_DATA_FILE ]] ; then
    print `date` ' ERROR in Common_Ftp_Trigger.ksh, file ' $FTP_DATA_FILE ' has zero bytes ' >> $LOG_FILE
    return $CME_FATAL_ERROR
fi

# derive the trigger file name
if [[ ${FTP_DATA_FILE##*.} = "dat" ]] ; then
   FTP_TRG_FILE=${FTP_DATA_FILE%%.dat}.trg
else
   FTP_TRG_FILE=${FTP_DATA_FILE%%.dat*}.trg.${FTP_DATA_FILE##*.}
fi

# create the trigger record using wc and check unix return code
`wc -l $FTP_DATA_FILE > $FTP_TRG_FILE ` >> $LOG_FILE
RC=$?
if [[ $RC != 0 ]] ; then
    print `date` ' *** Common_Ftp_Trigger.ksh return code ' $RC ' on wc command using ' $FTP_DATA_FILE  >> $LOG_FILE
    return $CME_FATAL_ERROR
fi

#set file permissions on the trigger file
chmod 664 $FTP_TRG_FILE

# log the fact that a trigger was created
print `date` ' Common_Ftp_Trigger.ksh created trigger file ' $FTP_TRG_FILE >> $LOG_FILE
cat $FTP_TRG_FILE >> $LOG_FILE


# append any userdata if provided
if [[ $FTP_UD1 != "" ]] ; then
    print `date` ' ... Common_Ftp_Trigger.ksh appending user data ' $FTP_UD1 ' ' $FTP_UD2 ' ' $FTP_UD3 ' to trigger ' >> $LOG_FILE
    echo $FTP_UD1 " " $FTP_UD2 " " $FTP_UD3 >> $FTP_TRG_FILE
fi

# return with code zero
#print `date` ' ... Completed Common_Ftp_Trigger.ksh . ' >> $LOG_FILE

return $CME_SUCCESS