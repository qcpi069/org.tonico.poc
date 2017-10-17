#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : Common_UDB_DML_Creation.ksh
#
# Description   : This script will read entires stored in Rebates Purge Rule
#                 and Rebates Purge Event table. Then prepares set of DML entires 
#                 and stores them in a SQL file. 
#
# Parameters    :  
#                 -d database  i.e. Database name
#
# Output        : Log file as $LOG_FILE
#                 $REBATES_HOME/TgtFiles/
#
# Input Files   : None
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
# Date       User ID     Description
#----------  --------    -------------------------------------------------#
# 06-16-14   qcpi733     Added logic to create the JOB_TRIGGER_FILE
# 03-21-14   qcpuk218    Initial Creation 
#                        ITPR005898 State of NY - Rebates Payment
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

   if [[ -z "$RETCODE" || "$RETCODE" == 0 ]]; then
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
   }    >> $LOG_FILE

   mailx -s "$EMAIL_SUBJECT" $TO_MAIL                        < $LOG_FILE
   cp -f $LOG_FILE $LOG_FILE_ARCH
   exit $RETCODE
}

#-------------------------------------------------------------------------#
# Function to connect to DB2 
#-------------------------------------------------------------------------#
function connect_DB2 {

   database=$1   
   
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

   db2 -p connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD             >> $LOG_FILE 

   RETCODE=$?

   if [[ $RETCODE != 0 ]]; then
      print "Error: couldn't connect to database " $SCRIPTNAME " ...        "  >> $LOG_FILE
      print "Return code is : <" $RETCODE ">"                                  >> $LOG_FILE
      exit_error $RETCODE "Unable to connect to database $DATABASE with $CONNECT_ID"
   fi

}

#-------------------------------------------------------------------------#
# Function to connect to DB2 
#-------------------------------------------------------------------------#
function disconnect_DB2 {

   # Disconnect form udb
   db2 -stvx connect reset
   db2 -stvx quit

}


#-------------------------------------------------------------------------#
# Function to exit the script on success
#-------------------------------------------------------------------------#
function exit_success {

   # Finishing script
   print "********************************************"                        >> $LOG_FILE
   print "Finishing the script $SCRIPTNAME ......"                             >> $LOG_FILE
   print `date +"%D %r %Z"`                                                    >> $LOG_FILE
   print "Final return code is : <" $RETCODE ">"                               >> $LOG_FILE
   print " "                                                                   >> $LOG_FILE

   #-------------------------------------------------------------------------#
   # move log file to archive with timestamp
   #-------------------------------------------------------------------------#
   mv -f $LOG_FILE $LOG_FILE_ARCH
   
   exit 0
}


#-------------------------------------------------------------------------#
# Function to calculate frequency based on total count and block size 
#-------------------------------------------------------------------------#
function calculateFrequency {

    row_cnt=$1            # Total number of records to be deleted
    block_size=$2         # Block size i.e. number of records allowed to be deleted at a time. 
    
    # Calculate remainder of total records divided by block size 
    # i.e. if total records = 100 and block size = 10 then Modulo = 0
    #      if total records = 7 and block size = 2 then Modulo = 1        
    modulo=`expr  $row_cnt % $block_size`

    # Calculate quotient of total records divided by block size 
    # i.e. if total records = 500 and block size = 10 then quotient = 50
    #      if total records = 7 and block size = 2 then quotient = 3 
    quotient=`expr  $row_cnt / $block_size`

    # Calculate the frequency based on module value. 
    # If module is non zero then frequency is quotient + 1 else is equal to quotient
    # if total records = 500 and block size = 10 then frequency = 50
    # if total records = 7 and block size = 2 then frequency = 3 + 1 = 4
    if [ $modulo = 0 ]
    then 
       frequency=$quotient
    else
       frequency=`expr $quotient + 1`
    fi
    
    export frequency
    print " "                                                                  >> $LOG_FILE
    print "Number of blocks : $frequency"                                      >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
}

#-------------------------------------------------------------------------#
# Function to Read Purge and Event Tables 
# Read records from Purge rule and event table where 
#  TBL_STRTR_CD = 2 i.e.Table Structure code is Non partiotioned
#  PURG_ACTN_CD = Pending i.e. pending for processing
#-------------------------------------------------------------------------#

function read_Purge_Rule_And_Event_Table {

    print " "                                                       >> $LOG_FILE
    print " Read Rebates Purge Rule and Rebates Purge Event Table " >> $LOG_FILE
    
    SQL="SELECT SCHEMA_NM,
           TBL_NM,
           ACTN_COL_NM,
           REPLACE(PURG_RANGE_HIGH_VAL_TX, ' ', '~'),
           REPLACE(PURG_RANGE_LOW_VAL_TX, ' ', '~'),
           COALESCE(ROW_INCRMT_DEL_LMT_AT,0),
           KEY_COL_NM,
           R.PURG_RULE_ID,
           REPLACE(COALESCE(ADTN_FLTR_CRTR_TX,' '), ' ', '~')
     FROM RPS.TRBAT_PURG_RULE R, RPS.TRBAT_PURG_EVNT E
     WHERE R.PURG_RULE_ID = E.PURG_RULE_ID
           AND R.TBL_STRTR_CD = 2
           AND E.PURG_ACTN_CD = 'Pending'"
      
    print " "                                              >> $LOG_FILE
    print "SQL running to find pending records : $SQL"     >> $LOG_FILE
    print " "                                              >> $LOG_FILE
    
    db2 -x $SQL > $DATA_FILE
    RETCODE=$?

    if [[ $RETCODE = 1 ]]; then
        print " "                                                                  >> $LOG_FILE
        print "No records to process. Ending the script "                          >> $LOG_FILE
        exit_success  
    fi

    if [[ $RETCODE > 1 ]]; then
        print " "                                                                  >> $LOG_FILE
        print "ERROR: Select of pending records                        "           >> $LOG_FILE
        print " "                                                                  >> $LOG_FILE
        print $SQL                                                                 >> $LOG_FILE
        print " "                                                                  >> $LOG_FILE
        print "Return code is : <" $RETCODE ">"                                    >> $LOG_FILE
        exit_error $RETCODE
    fi

} 

#-------------------------------------------------------------------------#
# Function to find total row count
#-------------------------------------------------------------------------#

function total_row_count {

    SQL="SELECT COUNT(*) FROM $SCHEMA_NM.$TBL_NM WHERE $ACTN_COL_NM BETWEEN '$LOW_VAL' AND '$HIGH_VAL' $ADTN_FLTR_CRTR"
    print " "                                                                  >> $LOG_FILE
    print "SQL running to calculate record count : $SQL"                       >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    
    db2 -x $SQL > $TEMP_SQL_RESULT_FILE
    RETCODE=$?
    
    if [[ $RETCODE = 1 ]]; then
        print " "                                                              >> $LOG_FILE
        print $SQL                                                             >> $LOG_FILE
        print "No records to delete. Block count is set to 0"                  >> $LOG_FILE
        row_cnt=0  
    fi
    
    if [[ $RETCODE > 1 ]]; then
        print " "                                                              >> $LOG_FILE
        print "ERROR: Select of row count                        "             >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print $SQL                                                             >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Return code is : <" $RETCODE ">"                                >> $LOG_FILE
        exit_error $RETCODE
    fi
    
    read row_cnt < $TEMP_SQL_RESULT_FILE

    export row_cnt

    print " "                                                                  >> $LOG_FILE
    print "Count returned: $row_cnt"                                           >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE

} 

#-------------------------------------------------------------------------#
# Function to Update PURG_ACTN_CD and PURG_ACTN_TYP_CD with .New. and 2.
#-------------------------------------------------------------------------#

function update_TRBAT_PURG_RULE_EVNT_Table {

    SQL="UPDATE RPS.TRBAT_PURG_EVNT set PURG_ACTN_CD='New', PURG_ACTN_TYP_CD= 2 WHERE PURG_RULE_ID = $PURG_RULE_ID"
    print " "                                                                  >> $LOG_FILE
    print "SQL running update type codes : $SQL"                               >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    
    db2 -x $SQL > $TEMP_SQL_RESULT_FILE
    RETCODE=$?
    
    if [[ $RETCODE > 1 ]]; then
        print " "                                                              >> $LOG_FILE
        print "ERROR: Update type codes "                                      >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print $SQL                                                             >> $LOG_FILE
        print " "                                                              >> $LOG_FILE
        print "Return code is : <" $RETCODE ">"                                >> $LOG_FILE
        exit_error $RETCODE
    fi

} 
    
#-------------------------------------------------------------------------#
# Function to write DML statements N times based
#-------------------------------------------------------------------------#
    
function write_DML_Statements {
   
   if [[ $1 == 'single' ]]; then

      echo "DELETE FROM $SCHEMA_NM.$TBL_NM WHERE $ACTN_COL_NM BETWEEN '$LOW_VAL' AND '$HIGH_VAL' $ADTN_FLTR_CRTR;" >> $SQL_DML_File
      echo "COMMIT;" >> $SQL_DML_File

   else 
      index=1
      while [[ $index -le $frequency ]]  
      do
         echo "DELETE FROM $SCHEMA_NM.$TBL_NM WHERE ($KEY_COL_NM) IN (SELECT $KEY_COL_NM FROM $SCHEMA_NM.$TBL_NM WHERE $ACTN_COL_NM BETWEEN '$LOW_VAL' AND '$HIGH_VAL' $ADTN_FLTR_CRTR FETCH FIRST $ROW_INCRMT_DEL_LMT_AT ROWS ONLY);" >> $SQL_DML_File
         echo "COMMIT;" >> $SQL_DML_File
         index=`expr $index + 1`
      done
   fi
   
   #DML statements written out, create trigger file to trigger next job
   #  Yes this will write multiple rows, but it is a trigger file.
   print "$SCRIPTNAME created this trigger file to trigger the DML execution job" >> $JOB_TRIGGER_FILE
} 

#-------------------------------------------------------------------------#
# Main processing starts here
#-------------------------------------------------------------------------#

# Set Variables
RETCODE=0
SCRIPTNAME=$(basename "$0")

# LOG FILES
LOG_ARCH_PATH=$REBATES_HOME/log/archive
LOG_FILE_ARCH=${LOG_ARCH_PATH}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE=${LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log"

#-------------------------------------------------------------------------#
# Remove old log files
#-------------------------------------------------------------------------#
rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#

print "********************************************"                           >> $LOG_FILE
print "Starting the script $SCRIPTNAME ............"                           >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE

# Assign values to variable from arguments passed
while getopts d: argument
do
      case $argument in
          d)database=$OPTARG;;
          *)
            echo "\n Usage: $SCRIPTNAME -d <databaseName>"                     >> $LOG_FILE
            echo "\n Example: $SCRIPTNAME -d RPSDM"                            >> $LOG_FILE
            echo "\n -d <Database> Database name to be used"                   >> $LOG_FILE
            exit_error ${RETCODE} "Incorrect arguments passed"
            ;;
      esac
done

print " "                                    >> $LOG_FILE
print " Parameters passed for current run "  >> $LOG_FILE
print " Database Name     : $database"       >> $LOG_FILE
print " "                                    >> $LOG_FILE
      
if [[ $database = '' ]]; then
      RETCODE=1
      echo "\n Usage: $SCRIPTNAME -d <databaseName>"                           >> $LOG_FILE
      echo "\n Example: $SCRIPTNAME -d RPSDM"                                  >> $LOG_FILE
      echo "\n -d <Database> Database name to be used (RSPDM/GDX/TRBI)"        >> $LOG_FILE
      exit_error ${RETCODE} "Incorrect arguments passed"
fi

# Connect to UDB.
connect_DB2 $database

# Setup DML files name based on database name passed
DATA_FILENAME=$OUTPUT_DIR/Data_purge_$database
#NOTE - NEVER REMOVE THIS FILE, ALWAYS APPEND TO IT, NEVER CREATE IT NEW
SQL_DML_File=$DATA_FILENAME.txt
DATA_FILE=$DATA_FILENAME.data
TEMP_SQL_RESULT_FILE=$DATA_FILENAME.tmp
JOB_TRIGGER_FILE=$DATA_FILENAME.trg

#-------------------------------------------------------------------------#
# Remove old data files
# DO NOT DELETE SQL_DML_File file. Script will append DML entries in  file
#-------------------------------------------------------------------------#
rm -f $DATA_FILE
rm -f $TEMP_SQL_RESULT_FILE

#read purge rule and event table
read_Purge_Rule_And_Event_Table

while read SCHEMA_NM TBL_NM ACTN_COL_NM PURG_RANGE_HIGH_VAL_TX PURG_RANGE_LOW_VAL_TX ROW_INCRMT_DEL_LMT_AT KEY_COL_NM PURG_RULE_ID ADTN_FLTR_CRTR_TX
do
    # Replacing temporary symbol '~' back with space. Space was converted to ~ symbol to avoid space acting as delimeter for the internal value of below variable
    
    HIGH_VAL=`echo $PURG_RANGE_HIGH_VAL_TX | sed 's/~/ /g'`  
    LOW_VAL=`echo $PURG_RANGE_LOW_VAL_TX | sed 's/~/ /g'`    
    ADTN_FLTR_CRTR=`echo $ADTN_FLTR_CRTR_TX | sed 's/~/ /g'` 
    
    print "##################################################################" >> $LOG_FILE
    print "Process started for the following record"                           >> $LOG_FILE
    print "##################################################################" >> $LOG_FILE
    print "Schema Name                         : $SCHEMA_NM"                   >> $LOG_FILE
    print "Table Name                          : $TBL_NM"                      >> $LOG_FILE
    print "Action Column Name                  : $ACTN_COL_NM"                 >> $LOG_FILE
    print "Purge Value - High Value            : $HIGH_VAL"                    >> $LOG_FILE
    print "Purge Value - High Value            : $LOW_VAL"                     >> $LOG_FILE
    print "Row Increment Delete Limit Amount   : $ROW_INCRMT_DEL_LMT_AT"       >> $LOG_FILE
    print "Additional Filtering Criteria Text  : $ADTN_FLTR_CRTR"              >> $LOG_FILE
    print "Key column name                     : $KEY_COL_NM"                  >> $LOG_FILE
    print "Purge Rule Identifier               : $PURG_RULE_ID"                >> $LOG_FILE
    
    #assign block size from RPS.TRBAT_PURG_RULE.ROW_INCRMT_DEL_LMT
    block_size=$ROW_INCRMT_DEL_LMT_AT

    if [[ $block_size = 0 ]]; then
    {
        #write single delete statement
        write_DML_Statements 'single'
    }
    else
    {
        # Find total records in database which are meeting criteria
        total_row_count 
 
        if [[ $row_cnt = 0 ]]; then
           print "No records found in the $SCHEMA_NM.$TBL_NM for processing."  >> $LOG_FILE
        else 
           #find how many time DML statements needs to be ran
           calculateFrequency $row_cnt $block_size

           #write DML statements
           write_DML_Statements 'multiple'        
        fi      

    }
    fi 

    # Update PURG_ACTN_CD and PURG_ACTN_TYP_CD with .New. and 2.
    update_TRBAT_PURG_RULE_EVNT_Table  
    
    print "##################################################################" >> $LOG_FILE
    print "Process ended for Purge Rule Identifier : $PURG_RULE_ID           " >> $LOG_FILE
    print "##################################################################" >> $LOG_FILE 
    
done < "$DATA_FILE"

exit_success

#-------------------------------------------------------------------------#
# End of Script
#-------------------------------------------------------------------------#
