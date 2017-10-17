#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
# Script        : Common_UDB_DML_Execution.ksh
# Description   : This script will execute SQL statments present 
#                 in a file (passed as argument) 
#                 and executes it in database passed by user (as an argument)  
#                 
#
# Parameters    : Below mentioned parameters 
#        -d Directory : Path relative to $REBATES_HOME
#        -f filename  : File name (with extension if any) containing DML statements 
#                       SQL statements needs to delimted by semi-colon i.e ';' 
#        -D database  : Database name where DML needs to be executed.
#                       RPSDM, GDX or TRBI (in capital letters)
#
# Output        : Log file as $LOG_DIR/$LOG_FILE,
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
# Date       User ID     Description
#----------  --------    -------------------------------------------------#
# 06-16-14   qcpi733     Added logic to allow for trigger filename to be 
#                        passed in and removed
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
   EMAIL_SUBJECT=$SCRIPTNAME" Abended In "$REGION" "`date`

   if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
   fi

   {
        print " "
        print $ERROR
        print " "
        print " !!! Aborting !!!"
        print " "
        print "Return_code = " $RETCODE
        print " "
        print " ------ Ending script " $SCRIPT `date`
   }                                                                           >> $LOG_FILE

   mailx -s "$EMAIL_SUBJECT" $TO_MAIL < $LOG_FILE
   cp -f $LOG_FILE $LOG_FILE_ARCH
   exit $RETCODE

}

#-------------------------------------------------------------------------#
# Function to exit the script on Success
#-------------------------------------------------------------------------#
function exit_success {

    #-------------------------------------------------------------------------#
    # remove trigger file, execute if the trg_file length is not zero
    #-------------------------------------------------------------------------#
    if [[ -n ${trg_file} ]];
        then
            rm -f $REBATES_HOME/${directory}/${trg_file}
            print " "                                                                                      >> $LOG_FILE
            print "Script removed trigger file $REBATES_HOME/${directory}/${trg_file}"                     >> $LOG_FILE
            print " "                                                                                      >> $LOG_FILE
    fi

    print "********************************************"                       >> $LOG_FILE
    print "....Completed executing " $SCRIPTNAME " ...."                       >> $LOG_FILE
    print `date +"%D %r %Z"`                                                   >> $LOG_FILE
    print "********************************************"                       >> $LOG_FILE

    #-------------------------------------------------------------------------#
    # move log file to archive with timestamp
    #-------------------------------------------------------------------------#
    SQL_FILE_ARCH="${OUTPUT_DIR}/$sql_file"`date +"%Y%m%d_%H%M%S"`
    mv -f $REBATES_HOME/${directory}/${sql_file} $SQL_FILE_ARCH
    mv -f $LOG_FILE $LOG_FILE_ARCH

    exit 0
}  

#-------------------------------------------------------------------------#
# Main processing starts here
#-------------------------------------------------------------------------#

# Variables and temp files
RETCODE=0
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
SCRIPTNAME=$FILE_BASE".ksh"

# LOG FILES
LOG_FILE_ARCH="${ARCH_LOG_DIR}/${FILE_BASE}.log"`date +"%Y%m%d_%H%M%S"`
LOG_FILE="${LOG_DIR}/${FILE_BASE}.log"

#removing log file
rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
   {
      print "********************************************"
      print "Starting the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "********************************************"
   }                                                                           > $LOG_FILE
  
# Assign values to variable from arguments passed
while getopts d:f:D:t: argument
do
      case $argument in
          d)directory=$OPTARG;;
          f)sql_file=$OPTARG;;
          D)database=$OPTARG;;
          t)trg_file=$OPTARG;;
          *)
            echo "\n Usage: $SCRIPTNAME -d <Direcotry > -f <file Name> -D <database>"                      >> $LOG_FILE
            echo "\n Example: $SCRIPTNAME -d TgtFiles -f Common_UDB_Data_purge_process_RPSDM.txt -D RPSDM" >> $LOG_FILE
            echo "\n -d <directory> Relative directory path i.e. relative to $REBATES_HOME"                >> $LOG_FILE
            echo "\n -f <SQL File> File containing SQl statements"                                         >> $LOG_FILE
            echo "\n -D <Database> Database Name where SQL needs to be executed"                           >> $LOG_FILE
            echo "\n -t <Trigger file> Trigger file that needs to be removed, same location as sql file"   >> $LOG_FILE
            exit_error ${RETCODE} "Incorrect arguments passed"
            ;;
      esac
done

print " "                                                                                                  >> $LOG_FILE
print " Parameters passed for current run"                                                                 >> $LOG_FILE
print " Directory path passed     : ${directory}"                                                          >> $LOG_FILE
print " SQL File Name             : ${sql_file}"                                                           >> $LOG_FILE
print " Database Name             : ${database}"                                                           >> $LOG_FILE
print " Trigger file (optional)   : ${trg_file}"                                                           >> $LOG_FILE
print " "                                                                                                  >> $LOG_FILE
      
if [[ $directory = '' || $sql_file = '' || $database = '' ]]; then
      RETCODE=1
      echo "\n Usage: $SCRIPTNAME -d <Direcotry > -f <file Name> -D <database>"                            >> $LOG_FILE
      echo "\n Example: $SCRIPTNAME -d TgtFiles -f Common_UDB_Data_purge_process_RPSDM.txt -D RPSDM"       >> $LOG_FILE
      echo "\n -d <directory> Relative directory path i.e. relative to $REBATES_HOME"                      >> $LOG_FILE
      echo "\n -f <SQL File> File containing SQl statements"                                               >> $LOG_FILE
      echo "\n -D <Database> Database Name where SQL needs to be executed"                                 >> $LOG_FILE
      echo "\n -t <Trigger file> Trigger file that needs to be removed, same location as sql file"         >> $LOG_FILE

      exit_error ${RETCODE} "Incorrect arguments passed"
fi


#-------------------------------------------------------------------------#
# Check if SQL file is present or not
#-------------------------------------------------------------------------#
if [[ -f $REBATES_HOME/${directory}/${sql_file} ]]
then
      print "$SCRIPTNAME will process SQL statements present in $REBATES_HOME/${directory}/${sql_file} "   >> $LOG_FILE
else
      exit_error $RETCODE "SQL File - ${sql_file} does not exist."  
fi

#-------------------------------------------------------------------------#
# Check if SQL file contains some data or it is empty
#-------------------------------------------------------------------------#
if [[ -s $REBATES_HOME/${directory}/${sql_file} ]]
then
      print " "                                                                                            >> $LOG_FILE
else 
      RETCODE=0
      print "SQL file $REBATES_HOME/${directory}/${sql_file} is empty. "                                   >> $LOG_FILE
      print "No SQL statement/s to process so completing the script execution"                             >> $LOG_FILE
      exit_success 
fi

#-------------------------------------------------------------------------#
# Read database, user id and password based on database name
#-------------------------------------------------------------------------#
case $database in
    "RPSDM" )
        read DATABASE CONNECT_ID CONNECT_PWD < $SCRIPTS_DIR/.connect/.rpsdm_connect.txt
        ;;
    "GDX" )
        read DATABASE CONNECT_ID CONNECT_PWD < $SCRIPTS_DIR/.connect/.db_connect.txt
        ;;
    "TRBI" )
        read DATABASE CONNECT_ID CONNECT_PWD < $SCRIPTS_DIR/.connect/.trbi_connect.txt
        ;;
    * )
        RETCODE=1
        exit_error $RETCODE "Incorrect database name - $database. Enter RPSDM or GDX or TRBI in caps"  
        ;;
esac

#-------------------------------------------------------------------------#
# Connect to UDB.
#-------------------------------------------------------------------------#
print " "                                                                      >> $LOG_FILE
db2 -p connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD                >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   exit_error $RETCODE "Unable to connect to database $DATABASE with $CONNECT_ID"
fi

#-------------------------------------------------------------------------#
# Execute the SQL statements stored in SQL file.
# SQL statements present needs to be delimited with semi-colon i.e. ';'
#-------------------------------------------------------------------------#
db2 -tf $REBATES_HOME/${directory}/$sql_file                                   >> $LOG_FILE
RETCODE=$?

#-------------------------------------------------------------------------#
# Db2 command return codes
# 0 DB2® command or SQL statement executed successfully
# 1 SELECT or FETCH statement returned no rows
# 2 DB2 command or SQL statement warning
# 4 DB2 command or SQL statement error
# 8 Command line processor system error
# 
# Script will fail if return code is greater than 1
#-------------------------------------------------------------------------#
if [[ $RETCODE > 1 ]]; then
    exit_error $RETCODE "Error executing SQL statements present in $REBATES_HOME/${directory}/$sql_file "
fi

#-------------------------------------------------------------------------#
# Disconnect form udb
#-------------------------------------------------------------------------#
db2 -stvx connect reset
db2 -stvx quit
RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    exit_error $RETCODE "Error while disconnecting from Database"
else 
    exit_success 
fi

#-------------------------------------------------------------------------#
# End of script
#-------------------------------------------------------------------------#

