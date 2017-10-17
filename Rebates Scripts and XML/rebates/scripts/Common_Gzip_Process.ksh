#!/usr/bin/ksh
#set -x
#-----------------------------------------------------------------------------------------------------------------------#
#
# Script        : Common_Gzip_Process.ksh
#
# Description   : General Purpose script to use the gzip functions for 
#                 compressing and uncompressing
#
# Command Line Flags:   -a c/u action indicator, compress or uncompress
#                       -d source directory, optional
#                       -s source filename
#                       -D Target directory, optional
#                       -t target filename
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date      User           Description
# ---------  ----------  -------------------------------------------------
#
# 11-02-15    QCPI733      Initial Creation for ITPR012352.
#
#-------------------------------------------------------------------------------------------------------------------------#

. `dirname $0`/Common_RCI_Environment.ksh

#####################################################################################################################################
#                                    Help function 
#####################################################################################################################################

function help_Usage
{
echo "Help function activated"
echo " "
echo "Usage: $SCRIPTNAME -a [-d] -s [-D] -t target_filename.txt "
echo "Example: $SCRIPTNAME -a c -d <optional> -s source_filename.txt -D <optional> -t target_filename.zip"
echo "-a required, c for compress or u for uncompress"
echo "-d optional, source file directory, if not provided, default is $REBATES_HOME/TgtFiles"
echo "-s required, source filename, not qualified, with extension"
echo "-D optional, target file directory, if not provided, default is $REBATES_HOME/TgtFiles"
echo "-t required, target filename, not qualified, with or WITHOUT extension"
echo " "
}

#-------------------------------------------------------------------------------------------------------------------------#
#                                       Function to exit the script
#-------------------------------------------------------------------------------------------------------------------------#
function exit_Script {

    RETCODE=$1
    ERROR=$2
    
    if [[ $RETCODE != 0 ]];then
                {
                print " "
                print $ERROR
                print " "
                print " !!! Aborting!!!"
                print " "
                print "return_code = " $RETCODE
                print " "
                print " ------ Ending script $SCRIPTNAME `date` ------"
                }                                                              >> $LOG_FILE
    else
                {
                print " "
                print ".... $SCRIPTNAME  completed with return code $RETCODE ...."
                print " "
                print " ------ Ending script $SCRIPTNAME `date` ------"
                print " "
                }                                                              >> $LOG_FILE
                mv $LOG_FILE $ARCH_LOGFILE
     fi

    return $RETCODE
}

#--------------------------------------------------------------------------------------------------------------------------#
#                                        Function to check variables                                                       #
#--------------------------------------------------------------------------------------------------------------------------#

function validate_Params {

print " "                                                                      >> $LOG_FILE
print "Start Gzip parameter validation"                                        >> $LOG_FILE 
print " "                                                                      >> $LOG_FILE

RETCODE=0

#Check compression flag (required) (-z checks if given string is zero)
if [[ -z $ACTN_IND ]]; then
    RETCODE=$ERR_RC
    print "Action indicator is missing, c or u required"                       >> $LOG_FILE
elif [[ $ACTN_IND = 'c' || $ACTN_IND = 'C' ]];then
    print "Compression action passed: >$ACTN_IND<"                             >> $LOG_FILE
    elif [[ $ACTN_IND = 'u' || $ACTN_IND = 'U' ]];then
        print "Uncompress action passed: >$ACTN_IND<"                          >> $LOG_FILE
        else 
            "Invalid action indicator passed, c or u required."                >> $LOG_FILE
            RETCODE=$ERR_RC
fi 
#Check Source Directory (optional)(-n checks if string size is non-zero, -d check to see if directory)
if [[ -n $SRC_FILE_DIR ]]; then
    if [[ -d $SRC_FILE_DIR ]]; then
        print "Valid Source Directory provided: >$SRC_FILE_DIR< "              >> $LOG_FILE
    else
        print "INVALID Source directory was provided: >$SRC_FILE_DIR<"         >> $LOG_FILE
        RETCODE=$ERR_RC
    fi
else 
    print "No source dir provided, default of $REBATES_HOME/TgtFiles used"     >> $LOG_FILE
    SRC_FILE_DIR=$REBATES_HOME/"TgtFiles"
fi
#Check Source filename (required)(-e checks to see if file exists, -s checks to see if file size > 0)
SRC_FILE=$SRC_FILE_DIR/$SRC_FILE_NME
if [[ -e $SRC_FILE ]]; then
    if [[ -s $SRC_FILE ]]; then
        print "Existing Source filename provided: >$SRC_FILE_NME<"             >> $LOG_FILE
    else
        print "Source filename provided but file empty: >$SRC_FILE_NME<"       >> $LOG_FILE
        RETCODE=$ERR_RC
    fi
else
    print "Source filename not provided or cannot find file, required"         >> $LOG_FILE
    print "    Source filename provided - >$SRC_FILE<"                         >> $LOG_FILE
    RETCODE=$ERR_RC
fi
#Check Target Directory (optional) 
if [[ -n $TGT_FILE_DIR ]]; then
    if [[ -d $TGT_FILE_DIR ]]; then
        print "Valid Target Directory provided: >$TGT_FILE_DIR< "              >> $LOG_FILE
    else
        print "INVALID Target directory was provided: >$TGT_FILE_DIR<"         >> $LOG_FILE
        RETCODE=$ERR_RC
    fi
else 
    print "No Target dir provided, default of $REBATES_HOME/TgtFiles used"     >> $LOG_FILE
    TGT_FILE_DIR=$REBATES_HOME/"TgtFiles"
fi
#Check Target filename (required)
if [[ -n $TGT_FILE_NME ]]; then
    print "Target filename provided: >$TGT_FILE_NME<"                          >> $LOG_FILE
    TGT_FILE=$TGT_FILE_DIR/$TGT_FILE_NME
else
    print "Target filename not provided or cannot find file, required"         >> $LOG_FILE
    print "    Target filename provided - >$$TGT_FILE_DIR/$TGT_FILE_NME<"      >> $LOG_FILE
    RETCODE=$ERR_RC
fi

if [[ $RETCODE != 0 ]]; then
    print " "                                                                  >> $LOG_FILE
    help_Usage
    print " "                                                                  >> $LOG_FILE
    exit_Script $RETCODE "An error was found (above) causing this script to abort"
fi

print " "                                                                      >> $LOG_FILE
print "Script parameters accepted, continuing"                                 >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

}

#--------------------------------------------------------------------------------------------------------------------------#
#                                        Function to compress file                                                         #
#--------------------------------------------------------------------------------------------------------------------------#

function file_Compress
{

print "Script being used to compress the file $SRC_FILE into $TGT_FILE"        >> $LOG_FILE
print " "                                                                      >> $LOG_FILE


# execute the gzip command
#option 'c' pipes the compressed file into the desired filename
#option 'f' forces the overrite of the target filename if it already exists
`gzip -cf $SRC_FILE > $TGT_FILE`                                               >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]];then
    print "The gzip command failed"                                            >> $LOG_FILE
    #show that the file is not valid
    gzip -tl $TGT_FILE                                                         >> $LOG_FILE
    exit_Script $RETCODE "An error occurred during the compression"            >> $LOG_FILE
fi

#test the renamed file for integrity
#note that when testing compressed file integrity, it does not have to end in .gz
#option 't' tests the integrity of the compressed file
#option 'l' lists the contents
#option 'N' lists the full name with file extension
gzip -tlN $TGT_FILE                                                            >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print " "                                                                  >> $LOG_FILE
    exit_Script $RETCODE "The renamed gzip file integrity failed"              >> $LOG_FILE
fi

print " "                                                                      >> $LOG_FILE
print "Completed compression"                                                  >> $LOG_FILE

}

#--------------------------------------------------------------------------------------------------------------------------#
#                                        Function to uncompress file                                                       #
#--------------------------------------------------------------------------------------------------------------------------#

function file_Uncompress
{

print "Script being used to uncompress the file $SRC_FILE"                     >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

SRC_ZIP_FILE_EXT=$(echo $SRC_FILE|awk -F. '{print $2}')

#find the name of the file that is inside the compressed file
ZIP_FLE_CONTENTS=$ORIG_ZIP_FILE_NME"_contents.txt"
ZIP_FLE_LIST=$ORIG_ZIP_FILE_NME"_list.txt"

#option 'l' lists the contents
#option 'N' lists the full name with file extension (required for renaming)
gzip -lN $SRC_FILE > $ZIP_FLE_LIST

RETCODE=$?

if [[ $RETCODE != 0 ]];then
    print "The gzip file is not a valid compressed file"                       >> $LOG_FILE
    #rename the temporary zip file back to original name
    exit_Script $RETCODE "An error occurred during the uncompress command"     >> $LOG_FILE
fi

#turn the 2 lines of output from the prior gzip list command into one line of data for reading
paste -s -d"\t\n" $ZIP_FLE_LIST > $ZIP_FLE_CONTENTS

#read the ZIP_FLE_CONTENTS, skipping irrelevant data until the filename
read a b c d e f g ORIG_ASCII_FILENAME < $ZIP_FLE_CONTENTS

# execute the gzip command
#option 'd' uncompresses, option 'N' saves the full name with file extension
gzip -fdNS ".$SRC_ZIP_FILE_EXT" $SRC_FILE                                      >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]];then
    print "The gzip command failed"                                            >> $LOG_FILE
    #rename the temporary zip file back to original name
    exit_Script $RETCODE "An error occurred during the uncompress command"     >> $LOG_FILE
fi

if [[ $ORIG_ASCII_FILENAME != $TGT_FILE ]];then
    #the ascii file stored in the zip file is not hte name we need it to be for the next process.
    mv $ORIG_ASCII_FILENAME $TGT_FILE                                          >> $LOG_FILE
fi

print " "                                                                      >> $LOG_FILE
print "Completed uncompress"                                                   >> $LOG_FILE

#cleanup working files
rm -f $ZIP_FLE_CONTENTS
rm -f $ZIP_FLE_LIST

}

#####################################################################################################################################
#                                    Begin Common SFTP script Processing                                                            #
#####################################################################################################################################

ERR_RC=1
SCRIPTNAME=$(basename "$0")

while getopts a:d:s:D:t:h opt
do
    case $opt in
        a)
            export ACTN_IND=$OPTARG
            ;;
        d)
            export SRC_FILE_DIR=$OPTARG
            ;;
        s)
            export SRC_FILE_NME=$OPTARG
            ;;
        D)
            export TGT_FILE_DIR=$OPTARG
            ;;
        t)
            export TGT_FILE_NME=$OPTARG
            ;;
        h)
        print "h"
            help_Usage
            exit_Script 0
            ;;
        *)
        print "*"
            help_Usage
            exit_Script $ERR_RC "Incorrect arguments passed"
            ;;
    esac
done

LOG=$(echo $SCRIPTNAME|awk -F. '{print $1}')"_$TGT_FILE_NME.log"
LOG_FILE="$LOG_DIR/$LOG"
ARCH_LOGFILE=$ARCH_LOG_DIR/$LOG`date +%Y%j%H%M%S`

print " "                                                                      >> $LOG_FILE
print " ------ Starting script execution  $SCRIPTNAME `date` ------"           >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

print "ACTN_IND=>$ACTN_IND<"                                                   >> $LOG_FILE
print "SRC_FILE_DIR=>$SRC_FILE_DIR<"                                           >> $LOG_FILE
print "SRC_FILE_NME=>$SRC_FILE_NME<"                                           >> $LOG_FILE
print "TGT_FILE_DIR=>$TGT_FILE_DIR<"                                           >> $LOG_FILE
print "TGT_FILE_NME=>$TGT_FILE_NME<"                                           >> $LOG_FILE

# Check the input parameter values

validate_Params

#take the appropriate action based on the action indicator
if [[ $ACTN_IND == 'c' || $ACTN_IND == 'C' ]];then
    file_Compress
elif [[ $ACTN_IND == 'u' || $ACTN_IND == 'U' ]];then
        file_Uncompress
    else
        print " "                                                              >> $LOG_FILE
        print "Action indicator required to be c for compress "                >> $LOG_FILE
        print "  or u for uncompress.  Value passed was >$ACTN_IND<"           >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        exit_Script ERR_RC "Invalid action indicator passed"     
fi

exit_Script $RETCODE "Complete"
