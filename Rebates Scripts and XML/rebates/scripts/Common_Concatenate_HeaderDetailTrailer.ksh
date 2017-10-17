#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : Common_Concatenate_HeaderDetailTrailer.ksh
#
# Description   : This script will perform the below operations
# 
#               1) It will receive file name as parameter
#               2) It will search the directory (specified as source) for
#                    <filename>_Header.<extension>
#                    <filename>_Detail.<extension>
#                    <filename>_Trailer.<extension>
#               3) It will merge the 3 file to create a new file (where $3= Target file name)
#
# Parameters    : 
#               1) -d directory   relative to ${REBATES_HOME}\ 
#                                 i.e. actual path =  ${REBATES_HOME}\$directory
#               2) -s sourcefilename
#               3) -t targetfilename  
#               4) -e extension    (without dot)
#
# Output        : Log file as $LOG_FILE
#
# Input Files   : /opt/pcenter/<env>/rebates/TgtFiles
#                 where env is dev1/dev2 or sit1/sit2 or prod
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date     User ID     Description
#----------  --------    -------------------------------------------------#
# 03-21-14   qcpuk218    Initial Creation 
#                        ITPR005898 State of NY - Rebates Payment
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
   cp -f $LOG_FILE $LOG_FILE_ARCH
   exit $RETCODE
}


#-------------------------------------------------------------------------#
# Main Processing starts 
#-------------------------------------------------------------------------#

# Set Variables
RETCODE=0
SCRIPTNAME=$(basename "$0")

# LOG FILES
LOG_ARCH_PATH=$REBATES_HOME/log/archive
LOG_FILE_ARCH=${LOG_ARCH_PATH}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE=${LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log"

# Remove log file if present
rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#

print "********************************************"     >> $LOG_FILE
print "Starting the script $SCRIPTNAME ............"     >> $LOG_FILE
print `date +"%D %r %Z"`                                 >> $LOG_FILE
print "********************************************"     >> $LOG_FILE

#-------------------------------------------------------------------------#
# Step 1. Assign values to variables from arguments passed
#-------------------------------------------------------------------------#
while getopts d:s:e:t: argument
do
      case $argument in
          d)SOURCE_FILE_PATH=$OPTARG;;
          s)SOURCE_FILE_PREFIX=$OPTARG;;
          e)EXTENSION=$OPTARG;;
          t)TARGET_FILE_PREFIX=$OPTARG;;
          *)
            echo "\n Usage: $SCRIPTNAME -d -s -e -t"                                                      >> $LOG_FILE
            echo "\n Example: $SCRIPTNAME -d TgtFiles -f NYS.Rebates.2014Q1 -e txt -t NYS.Rebates.2014Q1" >> $LOG_FILE
            echo "\n -d <Directory> Relative directory path i.e. relative to $REBATES_HOME"               >> $LOG_FILE
            echo "\n -s <Source File> Source file name without extension"                                 >> $LOG_FILE
            echo "\n -e <Extension> Extension of source and target file without dot"                      >> $LOG_FILE
            echo "\n -t <Target File> Target file name without extension"                                 >> $LOG_FILE
            exit_error ${RETCODE} "Incorrect arguments passed"
            ;;
      esac
done

print " "                                                    >> $LOG_FILE
print " Parameter values passed for current run are: "       >> $LOG_FILE
print " Directory path            : ${SOURCE_FILE_PATH}"     >> $LOG_FILE
print " Source File Name prefix   : $SOURCE_FILE_PREFIX"     >> $LOG_FILE
print " Extension of file         : $EXTENSION"              >> $LOG_FILE
print " Target File Name          : $TARGET_FILE_PREFIX"     >> $LOG_FILE
print " "                                                    >> $LOG_FILE

if [[ $SOURCE_FILE_PATH = '' || $SOURCE_FILE_PREFIX = '' || $EXTENSION = '' || $TARGET_FILE_PREFIX = '' ]]; then
      RETCODE=1
      echo "\n Usage: $SCRIPTNAME -d -s -e -t"                                                            >> $LOG_FILE
      echo "\n Example: $SCRIPTNAME -d TgtFiles -f NYS.Rebates.2014Q1 -e txt -t NYS.Rebates.2014Q1"       >> $LOG_FILE
      echo "\n -d <directory> Relative directory path i.e. relative to $REBATES_HOME"                     >> $LOG_FILE
      echo "\n -s <Source File> Source file name without extension"                                       >> $LOG_FILE
      echo "\n -e <Extension> Extension of source and target file without dot e.g. txt"                   >> $LOG_FILE
      echo "\n -t <Target File> Target file name without extension"                                       >> $LOG_FILE    
      exit_error ${RETCODE} "Incorrect arguments passed"
fi

if [[ -d ${REBATES_HOME}/${SOURCE_FILE_PATH} ]]; then
      print "Absolute Directory path to be used for source file is ${REBATES_HOME}/${SOURCE_FILE_PATH}"   >> $LOG_FILE
else 
      RETCODE=1
      print "ERROR: Directory path incorrect ${REBATES_HOME}/${SOURCE_FILE_PATH}"                         >> $LOG_FILE
      exit_error $RETCODE " Directory path incorrect ${REBATES_HOME}/${SOURCE_FILE_PATH}"                 >> $LOG_FILE
fi

cd ${REBATES_HOME}/${SOURCE_FILE_PATH}

#-------------------------------------------------------------------------#
# Step 2. Check existence of HEADER, DETAIL and TRAILER files to be merged.
#-------------------------------------------------------------------------#

if [[ -s ${SOURCE_FILE_PREFIX}_Header.${EXTENSION}  &&  -s ${SOURCE_FILE_PREFIX}_Detail.${EXTENSION}  &&  -s ${SOURCE_FILE_PREFIX}_Trailer.${EXTENSION} ]]; then
   print "Header, detail and trailer file are present. "              >> $LOG_FILE 
   print "Processing started for files "                              >> $LOG_FILE
   print "Header File  - ${SOURCE_FILE_PREFIX}_Header.${EXTENSION}"   >> $LOG_FILE
   print "Detail File  - ${SOURCE_FILE_PREFIX}_Detail.${EXTENSION}"   >> $LOG_FILE
   print "Trailer File - ${SOURCE_FILE_PREFIX}_Trailer.${EXTENSION}"  >> $LOG_FILE

else
   print "At least one of the input file not present\empty."          >> $LOG_FILE 
   print "Please check input files (header, detail or trailer)"       >> $LOG_FILE
   print "Header File  - ${SOURCE_FILE_PREFIX}_Header.${EXTENSION}"   >> $LOG_FILE
   print "Detail File  - ${SOURCE_FILE_PREFIX}_Detail.${EXTENSION}"   >> $LOG_FILE
   print "Trailer File - ${SOURCE_FILE_PREFIX}_Trailer.${EXTENSION}"  >> $LOG_FILE
   RETCODE=1
   exit_error $RETCODE "Input file not present or empty"
fi

#-------------------------------------------------------------------------#
# Step 3. Merge Header, Detail and Trailer files into one file.
#-------------------------------------------------------------------------#

print " "                                                                              >> $LOG_FILE
print "Merging Header, Detail and Trailer file into $TARGET_FILE_PREFIX.${EXTENSION} " >> $LOG_FILE
print " "                                                                              >> $LOG_FILE

awk '{print}' ${SOURCE_FILE_PREFIX}_Header.${EXTENSION} ${SOURCE_FILE_PREFIX}_Detail.${EXTENSION} ${SOURCE_FILE_PREFIX}_Trailer.${EXTENSION} > $TARGET_FILE_PREFIX.${EXTENSION}

# Capture error code of awk command
RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    exit_error $RETCODE "Error in awk command execution"
else 
    print "********************************************"              >> $LOG_FILE
    print "....Completed executing " $SCRIPTNAME " ...."              >> $LOG_FILE
    print `date +"%D %r %Z"`                                          >> $LOG_FILE
    print "********************************************"              >> $LOG_FILE
    mv -f $LOG_FILE $LOG_FILE_ARCH
    exit $RETCODE
fi

#-------------------------------------------------------------------------#
# End of Script
#-------------------------------------------------------------------------#
