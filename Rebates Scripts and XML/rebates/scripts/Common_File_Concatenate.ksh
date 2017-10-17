
#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : Common_File_Concatenate.ksh
#
# Description   : Script to concatenate multiple split files to one file
#                 Script performs wildcard search on -i parameter
#                 <input file name_split*> and merge them as single file#
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
#----------  --------    -------------------------------------------------#
# 04-21-14   qcpue98u    Initial Creation - PDA
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

#-------------------------------------------------------------------------#
# Input Parameter Validation
#-------------------------------------------------------------------------#
print "\n"                                                                                                                      >> $LOG_FILE
print "####################################################################"                                                    >> $LOG_FILE
print "##### File Concatenate Script Starts -- $TIME_STAMP       #####"                                                         >> $LOG_FILE
print "####################################################################"                                                    >> $LOG_FILE
print "\n"                                                                                                                      >> $LOG_FILE

while getopts d:i:e:t:r: argument
do
      case $argument in
          d)SOURCE_DIR=$OPTARG;;
          i)SOURCE_FILE=$OPTARG;;
          e)SOURCE_FILE_EXTN=$OPTARG;;
          t)TARGET_FILE=$OPTARG;;
          r)DELETE_FLAG=$OPTARG;;
          *)
            echo "\n Usage: $SCRIPTNAME -d -i -e -t -r"                                                                         >> $LOG_FILE
            echo "\n Example: $SCRIPTNAME -d TgtFiles -i Source_File -e extension  -t Target_File -r Y/N"                       >> $LOG_FILE
            echo "\n -d <Directory> Relative directory path i.e. relative to $REBATES_HOME"                                     >> $LOG_FILE
            echo "\n -i <input Filename>  file name format -- FILE_NAME "                                                       >> $LOG_FILE
            echo "\n -e <input file extension> file extension"                                                                  >> $LOG_FILE
            echo "\n -t <Target Filename> Target Filename with file extension txt or txt_split"                                 >> $LOG_FILE
            echo "\n -r <Flag (Y/N)> Delete Flag to remove source files "                                                       >> $LOG_FILE
            exit_error ${RETCODE} "Incorrect arguments passed"
            ;;
      esac
done

print "\n"                                                                                                                      >> $LOG_FILE
print "################################"                                                                                        >> $LOG_FILE
print "### Script Parameters Passed ###"                                                                                        >> $LOG_FILE
print "###############################"                                                                                         >> $LOG_FILE
print "\n"                                                                                                                      >> $LOG_FILE


print "\n"                                                                                                                      >> $LOG_FILE
print " Directory path            : $SOURCE_DIR "                                                                               >> $LOG_FILE
print " Source File Name          : $SOURCE_FILE "                                                                              >> $LOG_FILE
print " Source File Extn          : $SOURCE_FILE_EXTN "                                                                         >> $LOG_FILE
print " Target File Name          : $TARGET_FILE "                                                                              >> $LOG_FILE
print " Source File Delete Flag   : $DELETE_FLAG "                                                                              >> $LOG_FILE
print "\n"

if [[ $SOURCE_DIR = '' || $SOURCE_FILE = '' || $SOURCE_FILE_EXTN = '' || $TARGET_FILE = '' ||  $DELETE_FLAG = '' ]]; then
      RETCODE=1
            echo "\n Usage: $SCRIPTNAME -d -i -e -t -r"                                                                         >> $LOG_FILE
            echo "\n Example: $SCRIPTNAME -d TgtFiles -i FILE_NAME -e txt -t Out_file_name.txt -r Y"                            >> $LOG_FILE
            echo "\n -d <Directory> Relative directory path i.e. relative to $REBATES_HOME"                                     >> $LOG_FILE
            echo "\n -i <input File> input file name without extension"                                                         >> $LOG_FILE
            echo "\n -e <File Extension> input file extension "                                                                 >> $LOG_FILE
            echo "\n -r <Flag (Y/N)> Delete Flag to remove source files "                                                       >> $LOG_FILE
      exit_error ${RETCODE} "Incorrect arguments passed"
fi

if [[ -d ${REBATES_HOME}/${SOURCE_DIR} ]]; then
      print "\n Absolute Directory path to be used for source file is ${REBATES_HOME}/${SOURCE_DIR}"                            >> $LOG_FILE
else
      RETCODE=1
      print "\n ERROR: Directory path incorrect ${REBATES_HOME}/${SOURCE_DIR}"                                                  >> $LOG_FILE
      exit_error $RETCODE " Directory path incorrect ${REBATES_HOME}/${SOURCE_DIR}"                                             >> $LOG_FILE
fi

#-------------------------------------------------------------------------#
# Concat Files
#-------------------------------------------------------------------------#

pattern="split"

if [[  $SOURCE_FILE_EXTN == *${pattern}* ]]; then
   SOURCE_FILE="$SOURCE_FILE*""$SOURCE_FILE_EXTN*"
else
  SOURCE_FILE="$SOURCE_FILE*""$SOURCE_FILE_EXTN"
fi

SOURCE_FILE_CNT=`find ${REBATES_HOME}/${SOURCE_DIR}  -name "$SOURCE_FILE*" | wc -l`

print "\n"                                                                                                                      >> $LOG_FILE
print "#################################"                                                                                       >> $LOG_FILE
print "## Remove existing Target file ##"                                                                                       >> $LOG_FILE
print "#################################"                                                                                       >> $LOG_FILE
print "\n"                                                                                                                      >> $LOG_FILE

   rm -f ${REBATES_HOME}/${SOURCE_DIR}/$TARGET_FILE
   if [[ $? != 0 ]]; then
     RETCODE=1
     exit_error $RETCODE "Error Removing $TARGET_FILE present in Folder $SOURCE_DIR "                                           >> $LOG_FILE
   else
     print "\n Removed $TARGET_FILE present in Folder $SOURCE_DIR "                                                             >> $LOG_FILE
  fi

print "\n"                                                                                                                      >> $LOG_FILE
print "#########################"                                                                                               >> $LOG_FILE
print "### Concatenate Files ###"                                                                                               >> $LOG_FILE
print "#########################"                                                                                               >> $LOG_FILE
print "\n"                                                                                                                      >> $LOG_FILE

TOT_SRC_CNT=0
echo $SOURCE_FILE
ls -l ${REBATES_HOME}/${SOURCE_DIR}/$SOURCE_FILE | awk '{print $9}'  | while read file;
do

 if [[ ! -s $file ]]; then
   SRC_REC_CNT=0
 else
   SRC_REC_CNT=`sed -n '$=' $file`
 fi

TOT_SRC_CNT=`expr $TOT_SRC_CNT + $SRC_REC_CNT`

awk '{print}' $file >> ${REBATES_HOME}/${SOURCE_DIR}/$TARGET_FILE

 if [[ $? != 0 ]]; then
    RETCODE=1
    exit_error $RETCODE "Error writing Source File -- $file to Target -- $TARGET_FILE"                                          >> $LOG_FILE
 fi
done

TOT_TGT_CNT=`sed -n '$=' ${REBATES_HOME}/${SOURCE_DIR}/$TARGET_FILE`

if [[ $TOT_SRC_CNT -eq $TOT_TGT_CNT ]]; then
   print "\n $TARGET_FILE -- record count $TOT_TGT_CNT matches  "$SOURCE_FILE*" count $TOT_SRC_CNT "                            >> $LOG_FILE
else
    RETCODE=1
    exit_error $RETCODE "$TARGET_FILE -- record count $TOT_TGT_CNT not matched with "$SOURCE_FILE*" count $TOT_SRC_CNT "        >> $LOG_FILE
fi

print "\n"                                                                                                                      >> $LOG_FILE
print "###############################################################"                                                         >> $LOG_FILE
print "### Remove Split Files / Source files based on Optional Flag ##"                                                         >> $LOG_FILE
print "###############################################################"                                                         >> $LOG_FILE
print "\n"                                                                                                                      >> $LOG_FILE


if [[ $DELETE_FLAG = 'Y' ]]; then

   rm -f `find ${REBATES_HOME}/${SOURCE_DIR}  -name "$SOURCE_FILE*"`

     if [[ $? != 0 ]]; then
         RETCODE=1
         exit_error $RETCODE " Error in Removing Source files"                                                                  >> $LOG_FILE
     else
         print "\n Source files deletion successfull -- $SOURCE_FILE* -- $TIME_STMAP "                                          >> $LOG_FILE
         print "\n ***Common_File_Concatenate Script run Complete - $TIME_STAMP ***"                                            >> $LOG_FILE
    fi
else
   print "\n Delete Flag is not Y.... "                                                                                         >> $LOG_FILE
   print "\n ***Common_File_Concatenate Script run Complete - $TIME_STAMP ***"                                                  >> $LOG_FILE
fi

if [[ $RETCODE != 1 ]]; then

    mv -f $LOG_FILE $LOG_FILE_ARCH
    if [[ $? != 0 ]]; then
         RETCODE=1
         exit_error $RETCODE " Error moving $LOG_FILE to $LOG_FILE_ARCH"                                                        >> $LOG_FILE
    fi
fi
