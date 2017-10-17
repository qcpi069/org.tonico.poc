#!/usr/bin/ksh
#set -x
#-----------------------------------------------------------------------------------------------------------------------#
#
# Script        : Common_SFTP_Process.ksh
#
# Description   : General Purpose script to sftp below type of files
#
#                       Single file
#                       Multiple files to same server
#                       Multiple files to different server
#                       Push or pull from the sever
#                       Unix to Unix transfer (Vs)
#                       Unix to Web transport (Vs)
#                       Unix to any server . Provided we have all setups done for
#                                      access and configurations
#
# Command Line Flags:   -p <Required Parentscript>
#                       -s <Optional fully qualified source file>
#                       -t <optional fully qualified target file>
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date      User           Description
# ---------  ----------  -------------------------------------------------
#
# 06-15-15    QCPI2D6      Initial Creation for ITPR011275.
#
#-------------------------------------------------------------------------------------------------------------------------#

#-------------------------------------------------------------------------------------------------------------------------#
#                              Caremark Rebates Environment variables
#-------------------------------------------------------------------------------------------------------------------------#

  . `dirname $0`/Common_RPS_Environment.ksh

#-------------------------------------------------------------------------------------------------------------------------#
#                                       Function to exit the script
#-------------------------------------------------------------------------------------------------------------------------#
function exit_script {

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
                }                                                               >> $LOG_FILE
    else
                {
                print " "
                print ".... $SCRIPTNAME  completed with return code $RETCODE ...."
                print " "
                print " ------ Ending script $SCRIPTNAME `date` ------"
                print " "
                }                                                               >> $LOG_FILE
                mv $LOG_FILE $ARCH_LOGFILE
     fi

    exit $RETCODE
}

#--------------------------------------------------------------------------------------------------------------------------#
#                                        Function to check variables                                                       #
#--------------------------------------------------------------------------------------------------------------------------#

function Validate_script {

print " "                                                                       >> $LOG_FILE
print "Start SFTP parameter validation"                                         >> $LOG_FILE 

#Check User
                if [[ -z $SF_USER || $SF_USER == '-' ]]; then
                      exit_script ${RETCODE} "Connect User Required"
                else
                      print "  User name available"                             >> $LOG_FILE
                fi 
#Check Source File
                if [[ -z $SOURCE ]]; then
                   if [[ -z $SOURCE_FILE_TXT || $SOURCE_FILE_TXT == '-' ]]; then
                       exit_script ${RETCODE} "Source file name is required or not available"
                   else
                       FINAL_SOURCE=$SOURCE_FILE_TXT
                   fi
                else 
                   FINAL_SOURCE=$SOURCE
                fi
#Check target File
                if [[ -z $TARGET ]]; then
                   if [[ -z $TARGET_FILE_TXT || $TARGET_FILE_TXT == '-' ]]; then
                       exit_script ${RETCODE} "Target file name is required or not available"
                   else
                       FINAL_TARGET=$TARGET_FILE_TXT
                   fi
                else 
                     FINAL_TARGET=$TARGET
                fi
#Check Source Directory
                if [[ -d ${SOURCE_DIR_TXT} ]]; then
                      print "  Source Directory - ${SOURCE_DIR_TXT} "              >> $LOG_FILE
                else
                      exit_script $RETCODE "Source Directory path incorrect or not available - ${SOURCE_DIR_TXT}"
                fi
#Check Action
                if [[ -z $ACTION_TXT || $ACTION_TXT == '-' ]]; then
                      exit_script $RETCODE "Action: $ACTION_TXT is required"
                else
                      print "  Action is $ACTION_TXT "                             >> $LOG_FILE
                fi
#Check Action request
                if [[ $ACTION_TXT == 'put' ]]; then
                   if [[ -s ${SOURCE_DIR_TXT}/${FINAL_SOURCE} ]]; then
                      print "  Source File - ${SOURCE_DIR_TXT}/${FINAL_SOURCE} "   >> $LOG_FILE
                   else
                      exit_script $RETCODE "Source file is either empty or not present - ${SOURCE_DIR_TXT}/${FINAL_SOURCE}"
                   fi
                fi
#Check Target Directory
                if [[ -z ${TARGET_DIR_TXT} || ${TARGET_DIR_TXT} == '-' ]]; then
                      exit_script $RETCODE "Target Directory path required"
                else
                      print "  Target Directory - ${TARGET_DIR_TXT} "              >> $LOG_FILE
                fi
#Check Archive Directory
                if [[ -z $ARCHIVE_DIR_TXT || $ARCHIVE_DIR_TXT == '-' ]]; then
                      print "  Archival Directory is not passed so file won't be archived on succesful SFTP tranfer " >> $LOG_FILE
                else
                      if [[ -d ${ARCHIVE_DIR_TXT} ]]; then
                           print "  Archival Directory - ${ARCHIVE_DIR_TXT} "      >> $LOG_FILE
                           # It will just bulid the Archive command file since every records have flag set for Archive #                          
                           print "mv ${SOURCE_DIR_TXT}/$FINAL_SOURCE $ARCHIVE_DIR_TXT/$FINAL_SOURCE.`date +"%Y%j%H%M%S"`" >> $ARCH_OPTION_FILE                     
                      else
                            exit_script $RETCODE " Archive Directory path incorrect ${ARCHIVE_DIR_TXT}"
                      fi
                fi
print "End SFTP parameter validation"                                              >> $LOG_FILE
}

#--------------------------------------------------------------------------------------------------------------------------------------#
#                                    Function to get the hostname                                                                      #
#--------------------------------------------------------------------------------------------------------------------------------------#

function get_hostname {
print " "                                                                          >> $LOG_FILE
print "Getting the hostname from Environment script"                               >> $LOG_FILE
                if [[ -z $TARGET_HOST_TXT || $TARGET_HOST_TXT == '-' ]];then
                      exit_script ${RETCODE} "Target Hostname required in the UNIX_SFTP_CONFIG table for $PARENTNAME"
                else
                    case $TARGET_HOST_TXT in
                        RPSDM)
                            HOSTNAME=$RPSDM_APPL_DB_SERVER_NM
                            ;;
                        GDX)
                            HOSTNAME=$GDX_APPL_DB_SERVER_NM
                            ;;
                        WEBT)
                            HOSTNAME=$SFTP_SERVER
                            ;;
                        ETL)
                            HOSTNAME=$APPL_ETL_SERVER_NM
                            ;;
                        *)
                            HOSTNAME=$TARGET_HOST_TXT
                            ;;
                    esac
                fi
}

#####################################################################################################################################
#                                    Begin Common SFTP script Processing                                                            #
#####################################################################################################################################

SCRIPTNAME=$(basename "$0")

RETCODE=1
SFTP_RETURN_CODE=0
while getopts p:s:t: opt
do
    case $opt in
        p)
            PARENTNAME_TMP=$OPTARG
            ;;
        s)
            SOURCE=$OPTARG
            ;;
        t)
            TARGET=$OPTARG
            ;;
        *)
            echo "Usage: $SCRIPTNAME -p  [-s] [-t]"
            echo "Example: $SCRIPTNAME -p common_script -s fake_file -t fake_file"
            echo "-p <Parentname>   Required paramater. The parentscript name we call to pull the information from base table"
            echo "-s <source file> Optional. The file to be transfered"
            echo "-t <target file> Optional. The target file name"
            exit_script ${RETCODE} "Incorrect arguments passed"
            ;;
        esac
    done

# Change parent name to uppercase
PARENTNAME=`echo ${PARENTNAME_TMP} | tr '[a-z]' '[A-Z]'`

LOG=${PARENTNAME}"_SFTP".log
LOG_FILE="$LOG_DIR/$LOG"
ARCH_LOGFILE="$ARCH_LOG_DIR/${PARENTNAME}"_SFTP_"`date +"%Y%j%H%M%S"`.log"

print " "                                                                        >> $LOG_FILE
print " ------ Starting script execution  $SCRIPTNAME `date` ------"             >> $LOG_FILE
print " "                                                                        >> $LOG_FILE

# Check the variables

if [[ -z $PARENTNAME ]];then
    print "PARENTNAME is required! see usage: $SCRIPTNAME -H"                    >> $LOG_FILE
    print " "                                                                    >> $LOG_FILE
    exit_script ${RETCODE} "-p Parent script name is required"
fi

SFTP_CMD=${PARENTNAME}"_SFTP_"`date +"%Y%j%H%M%S"`.sftpcmds
SFTP_CMD_FILE="$LOG_DIR/$SFTP_CMD"

rm -f $SFTP_CMD_FILE

export query="Select decode(ltrim(rtrim(TARGET_HOST_TXT)),'',null,ltrim(rtrim(TARGET_HOST_TXT))), 
       decode(ltrim(rtrim(APPL_ID_TXT)),'',null,ltrim(rtrim(APPL_ID_TXT))),
       decode(ltrim(rtrim(SOURCE_DIR_TXT)),'',null,ltrim(rtrim(SOURCE_DIR_TXT))),
       decode(ltrim(rtrim(SOURCE_FILE_TXT)),'',null,ltrim(rtrim(SOURCE_FILE_TXT))),
       decode(ltrim(rtrim(TARGET_DIR_TXT)),'',null,ltrim(rtrim(TARGET_DIR_TXT))),
       decode(ltrim(rtrim(TARGET_FILE_TXT)),'',null,ltrim(rtrim(TARGET_FILE_TXT))),
       decode(ltrim(rtrim(lower(ACTION_TXT))),'',null,ltrim(rtrim(lower(ACTION_TXT)))),
       decode(ltrim(rtrim(ARCHIVE_DIR_TXT)),'',null,ltrim(rtrim(ARCHIVE_DIR_TXT))),
       decode(ltrim(rtrim(ADDTL_CMD_TXT)),'',null,ltrim(rtrim(ADDTL_CMD_TXT))) 
From $APPL_SCHEMA_NM.UNIX_SFTP_CONFIG
Where coalesce(ROW_ACTV_IND,1)=1 and upper(PARENT_PRCS_TXT) ='$PARENTNAME'
order by PARENT_PRCS_TXT,TARGET_HOST_TXT,SFTP_KEY_GID ;"

ID_FILE=$LOG_DIR/${PARENTNAME}_SFTP_id_file_`date +"%Y%j%H%M%S"`.txt

ARCH_OPTION_FILE=$LOG_DIR/${PARENTNAME}_SFTP_archfile_`date +"%Y%j%H%M%S"`.txt

print "Connecting to UDB "                                                       >> $LOG_FILE
db2 -p "connect to $DB user $C_ID using $C_PWD"

SQL_CNT_RC=$?

if [[ $SQL_CNT_RC != 0 ]]; then
    print "aborting script - cant connect to udb "                               >> $LOG_FILE
    print " "                                                                    >> $LOG_FILE
    exit_script $SQL_CNT_RC "cant connect to udb"
 fi

db2 -stxw $query >$ID_FILE

SQL_ERROR_RC=$?

    print " "                                                                   >> $LOG_FILE
    print "Disconnect from UDB"                                                 >> $LOG_FILE 
    db2 -stvx connect reset
    db2 -stvx quit

 if [[ $SQL_ERROR_RC != 0 ]]; then
    print "aborting script - Error executing query "                             >> $LOG_FILE
    print $query                                                                 >> $LOG_FILE
    print " "                                                                    >> $LOG_FILE
    rm -f $ID_FILE
    exit_script $SQL_ERROR_RC "Error executing query"
 fi


########################################################################################################################################
#                                            Read the SFTP variables                                                                   #
########################################################################################################################################

HOSTNAME_PREV=""
let LOOP_CNT=0

SFTP_LOG_FILE=$LOG_DIR/${PARENTNAME}_SFTP_LOG.txt.`date +"%Y%j%H%M%S"`

while read TARGET_HOST_TXT SF_USER SOURCE_DIR_TXT SOURCE_FILE_TXT TARGET_DIR_TXT TARGET_FILE_TXT ACTION_TXT ARCHIVE_DIR_TXT ADDTL_CMD_TXT 
do

# Need the SF_USER value to be available outside the loop

export SF_USER_FINAL=$SF_USER

########################################################################################################################################
#                                           Bulid SFTP command file and execute                                                        #
########################################################################################################################################

# This is checking to see if the next record is present 

get_hostname

# Checking to see if HOSTNAME change from previous record 

if [[ $HOSTNAME_PREV == $HOSTNAME ]]; then
    print "same host"                                                                >> $LOG_FILE
else
# Execute previous HOST SFTP command file when there is another HOST found for the same parent
    if [[ $LOOP_CNT > 0 ]]; then
        print "quit"                                                                 >> $SFTP_CMD_FILE
        sftp -b $SFTP_CMD_FILE $PREV_USER@$PREV_HOST                                 >> $SFTP_LOG_FILE
        SFTP_RETURN_CODE=$?
        if [[ $SFTP_RETURN_CODE != 0 ]]; then
           print "SFTP Errored out with return code $SFTP_RETURN_CODE"               >> $SFTP_LOG_FILE
        fi
        print " "                                                                    >> $LOG_FILE
        print "Writing SFTP command into log file"                                   >> $LOG_FILE        
        cat $SFTP_CMD_FILE                                                           >> $LOG_FILE
        print " "                                                                    >> $LOG_FILE
        rm -f $SFTP_CMD_FILE
    fi

    # Hostname changed disconnect previous host and connect to next host 
    
    HOSTNAME_PREV=$HOSTNAME
fi
#######################################################################################################################################
#                                           Check SFTP variables                                                                      #
#######################################################################################################################################

Validate_script

 if [[ ! -z $ADDTL_CMD_TXT || $ADDTL_CMD_TXT != '-' ]]; then
        print $ADDTL_CMD_TXT >> $SFTP_CMD_FILE
 fi

 if [[ $ACTION_TXT == 'get' ]];then
        print "$ACTION_TXT $TARGET_DIR_TXT/$FINAL_TARGET $SOURCE_DIR_TXT/$FINAL_SOURCE" >> $SFTP_CMD_FILE
 else
        print "$ACTION_TXT $SOURCE_DIR_TXT/$FINAL_SOURCE $TARGET_DIR_TXT/$FINAL_TARGET" >> $SFTP_CMD_FILE
 fi

LOOP_CNT=`expr $LOOP_CNT + 1`

# Assign previous loop value to connect if next loop value is different host

PREV_HOST=$HOSTNAME
PREV_USER=$SF_USER_FINAL

done < $ID_FILE

# Execute SFTP command when there is command file available with previous run return code is 0

if [[ -s $SFTP_CMD_FILE && $SFTP_RETURN_CODE == 0 ]]; then
    print "quit"                                                               >> $SFTP_CMD_FILE
    sftp -b $SFTP_CMD_FILE $SF_USER_FINAL@$HOSTNAME                            >> $SFTP_LOG_FILE
    SFTP_RETURN_CODE=$?
    if [[ $SFTP_RETURN_CODE != 0 ]]; then
        print "SFTP Errored out with return code $SFTP_RETURN_CODE" 					 >> $SFTP_LOG_FILE
    fi
    print " "                                                                  >> $LOG_FILE 
    print "Writing SFTP command into log file"                                 >> $LOG_FILE   
    cat $SFTP_CMD_FILE                                                         >> $LOG_FILE
    rm -f $SFTP_CMD_FILE
fi

########################################################################################################################################
#                                          End of SFTP command execution                                                               #
########################################################################################################################################

print "Printing SFTP log into main log file"                                     >> $LOG_FILE
print " "                                                                        >> $LOG_FILE
cat $SFTP_LOG_FILE                                                               >> $LOG_FILE

# write the error msg from the SFTP run into a variable and check for any error

SFTP_RETURN_CODE=`more $SFTP_LOG_FILE | grep -E "SFTP Errored out|No such file or directory|not found.|Could not resolve|password:" | wc -l`

if [[ $SFTP_RETURN_CODE -eq 0 ]]; then
      print " "                                                                  >> $LOG_FILE     
      print "File Transfer is Successful ...."                                   >> $LOG_FILE
      print " "                                                                  >> $LOG_FILE
      if [[ -s $ARCH_OPTION_FILE ]]; then  
      print "Archive file content"                                               >> $LOG_FILE
      cat $ARCH_OPTION_FILE                                                      >> $LOG_FILE
      #                 Run Archive move command                     #
      chmod 755 $ARCH_OPTION_FILE
      $ARCH_OPTION_FILE 
      if [[ $? = 0 ]]; then
      print "Archive successful"                                                 >> $LOG_FILE
      print " "                                                                  >> $LOG_FILE
      rm -f $ARCH_OPTION_FILE
      else
            exit_script $ARCH_RETURN_CODE "Archive Failed"
      fi
      fi
else
      exit_script $SFTP_RETURN_CODE "SFTP Command Failed"
fi

rm -f $ID_FILE
rm -f $SFTP_LOG_FILE

RETCODE=$?
exit_script $RETCODE "Complete"
