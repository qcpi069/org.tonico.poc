
#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : Common_File_Split.ksh
#
# Description   : Script to split into multiple files based on -s parameter
#
#
# Parameters    :
#                -d directory   relative to ${REBATES_HOME} ==> DIRECTORY_NAME 
#                (ex: TgtFiles / input / output - directory where source file is kept)
#                -i input file name ==> FILE_NAME with extension (Test_file.txt)
#                   only one file name can be passed as input
#		 -s # of splits ==> 2
#
# Output        : Output files <Test_file.txt_split#> will be created in -d Directory
#
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date     User ID     Description
#----------  --------    -------------------------------------------------#
# 02-16-16   qcpue98u	 Removed harcoded developer email id
# 04-18-14   qcpue98u    Initial Creation - PDA
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
SCRIPTNAME=$(basename "$0")

# LOG FILES
LOG_ARCH_PATH=$REBATES_HOME/log/archive
LOG_FILE_ARCH=${LOG_ARCH_PATH}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE=${LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log"
TIME_STAMP=`date +"%Y%m%d_%H%M%S"`

rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Input Parameter Validation
#-------------------------------------------------------------------------#

print "####################################################################"					 >> $LOG_FILE
print "##### Common_File_Split Script Strats  $TIME_STAMP          #####"					 >> $LOG_FILE
print "####################################################################"					 >> $LOG_FILE


while getopts d:i:s: argument
do
      case $argument in
          d)SOURCE_DIR=$OPTARG;;
          i)SOURCE_FILE=$OPTARG;;
          s)SPLIT_FILE_CNT=$OPTARG;;
          *)
            echo "\n Usage: $SCRIPTNAME -d -i -s"								>> $LOG_FILE
            echo "\n Example: $SCRIPTNAME -d TgtFiles -f FILE_NAME.txt  -s 2"					>> $LOG_FILE
            echo "\n -d <Directory> Relative directory path i.e. relative to $REBATES_HOME"			>> $LOG_FILE
            echo "\n -i <input File> input file name with extension"						>> $LOG_FILE
            echo "\n -s <# of Target Files> Number of target files to be created"				>> $LOG_FILE
            exit_error ${RETCODE} "Incorrect arguments passed"
            ;;
      esac
done

print "\n\n"													>> $LOG_FILE
print "################################"									>> $LOG_FILE
print "### Script Parameters Passed ###"									>> $LOG_FILE
print "################################"									>> $LOG_FILE
print "\n\n"													>> $LOG_FILE


print "\n"							>> $LOG_FILE
print " Parameter values passed for current run are: "		>> $LOG_FILE
print " Directory path            : $SOURCE_DIR "		>> $LOG_FILE
print " Source File Name          : $SOURCE_FILE "      	>> $LOG_FILE
print " # of Files to split       : $SPLIT_FILE_CNT "	        >> $LOG_FILE
print "\n"							>> $LOG_FILE


if [[ $SOURCE_DIR = '' || $SOURCE_FILE = '' ||  $SPLIT_FILE_CNT = '' ]]; then
      RETCODE=1
            echo "\n Usage: $SCRIPTNAME -d -i -s"								>> $LOG_FILE
            echo "\n Example: $SCRIPTNAME -d TgtFiles -i FILE_NAME.txt  -s 2"					>> $LOG_FILE
            echo "\n -d <Directory> Relative directory path i.e. relative to $REBATES_HOME"			>> $LOG_FILE
            echo "\n -i <input File> input file name with extension"						>> $LOG_FILE
            echo "\n -s <# of Files to Split> Number of target files to be created"				>> $LOG_FILE
      exit_error ${RETCODE} "Incorrect arguments passed"
fi

if [[ -d ${REBATES_HOME}/${SOURCE_DIR} ]]; then
      print "Absolute Directory path to be used for source file is ${REBATES_HOME}/${SOURCE_DIR}"		>> $LOG_FILE
else
      RETCODE=1
      print "ERROR: Directory path incorrect ${REBATES_HOME}/${SOURCE_DIR}"					>> $LOG_FILE
      exit_error $RETCODE " Directory path incorrect ${REBATES_HOME}/${SOURCE_DIR}"				>> $LOG_FILE
fi

#-------------------------------------------------------------------------#
# Get line count and build split command file
#-------------------------------------------------------------------------#

print "\n\n"													>> $LOG_FILE
print "####################################################"							>> $LOG_FILE
print "### Get line Count and Calculates Lines to split ###"							>> $LOG_FILE
print "####################################################"							>> $LOG_FILE
print "\n\n"													>> $LOG_FILE

echo $SOURCE_FILE
TOT_SRC_CNT=`sed -n '$=' ${REBATES_HOME}/${SOURCE_DIR}/$SOURCE_FILE`                                             
SPLIT_TO_LINE=`expr $TOT_SRC_CNT / $SPLIT_FILE_CNT`
echo $TOT_SRC_CNT
BEGIN_FROM=1
LAST_TO=$SPLIT_TO_LINE
LOOP_CNT=1
SRC_FILE_PTH="${REBATES_HOME}/${SOURCE_DIR}/$SOURCE_FILE"
CMD_FILE=$SRC_FILE_PTH".cmd"

echo $SRC_FILE_PTH

print "SourceFile to Split -- $SOURCE_FILE"									>> $LOG_FILE
print "Total Line Count in $SOURCE_FILE -- $TOT_SRC_CNT"							>> $LOG_FILE
print "# of Files To Split -- $SPLIT_FILE_CNT"									>> $LOG_FILE

rm -f $CMD_FILE

print "\n\n"													>> $LOG_FILE
print "####################################################"							>> $LOG_FILE
print "### Build split.bat file to split files          ###"							>> $LOG_FILE
print "####################################################"							>> $LOG_FILE
print "\n\n"													>> $LOG_FILE

while [[ $LOOP_CNT -le $SPLIT_FILE_CNT ]]
do
   OUT_FILE=${REBATES_HOME}/${SOURCE_DIR}/"$SOURCE_FILE""_split$LOOP_CNT"
   print "sed -n '$BEGIN_FROM,$LAST_TO w $OUT_FILE' $SRC_FILE_PTH" >> $CMD_FILE
#sed -n "'""${BEGIN_FROM},${LAST_TO} w ${OUT_FILE}""'" ""${SRC_FILE_PTH}""  
   BEGIN_FROM=`expr $BEGIN_FROM + $SPLIT_TO_LINE`
   
   LOOP_CNT=`expr $LOOP_CNT + 1`

     if [[ $LOOP_CNT -lt $SPLIT_FILE_CNT ]]; then
         LAST_TO=`expr $LAST_TO + $SPLIT_TO_LINE`
     else
         LAST_TO=$TOT_SRC_CNT
     fi

done

#-------------------------------------------------------------------------#
# File Split Processing 
#-------------------------------------------------------------------------#

TOT_TGT_CNT=0

  rm -f `find ${REBATES_HOME}/${SOURCE_DIR}  -name $SOURCE_FILE"_split*"`
     if [[ $? != 0 ]]; then
         print "ERROR: Removing old split files -- $SOURCE_FILE"_split*" "
         RETCODE=1
         exit_error $RETCODE " Error in deleting the old split files"						>> $LOG_FILE
     fi

print "\n\n"													>> $LOG_FILE
print "####################################################"							>> $LOG_FILE
print "### Execute split.bat file                       ###"							>> $LOG_FILE
print "####################################################"							>> $LOG_FILE
print "\n\n"													>> $LOG_FILE

chmod 755 $CMD_FILE 
. $CMD_FILE          

     if [[ $? != 0 ]]; then
         print "ERROR: Processing File Split "									>> $LOG_FILE
         RETCODE=1
         exit_error $RETCODE " Error in function file_split"							>> $LOG_FILE
     fi


ls -lt ${REBATES_HOME}/${SOURCE_DIR} | grep $SOURCE_FILE"_split*" | awk '{print $9}'  | while read file;
do
  TGT_REC_CNT=`sed -n '$=' ${REBATES_HOME}/${SOURCE_DIR}/$file`
  TOT_TGT_CNT=`expr $TOT_TGT_CNT + $TGT_REC_CNT`
done
echo $TGT_REC_CNT
echo $TOT_TGT_CNT
if [[ $TOT_SRC_CNT -eq $TOT_TGT_CNT ]]; then
    print " $SOURCE_FILE"_split*" -- record count $TOT_TGT_CNT matches  "$SOURCE_FILE" count $TOT_SRC_CNT \n "   >> $LOG_FILE
    print "Split File creation successfull \n"									 >> $LOG_FILE
    print "******Common_File_Split Completes - $TIME_STAMP*******"                                               >> $LOG_FILE

else
    RETCODE=1
    print " $SOURCE_FILE"_split*"  record count $TOT_TGT_CNT not matched with "$SOURCE_FILE" count $TOT_SRC_CNT"  >> $LOG_FILE
    exit_error $RETCODE												  >> $LOG_FILE
fi

if [[ $RETCODE != 1 ]]; then

mv -f $LOG_FILE $LOG_FILE_ARCH

  if [[ $? != 0 ]]; then
         print "ERROR: Moving Log file - $LOG_FILE "
         RETCODE=1
         exit_error $RETCODE " Error moving $LOG_FILE to $LOG_FILE_ARCH"					>> $LOG_FILE
  fi
fi
