#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : GDX_GD_1011J_prctr_xref_load.ksh
# Title         :
#
# Description   : Populate the DEA to NPI prctr xref table 
#
# Maestro Job   : GDDY0010
#
# Parameters    : N/A  
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE,
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
#  
# 04-21-08   N Tucker     Initial Creation
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

  . `dirname $0`/Common_GDX_Environment.ksh

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

function exit_error {
    RETCODE=$1
    EMAILPARM4='  '
    EMAILPARM5='  '

    if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
    fi

    {
        print 'Sending email notification with the following parameters'

        print "JOBNAME is $JOBNAME"
        print "SCRIPTNAME is $SCRIPTNAME"
        print "LOG_FILE is $LOG_FILE"
        print "EMAILPARM4 is $EMAILPARM4"
        print "EMAILPARM5 is $EMAILPARM5"

        print '****** end of email parameters ******'
    }                                                                          >> $LOG_FILE

    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...."                                     >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH.`date +'%Y%j%H%M'`
    exit $RETCODE
}
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Function to Reload the tprct_npi_xref table
#-------------------------------------------------------------------------#
function reload_NPI {

   sql="import from $EXPORT_FILE of DEL
           commitcount 5000 messages "$DB2_MSG_FILE"
           replace into VRAP.TPRCT_NPI_XREF"
   echo "$sql"                                                                 >>$LOG_FILE
   sql=$(echo "$sql" | tr '\n' ' ')
   db2 -px "$sql"                                                              >>$LOG_FILE
   RETCODE=$?
print 'reload table tprct_npi_xref RETCODE=<'$RETCODE'>'>> $LOG_FILE

print "-------------------------------------------------------------------"    >>$LOG_FILE

if [[ $RETCODE != 0 ]]; then
        print "ERROR: having problem to recover table from export file ....."  >> $LOG_FILE
        return 1
else
        print "Having problem with import. Reloaded table with backup......"  >> $LOG_FILE
        return 0
fi

}
#-------------------------------------------------------------------------#


if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        SYSTEM="QA"
        export ALTER_EMAIL_TO_ADDY=""
        EMAIL_FROM_ADDY="GDXITD@caremark.com"
        EMAIL_TO_ADDY="GDXITD@caremark.com"
    else
        # Running in Prod region
        SYSTEM="PRODUCTION"
        export ALTER_EMAIL_TO_ADDY=""
        EMAIL_FROM_ADDY="GDXITD@caremark.com"
        EMAIL_TO_ADDY="GDXITD@caremark.com"
    fi
else
    # Running in Development region
    SYSTEM="DEVELOPMENT"
    export ALTER_EMAIL_TO_ADDY="nick.tucker@caremark.com"
    EMAIL_FROM_ADDY=$ALTER_EMAIL_TO_ADDY
fi

# Variables
RETCODE=0
JOBNAME="GD_1011J"
SCHEDULE="GDDY0010"

FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
SCRIPTNAME=$FILE_BASE".ksh"
COUNT_FILE=$OUTPUT_PATH/$FILE_BASE"_count.dat"

# LOG FILES
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}_${MODEL}.log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE="${LOG_PATH}/${FILE_BASE}.log"

DB2_MSG_FILE=$LOG_FILE.load
EXPORT_FILE=$GDX_PATH/input/GDX_unload_tprct_npi_xref.bkp

rm -f $LOG_FILE
rm -f $COUNT_FILE
rm -f $DB2_MSG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
   {
      print "Starting the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "********************************************"
   } > $LOG_FILE


#-------------------------------------------------------------------------#
# Connect to UDB.
#-------------------------------------------------------------------------#

   print "Connecting to GDX database......"                                    >> $LOG_FILE
   db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"           >> $LOG_FILE
   RETCODE=$?
   print "Connect to $DATABASE: RETCODE=<" $RETCODE ">"                        >> $LOG_FILE

   if [[ $RETCODE != 0 ]]; then
      print "ERROR: couldn't connect to database......"                        >> $LOG_FILE
      exit_error $RETCODE
   fi

#-------------------------------------------------------------------------#
# Truncate the staging table 
#-------------------------------------------------------------------------#

   print "Truncate table VRAP.TPRCTR_DENORM_STAGE"                             >> $LOG_FILE
   TRUNC_STAGE_SQL="import from /dev/null of del replace into VRAP.TPRCTR_DENORM_STAGE"
   db2 -stvxw $TRUNC_STAGE_SQL                                                 >> $LOG_FILE
   RETCODE=$?
   print "Truncate table, RETCODE: RETCODE=<" $RETCODE ">"                     >> $LOG_FILE

   if [[ $RETCODE > 1 ]]; then
       print " "                                                               >> $LOG_FILE
       print "Error: truncate table VRAP.TPRCTR_DENORM_STAGE...... "           >> $LOG_FILE
       exit_error $RETCODE
       print " "                                                               >> $LOG_FILE
   fi


#-------------------------------------------------------------------------#
# Now execute the XML to populate the VRAP.TPRCTR_DENORM_STAGE table.
#-------------------------------------------------------------------------#

   print "execute XMl to get prctr NPI data from the EDW. "                     >> $LOG_FILE
   print "Inserting into VRAP.TPRCTR_DENORM_STAGE"                              >> $LOG_FILE
   $SCRIPT_PATH/Common_java_db_interface.ksh GDX_prctr_xref_load.xml	

   RETCODE=$?
   
   if [[ $RETCODE != 0 ]]; then
       print " "                                                               >> $LOG_FILE
       print "Error: executing GDX_prctr_xref_load.xml...... "                 >> $LOG_FILE
       print "Return code is $RETCODE - see XML Log: "                         >> $LOG_FILE
       print "Common_java_db_interface_GDX_prctr_xref_load.log.yyyydddhhmm "   >> $LOG_FILE		
       exit_error $RETCODE
       print " "                                                               >> $LOG_FILE
   fi


#-------------------------------------------------------------------------#
# Now verify we selected data into VRAP.TPRCTR_DENORM_STAGE table.
#-------------------------------------------------------------------------#


   COUNT_SQL="SELECT COUNT(*) FROM VRAP.TPRCTR_DENORM_STAGE WITH UR "
   COUNT_SQL=$(echo "$COUNT_SQL" | tr '\n' ' ')

   print "Get ROW count from staging table"                   		       >> $LOG_FILE
   db2 -px $COUNT_SQL  > $COUNT_FILE 	   

   RETCODE=$?
   print "SELECT COUNT(*), RETCODE: RETCODE=<" $RETCODE ">"                    >> $LOG_FILE

   if [[ $RETCODE != 0 ]]; then
       print " "                                                               >> $LOG_FILE
       print "Error: Getting Count...... "                		       >> $LOG_FILE
       exit_error $RETCODE
   else
       print " "                                                               >> $LOG_FILE
       print "Check the count from VRAP.TPRCTR_DENORM_STAGE  "                 >> $LOG_FILE
       read OUTPUT_COUNT  < $COUNT_FILE 
       print "COUNT is " $OUTPUT_COUNT                                         >> $LOG_FILE
       if [[ $OUTPUT_COUNT = 0 ]]; then
	  print " "                                                            >> $LOG_FILE
          print "Error: Count IS 0 ...... "                		       >> $LOG_FILE
          RETCODE=99
       	  exit_error $RETCODE
          print " "                                                            >> $LOG_FILE
	fi
   fi

#-------------------------------------------------------------------------#
# Backup the VRAP.TPRCT_NPI_XREF table , export data into flat file.
#-------------------------------------------------------------------------#

  EXPORT_SQL="export to $EXPORT_FILE of DEL select * from VRAP.TPRCT_NPI_XREF"
  EXPORT_SQL=$(echo "$EXPORT_SQL" | tr '\n' ' ')
    echo "$EXPORT_SQL"                                                         >>$LOG_FILE
    db2 -px "$EXPORT_SQL"                                                      >>$LOG_FILE
    RETCODE=$?

  if [[ $RETCODE != 0 ]]; then
	print "ERROR: export backup abend, having problem backup the table..." >> $LOG_FILE
	exit_error 999
  else
   print "***********************************************************"         >> $LOG_FILE
   print "Backup of TPRCT_NPI_XREF table - Completed ......"                   >> $LOG_FILE
   print "***********************************************************"         >> $LOG_FILE
  fi

#-------------------------------------------------------------------------#
# Truncate the VRAP.TPRCT_NPI_XREF table 
#-------------------------------------------------------------------------#

   print "Truncate table VRAP.TPRCT_NPI_XREF"                                  >> $LOG_FILE
   TRUNC_SQL="import from /dev/null of del replace into VRAP.TPRCT_NPI_XREF"
   db2 -stvxw $TRUNC_SQL                                                       >> $LOG_FILE
   RETCODE=$?
   print "Truncate table, RETCODE: RETCODE=<" $RETCODE ">"                     >> $LOG_FILE

   if [[ $RETCODE > 1 ]]; then
       print " "                                                               >> $LOG_FILE
       print "Error: truncate table VRAP.TPRCT_NPI_XREF...... "                >> $LOG_FILE
       exit_error $RETCODE
       print " "                                                               >> $LOG_FILE
   fi


#-------------------------------------------------------------------------#
# Insert data from the stage table to the xref table 
#-------------------------------------------------------------------------#
  print "Insert rows for NPI Xref table "                                      >> $LOG_FILE
    
  INS_SQL="INSERT INTO VRAP.TPRCT_NPI_XREF "
  INS_SQL=$INS_SQL"SELECT PRCTR_DEA_ID, PRCTR_NPI_ID "
  INS_SQL=$INS_SQL"FROM VRAP.TPRCTR_DENORM_STAGE "

  INS_SQL=$(echo "$INS_SQL" | tr '\n' ' ')  
  db2 -stvxw $INS_SQL                                                          >> $LOG_FILE
  
  RETCODE=$?

  print "Insert table, RETCODE: RETCODE=<" $RETCODE ">"                        >> $LOG_FILE
                                        
  if [[ $RETCODE != 0 ]]; then
      print " "                                                                >> $LOG_FILE
      print "Error: insert NPI Xref Table...... "                              >> $LOG_FILE
      reload_NPI
      RETCODE=$?
	if [[ $RETCODE != 0 ]]; then
   	   print "ERROR:  - Both insert and reload to table vrap.tprct_npi_xref failed...." >>$LOG_FILE
  	   exit_error 999
	fi
      print "Recovered table vrap.tpharm_npi_xref from export file......"      >> $LOG_FILE      
      rm -f $EXPORT_FILE
      exit_error 999
  else
      print " "                                                                >> $LOG_FILE
      print "Successfully inserted rows "                                      >> $LOG_FILE
      RETCODE=0
  fi


#-------------------------------------------------------------------------#
# Finish the script and log the time.
#-------------------------------------------------------------------------#
   {
      print "********************************************"
      print "Finishing the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "Final return code is : <" $RETCODE ">"
   }  										>> $LOG_FILE

#-------------------------------------------------------------------------#
# move log file to archive with timestamp
#-------------------------------------------------------------------------#

   rm -f $EXPORT_FILE
   mv -f $LOG_FILE $LOG_FILE_ARCH
   
   exit $RETCODE
 
