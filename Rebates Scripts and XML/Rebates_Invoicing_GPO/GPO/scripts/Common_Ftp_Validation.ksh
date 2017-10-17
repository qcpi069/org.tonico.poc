#!/bin/ksh
#=====================================================================
#
# File Name    = Common_Ftp_Validation.ksh
# Description  = This script will locate the oldest trigger record matching 
#                the supplied pattern, 
#                extract the data file name, 
#                do a linecount on the data file and 
#                compare it to the linecount stored in the trigger record
#                returning a Y or N in $FTP_VALIDATED
# Author       = J Tedeschi
# Date Written = Feb 21, 2005
#
#=====================================================================
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION
#==============================================================================
#  04-12-05  qcpi768     5998053     tweak for trig file name with no timestamp
#  02-21-05  is89501                 initial version.
#
###############################################################################
#
#                ********* S P E C I A L  N O T E S ********* 
#
#   All local temporary variables are prefixed with "CFV_"
#
###############################################################################
# Environment variables are inherited from parent. 
# Call not used but shown here for documentation. 
####. `dirname $0`/Common_MDA_Environment.ksh

# initialize all output variables
FTP_VALIDATED=N
FTP_DATA_CNT=0
FTP_TRG_CNT=0
FTP_DATA_FILE=
FTP_UD1=
FTP_UD2=
FTP_UD3=

export CME_SUCCES=0
export CME_FATAL_ERROR=12

# make sure a value was passed in LOG_FILE 
if [[ $LOG_FILE = "" ]] ; then
    print `date` ' ! ERROR calling Common_Ftp_Validation.ksh, LOG_FILE name not set by caller! '
    return $CME_FATAL_ERROR
fi

# begin loggable processing
print `date` ' ... Starting Common_Ftp_Validation.ksh with FTP_TRG_FILE=' $FTP_TRG_FILE >> $LOG_FILE

# locate the oldest trigger record matching the supplied pattern 
#if [[ $FTP_TRG_FILE != "" ]] ; then
#   CFV_FTP_SELECTED_TRG=$(ls $FTP_TRG_FILE*.trg.* | head -n1 )
#else
#    print `date` ' ERROR in Common_Ftp_Validation.ksh, no trigger file name was passed ' >> $LOG_FILE
#    return $CME_FATAL_ERROR
#fi

# must pass a trigger base name to match
if [[ $FTP_TRG_FILE = "" ]] ; then
    print `date` ' ERROR in Common_Ftp_Validation.ksh, no trigger file name was passed ' >> $LOG_FILE
    return $CME_FATAL_ERROR
fi
if [[ -r $FTP_TRG_FILE.trg ]] ; then
   CFV_FTP_SELECTED_TRG=$FTP_TRG_FILE.trg
else
   # locate the oldest trigger record matching the supplied pattern 
    CFV_FTP_SELECTED_TRG=$(ls $FTP_TRG_FILE*.trg.* | head -n1 )
fi



# error if no trigger match found
if [[ $CFV_FTP_SELECTED_TRG = "" ]] ; then
    print `date` ' ERROR in Common_Ftp_Validation.ksh, no trigger file could be found for ' $FTP_TRG_FILE >> $LOG_FILE
    return $CME_FATAL_ERROR
fi

# get trigger count and datafile name
print `date` ' Reading data from selected trigger file ' $CFV_FTP_SELECTED_TRG >> $LOG_FILE
export CFV_FIRST_READ=1
# read trigger data into variables (count and datafilename)
# Note: this code looks a little weird but it works.
while read CFV_MY_TRG_CNT CFV_MY_DATA_FILE CFV_MY_UD3; do
  if [[ $CFV_FIRST_READ != 1 ]]; then
#   (when user data is present in second record it is returned in up to 3 User Defined fields)
    export FTP_UD1=$CFV_MY_TRG_CNT
    export FTP_UD2=$CFV_MY_DATA_FILE
    export FTP_UD3=$CFV_MY_UD3
  else
    CFV_FIRST_READ=0
    export FTP_TRG_CNT=$CFV_MY_TRG_CNT 
    export CFV_FTP_DATA_FILE_FULL=$CFV_MY_DATA_FILE
  fi
done < $CFV_FTP_SELECTED_TRG
# print 'Done reading data from trigger file' $CFV_FTP_SELECTED_TRG >> $LOG_FILE

# establish data file name to be validated and returned taking into account subsystem option
if [[ ${SUBSYSTEM:-none} != "none" ]] ; then
   FTP_DATA_FILE=$INPUT_PATH/$SUBSYSTEM/${CFV_FTP_DATA_FILE_FULL##*/}
else
   FTP_DATA_FILE=$INPUT_PATH/${CFV_FTP_DATA_FILE_FULL##*/}
fi

print `date` ' Data File Name to be validated established as ' $FTP_DATA_FILE >> $LOG_FILE

# establish the trigger file name as full path/name of the selected trigger file
FTP_TRG_FILE=$CFV_FTP_SELECTED_TRG

# error if trigger count not > zero
if (( $FTP_TRG_CNT <= 0  )) ; then
    print `date` ' ERROR in Common_Ftp_Validation.ksh, trigger count is zero in  ' $FTP_TRG_FILE >> $LOG_FILE
    return $CME_FATAL_ERROR
fi

# check if data file exists and is readable by current process
if [[ ! -r $FTP_DATA_FILE ]] ; then
    print `date` ' ERROR in Common_Ftp_Validation.ksh, file ' $FTP_DATA_FILE ' does not exist ' >> $LOG_FILE
    return $CME_FATAL_ERROR
fi

# check if data file is greater than zero bytes
if [[ ! -s $FTP_DATA_FILE ]] ; then
    print `date` ' ERROR in Common_Ftp_Validation.ksh, file ' $FTP_DATA_FILE ' has zero bytes ' >> $LOG_FILE
    return $CME_FATAL_ERROR
fi

# count the datafile and check unix return code from wc  
FTP_DATA_CNT=$(wc -l < $FTP_DATA_FILE)
RC=$?
if [[ $RC != 0 ]] ; then
    print `date` ' *** Common_Ftp_Validation.ksh return code ' $RC ' on wc command using ' $FTP_DATA_FILE  >> $LOG_FILE
    return $CME_FATAL_ERROR
fi

print `date` ' *** datafile linecount xx' $FTP_DATA_CNT 'xx' >> $LOG_FILE
print `date` ' *** trig file counter  xx' $FTP_TRG_CNT 'xx' >> $LOG_FILE

# return validation indicator based on comparison
if (( $FTP_DATA_CNT != $FTP_TRG_CNT )) ; then
    FTP_VALIDATED=N  
    print `date` ' *!!!!!!! counts do not match - arg! ' >> $LOG_FILE
else
    FTP_VALIDATED=Y
    print `date` ' *** counts match okay ' >> $LOG_FILE
fi

print `date` ' ... Completed Common_Ftp_Validation.ksh  ' >> $LOG_FILE
return $CME_SUCCESS
