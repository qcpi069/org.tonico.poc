#!/usr/bin/ksh

#############################################################################
#SCRIPT NAME : DFO_compress_file.ksh                                        #
#                                                                           #
#CALLED BY   : DFO_process_new_automate.ksh                                 #
#                                                                           #
#PURPOSE     : To free space from the file system since DFO process is      #
#              designed to be piggish...worse case scenario, compression    #
#              can be replaced with deletes of these files.  They are kept  #
#              around for logging and ease of problem resolution.           #
#									    #
#INSTRUCTIONS: This script takes one command line argument, FILE_NAME.      #
#              Compress the passed file and report of any problems.         #
#                                                                           #
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
#  1.0        William Price  12/25/2003  Initial Release                    #
#                                                                           #
#############################################################################
#EXPORTS AND VARS#
export SCRIPT_NAME="DFO_compress_file.ksh"

export HOME_DIR="/vradfo/prod"
export REF_DIR="$HOME_DIR/control/reffile"
export SUPPORT_MAIL_LIST_FILE="$REF_DIR/DFO_support_maillist.ref"
export MAILFILE="/vradfo/test/error_mail_body"
FILE_NAME=$1
echo "file to be compressed: " $FILE_NAME
#================================================
#ACCEPTS ONE COMMAND LINE PARAMETER.
#================================================

  if [[ $# != 1 ]] then
     echo "Usage DFO_compress_file.ksh <FILE_NAME (fully qualified)>"
     exit 1
  fi

compress $FILE_NAME
RTN_CD=$?

if [[ $RTN_CD != 0 ]]
 then
   echo "$FILE_NAME could not be compressed. error code: $RTN_CD "
   echo "Script: $SCRIPT_NAME"              \
        "\nProcessing for $CLIENT_NAME"     \
        "\nError: $FILE_NAME "              \
        "\nhad problems being compressed. " \
        " error code $RTN_CD. " > $MAILFILE
   export MAIL_SUBJECT="DFO: $SCRIPT_NAME ERROR"
   $SCRIPT_DIR/mailto_IS_group.ksh
fi
