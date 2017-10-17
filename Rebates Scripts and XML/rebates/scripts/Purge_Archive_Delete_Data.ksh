#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : Pruge_Archive_Delete_Data.ksh
# Title         : Purge / Archive the data from tables based on the Event records in VRBAT_PURG_RULE_EVNT.
#
# Parameters    :  
#                 -t table name <Name of the table which need to be purged>
#		  -s Size Code <defines table group to select for purge>
#		  -l loop count <defines the number of events to use in for a given run>
#		  -i action type Indicator <A-Archive,D-Delete>
#		  -m email id <otpional>
#
# Description   : The script will purge data from the tables, those are in ready for delete state.
#		  Create data files for the events those are in ready for archive state.
#		  Either one of the following combination of parameters is mandatory for script run
#		  1. Table Name OR 2. Size Code and Loop Count
#		  Refer TYP_CD 194 - for the status updated by upd_stus function
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
# Date       User ID     Description
#----------  --------    -------------------------------------------------#
# 07-24-17   qcpue98u    ITPR019305 Rebates System Archiving 
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
        print "Return_code = " $RETCODE
        print " "
        print " ------ Ending script " $SCRIPT `date`
   } >> $LOG_FILE

   # Check if error message needs to be CCed (when email ID is passed)
   if [[ $CC_EMAIL_LIST = '' ]]; then
        mailx -s "$EMAIL_SUBJECT" $TO_MAIL  < $LOG_FILE
        echo ''
   else 
        mailx -s "$EMAIL_SUBJECT" -c $CC_EMAIL_LIST $TO_MAIL  < $LOG_FILE
	echo ''
   fi
   
   cp -f $LOG_FILE $LOG_FILE_ARCH
   exit $RETCODE
}

#-------------------------------------------------------------------------#
# function to Connect DB
#-------------------------------------------------------------------------#
function connect_db {
  db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"

   RETCODE=$?

  if [[ $RETCODE != 0 ]]; then
    print "aborting script - Error connecting to DB - $DATABASE"                                >> $LOG_FILE
    print " "											>> $LOG_FILE
    exit_error $RETCODE "Error connecting to DB - $DATABASE"
  fi
}



#-------------------------------------------------------------------------#
# function to Disconnect form DB
#-------------------------------------------------------------------------#
function disconnect_db {
  db2 -stvx connect reset
  db2 -stvx quit

  RETCODE=$?

  if [[ $RETCODE != 0 ]]; then
    exit_error $RETCODE "Error while disconnecting from Database"
 fi
}


#-------------------------------------------------------------------------#
# function to set DB Alias name for DBA trigger file
#-------------------------------------------------------------------------#

function set_db_alias {

#export region=`echo $REBATES_HOME | cut -d / -f 4`

UNIX_REGION_TXT=$( echo "$UNIX_REGION_TXT" | tr -s  '[:lower:]'  '[:upper:]' )


case $UNIX_REGION_TXT in
    DEV1)
	   if [[ $DB_NM == 'GDX' ]]; then
	      DB_ALIAS='GDXDEV1'
	   else 
	      DB_ALIAS='TRBIDEV1'
	   fi
         ;;
    DEV2)
	   if [[ $DB_NM == 'GDX' ]]; then
	      DB_ALIAS='GDXDEV2'
	   else 
	      DB_ALIAS='TRBIDEV2'
	   fi        
	 ;;
    SIT1)
	   if [[ $DB_NM == 'GDX' ]]; then
	      DB_ALIAS='GDXSIT1'
	   else 
	      DB_ALIAS='TRBISIT1'
	   fi        
	 ;;
    SIT2)
	   if [[ $DB_NM == 'GDX' ]]; then
	      DB_ALIAS='GDXSIT2'
	   else 
	      DB_ALIAS='TRBISIT2'
	   fi        
	 ;;
    prod)
	   if [[ $DB_NM == 'GDX' ]]; then
	      DB_ALIAS='GDXPRD'
	   else 
	      DB_ALIAS='TRBIPRD'
	   fi        
	 ;;
    * )
        RETCODE=1
        exit_error $RETCODE "Incorrect region name - $region."
        ;;
esac

}

#-------------------------------------------------------------------------#
# function to  set action indicator and build associated variables
#-------------------------------------------------------------------------#

function set_actnind {
  if [[ $actnind == 'A' ]]; then
      stmt_col="SLCT_STMNT_TX"
      actncd=10
  elif [[ $actnind == 'D' ]]; then
      stmt_col="DEL_STMNT_TX"
      actncd=20
      
  else
     RETCODE=1
     exit_error $RETCODE "Invalid Action Indicator passed Valid values are  A or D"
  fi
}

#-------------------------------------------------------------------------#
# function to set loop count based on parameters passed to script
#-------------------------------------------------------------------------#

function get_RecCnt {


  if [[ $tablename != '' ]]; then

	tablename=$( echo "$tablename" | tr -s  '[:lower:]'  '[:upper:]' )
        tablename="'$tablename'"
        rec_cnt_sql="select ARCHV_RUN_LMT from VRAP.VRBAT_PURG_RULE_EVNT where PURG_STUS_CD = $actncd and TBL_NM = $tablename order by PRTY_SEQ_CD fetch first 1 rows only with ur "

  else
        sizecd=$( echo "$sizecd" | tr -s '[:lower:]' '[:upper:]' )

        if echo "$loopcnt" | egrep -q '^[1-9]$'; then
                echo "Event Loop Count - $loopcnt is valid"
        else
               RETCODE=1
		echo "Event Loop Count - $loopcnt is not valid. Can be a number between 1-9"                                    >> $LOG_FILE
                exit_error $RETCODE  echo "Event Loop Count - $loopcnt is not valid. Can be a number between 1-9"
        fi
	validate_cnt_sql="select count(1) from VRAP.VRBAT_PURG_RULE_EVNT where PURG_STUS_CD = $actncd and TBL_SZ_CD = $sizecd fetch first $loopcnt rows only with ur"
  fi

}

#-------------------------------------------------------------------------#
# function to update process status 
#-------------------------------------------------------------------------#

function update_stus {

 upd_stus=$1
 upd_stus_sql="update VRAP.TRBAT_PURG_EVNT set PURG_STUS_CD=$upd_stus, updt_usr_id='$SCRIPTNAME',  updt_ts=current timestamp where PURG_EVNT_ID=$PURG_EVNT_ID"

print "\n Updating Event table "TRBAT_PURG_EVNT" for Event ID $PURG_EVNT_ID -- Purge Status $upd_stus......."													>> $LOG_FILE
print "\n\n $upd_stus_sql"																		>> $LOG_FILE
  connect_db

  db2 -stxw $upd_stus_sql																		>> $LOG_FILE

  RETCODE=$?

      if [[ $RETCODE != 0 ]]; then
         print "ERROR: Updated Failed for update stauts - $updstus ...          "											>> $LOG_FILE
         print "Return code is : <$RETCODE>"																>> $LOG_FILE
         exit_error $RETCODE
      fi


  disconnect_db

  
}

#-------------------------------------------------------------------------#
# Function to COMMIT THE TRANSACTION OR ABORT IF FAILED
#-------------------------------------------------------------------------#
function commit_trans {

     db2 -px "commit"																			>> $LOG_FILE
     RETCODE=$?

      if [[ $RETCODE != 0 ]]; then
         print "ERROR: Commit failed in $SCRIPTNAME  ...          "													>> $LOG_FILE
         print "Return code is : <$RETCODE>"																>> $LOG_FILE
         exit_error $RETCODE
      fi
}


#-------------------------------------------------------------------------#
# Function to exit the script on Success
#-------------------------------------------------------------------------#

function exit_success {
    print " "																				>> $LOG_FILE
    print "********************************************"														>> $LOG_FILE
    print "....Completed executing " $SCRIPTNAME " ...."														>> $LOG_FILE
    print `date +"%D %r %Z"`																		>> $LOG_FILE
    print "********************************************"														>> $LOG_FILE

    #-------------------------------------------------------------------------#
    # move log file to archive with timestamp
    #-------------------------------------------------------------------------#
    rm -f $WRK_DIR/${sqlfile}
    rm -f ${WRK_FILE} 
    mv -f $LOG_FILE $LOG_FILE_ARCH

    exit 0
}



#-------------------------------------------------------------------------#
# Main Processing starts 
#-------------------------------------------------------------------------#

# Set Variables
RETCODE=0
SCRIPTNAME=$(basename "$0")

PRCS_ID=$$


# Set file path and names
LOG_ARCH_PATH=$REBATES_HOME/log/archive
LOG_FILE_ARCH=${LOG_ARCH_PATH}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE=${LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')"_P_ID_"$PRCS_ID".log"
WRK_DIR=$REBATES_HOME/TgtFiles/Data_Archive/Work_Dir
WRK_FILE=$WRK_DIR/WRK_FILE"_"$PRCS_ID".wrk"
DATA_DIR=$REBATES_HOME/TgtFiles/Data_Archive/Data_Dir
PARM_WRK_DIR="TgtFiles/Data_Archive/Work_Dir"

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#

print "********************************************"															>> $LOG_FILE
print "Starting the script $SCRIPTNAME ............"															>> $LOG_FILE
print `date +"%D %r %Z"`																		>> $LOG_FILE
print "********************************************"															>> $LOG_FILE

print "\n PRCS_ID for Script run --- $PRCS_ID "																>> $LOG_FILE

# set default value to blank before assigning

tablename=''		
sizecd=''		
loopcnt=''		
actnind=''
CC_EMAIL_LIST=''


# Assign values to variable from arguments passed
while getopts t:s:l:i:m: argument
do
      case $argument in
          t)tablename=$OPTARG;;
          s)sizecd=$OPTARG;;
          l)loopcnt=$OPTARG;;
	  i)actnind=$OPTARG;;
          m)CC_EMAIL_LIST=$OPTARG@caremark.com;;
          *)
            echo "\n Usage: $SCRIPTNAME -t -s -l -i [-m] -- Refer the parameter usage below"										>> $LOG_FILE
            echo "\n Example1: $SCRIPTNAME -t tablename -i action count -m firsname.lastname OR"									>> $LOG_FILE
            echo "\n Example2: $SCRIPTNAME  -s SizeCode -l EventCount -m firsname.lastname"										>> $LOG_FILE
            echo "\n -s <Size Code> Determines table size code Small/Big/Large"												>> $LOG_FILE
            echo "\n -l <Event Loop count> Number of evnets to process in a given run"											>> $LOG_FILE
            echo "\n -i <Archive OR Delete> SQL file creates for Load or Delete data"											>> $LOG_FILE
            echo "\n -m <EmailID without @caremark.com> Additional email ID where failure message will be sent"								>> $LOG_FILE
            exit_error ${RETCODE} "Incorrect arguments passed"
            ;;
      esac
done

print " "																				>> $LOG_FILE
print " Parameters passed for current run"																>> $LOG_FILE
print " Table Name: $tablename"																		>> $LOG_FILE
print " Table Size Code: $sizecd"																	>> $LOG_FILE
print " Purge Event Loop Count: $loopcnt"																>> $LOG_FILE
print " SQL Type Indicator: $actnind"																	>> $LOG_FILE
print " Alternate Email ID: $CC_EMAIL_LIST"																>> $LOG_FILE


print " " >> $LOG_FILE


if [[ ($actnind == '' ||  $tablename == '') && ($sizecd == '' ||  $loopcnt == '') ]]; then
      RETCODE=1

            echo "\n Usage: $SCRIPTNAME -i -t -s -l [-m] -- Refer the parameter usage below"										>> $LOG_FILE
            echo "\n Example1: $SCRIPTNAME -t tablename -m firsname.lastname OR"											>> $LOG_FILE
            echo "\n Example2: $SCRIPTNAME  -s SizeCode -l EventCount -m firsname.lastname"										>> $LOG_FILE
            echo "\n -t <tablename> Name of the table which need to be purged"												>> $LOG_FILE
            echo "\n -s <Size Code> Determines table size code Small/Big/Large"												>> $LOG_FILE
            echo "\n -l <Event Loop count> Number of evnets to process in a given run"											>> $LOG_FILE
            echo "\n -i <Select OR Delete> SQL file creates for Load or Delete data"											>> $LOG_FILE
            echo "\n -m <EmailID without @caremark.com> Additional email ID where failure message will be sent"								>> $LOG_FILE
            exit_error ${RETCODE} "Incorrect arguments passed"
fi

actnind=$( echo "$actnind" | tr -s  '[:lower:]'  '[:upper:]' )
set_actnind
get_RecCnt


if [[ $tablename != '' ]]; then

connect_db

typeset -i rec_cnt=`db2 -x $rec_cnt_sql`

	RETCODE=$?
	if [[ $RETCODE != 0 ]]; then
	   print "\n Error fetching record count -  $rec_cnt_sql"													>> $LOG_FILE
	fi
 disconnect_db
	else

	rec_cnt=$loopcnt

fi


print "\n\n Record count to process --- $rec_cnt"                                                                                                                         >> $LOG_FILE




if [[ $rec_cnt != 0 && $tablename != '' ]]; then
	export evnt_select="select DB_NM, SCHEMA_NM, TBL_NM, ARCHV_RUN_LMT, PURG_EVNT_ID, ARCHV_FILE_ADDON_NM, ARCHV_RTNTN_PRD_YR,  $stmt_col from VRAP.VRBAT_PURG_RULE_EVNT where PURG_STUS_CD = $actncd and TBL_NM = $tablename"
elif [[ $rec_cnt != 0 && $sizecd != '' ]]; then
	export evnt_select="select DB_NM, SCHEMA_NM, TBL_NM, ARCHV_RUN_LMT, PURG_EVNT_ID, ARCHV_FILE_ADDON_NM, ARCHV_RTNTN_PRD_YR ,$stmt_col from VRAP.VRBAT_PURG_RULE_EVNT where PURG_STUS_CD = $actncd and TBL_SZ_CD = $sizecd"
else 
    print "\n Ending script - No Purge Event to process"														>> $LOG_FILE
    print " "																				>> $LOG_FILE
    exit_success 

fi


#-------------------------------------------------------------------------#
# Add additional condition to the event sql when action code is Delete
#-------------------------------------------------------------------------#

if [[ $actncd == 20 ]]; then
	evnt_select=$evnt_select" and TBL_STRTR_CD != 1 and SPL_PRCS_CD in (1,2) order by PRTY_SEQ_CD fetch first $rec_cnt row only with ur;"
else
	evnt_select=$evnt_select"  order by PRTY_SEQ_CD fetch first $rec_cnt row only with ur;"
fi


print "\n\n $evnt_select"																		>> $LOG_FILE


#-----------------------------------------------------------------------------------#
#  Work File creation and end the process with success code if no records to process
#-----------------------------------------------------------------------------------#


if [[ $sizecd != '' ]]; then

connect_db

typeset -i validate_cnt=`db2 -x $validate_cnt_sql`															>> $LOG_FILE

disconnect_db

fi

if [[ ($sizecd != '' && $validate_cnt != 0) ||  ($tablename != '' &&  $rec_cnt != 0) ]]; then

connect_db

db2 -stxw $evnt_select > $WRK_FILE																	

  RETCODE=$?

      if [[ $RETCODE != 0 ]]; then
         print "ERROR executing sql $evnt_select -- Work file creationg $WRK_FILE failed"										>> $LOG_FILE
         exit_error $RETCODE
      fi
else
    print "\n Ending script - No Records in $WRK_FILE to process" 													>> $LOG_FILE                                                                  >> $LOG_FILE
    print " "                                                                                                                                                           >> $LOG_FILE
    exit_success
fi

disconnect_db


while read DB_NM SCHEMA_NM TBL_NM ARCHV_RUN_LMT PURG_EVNT_ID ARCHV_FILE_ADDON_NM ARCHV_RTNTN_PRD_YR STMNT_TXT
 do
     print "\n Processing Evnt_id -  $PURG_EVNT_ID for table - $DB_NM"_"$SCHEMA_NM"_"$TBL_NM"										>> $LOG_FILE

     sqlfile=$DB_NM"_"$SCHEMA_NM"_"$TBL_NM"_"$PURG_EVNT_ID"_"$PRCS_ID".sql"
     datafile=$DB_NM"_"$SCHEMA_NM"_"$TBL_NM"_"$PURG_EVNT_ID"_"$ARCHV_FILE_ADDON_NM".dat"
     lstfile=$DB_NM"_"$SCHEMA_NM"_"$TBL_NM"_"$PURG_EVNT_ID"_"$ARCHV_FILE_ADDON_NM"_"$ARCHV_RTNTN_PRD_YR".lst"
     insfile=$DB_NM"_"$SCHEMA_NM"_"$TBL_NM"_"$PURG_EVNT_ID"_"$ARCHV_FILE_ADDON_NM".ins"
     ddlfile=$DB_NM"_"$SCHEMA_NM"_"$TBL_NM"_"$PURG_EVNT_ID"_"$ARCHV_FILE_ADDON_NM".ddl"
     cntfile=$DB_NM"_"$SCHEMA_NM"_"$TBL_NM"_"$PURG_EVNT_ID"_"$ARCHV_FILE_ADDON_NM"_CNT_FILE.txt"
     dbatrg="DBA_TBL_DDL.trg"





#-----------------------------------------------------------------------------------#
#  Creating Select sql to collect the data for archival
#-----------------------------------------------------------------------------------#

    if [[ $actncd == 10 ]]; then

	update_stus 12
         
	print "\n export to $DATA_DIR/$datafile of del modified by coldel| messages $DATA_DIR/$cntfile $STMNT_TXT"							>> $LOG_FILE

         print "export to $DATA_DIR/$datafile of del modified by coldel| messages $DATA_DIR/$cntfile $STMNT_TXT" > $WRK_DIR/$sqlfile
	
	 RETCODE=$?	

         if [[ $RETCODE != 0 ]]; then
                print "\n Error Creating SQLFile - $WRK_DIR/$sqlfile"													>> $LOG_FILE
                exit_error $RETCODE "Error Creating SQLFile - $WRK_DIR/$sqlfile"
         fi

#-----------------------------------------------------------------------------------#
#  write trigger file for DBA script to create DDL and execute common UDB DML script
#-----------------------------------------------------------------------------------#

	set_db_alias
      
	print "$DB_ALIAS $SCHEMA_NM $TBL_NM $DATA_DIR $ddlfile"	   > $WRK_DIR/$dbatrg

         RETCODE=$?

         if [[ $RETCODE != 0 ]]; then
                print "\n Error Creating DBA Trigger File - $WRK_DIR/$dbatrg"												>> $LOG_FILE
                exit_error $RETCODE "Error Creating DBA Trigger File - $WRK_DIR/$dbatrg"
         fi

 
	print "\n Executing the Common_UDB_DML_Execution.ksh with following parameters .....  "										>> $LOG_FILE
        print "\n $REBATES_HOME/scripts/Common_UDB_DML_Execution.ksh -d $WRK_DIR -f $sqlfile -D $DB_NM"									>> $LOG_FILE

	$REBATES_HOME/scripts/Common_UDB_DML_Execution.ksh -d $PARM_WRK_DIR -f $sqlfile -D $DB_NM

	   RETCODE=$?

	  if [[ $RETCODE != 0 ]]; then
	    print "\n Error Exectuing $REBATES_HOME/scripts/Common_UDB_DML_Execution.ksh - Refer Common_UDB_DML_Execution log for details"				>> $LOG_FILE
	    exit_error $RETCODE "\n Error Exectuing $REBATES_HOME/scripts/Common_UDB_DML_Execution.ksh - Refer Common_UDB_DML_Execution log for details"
	
            update_stus 91
	  
	else
	   print "\n Execution successful $REBATES_HOME/scripts/Common_UDB_DML_Execution.ksh "										>> $LOG_FILE
	
	   update_stus 14

#-------------------------------------------------------------------------#
# Creating necessary files for the Archival steps
#-------------------------------------------------------------------------#

          print "$datafile" > $DATA_DIR/$lstfile
          print "$insfile" >> $DATA_DIR/$lstfile
	  print "$ddlfile" >> $DATA_DIR/$lstfile
	  print "$cntfile" >> $DATA_DIR/$lstfile
	  cp "$WRK_DIR/Archive_Import_Instruction.txt"  "$DATA_DIR/$insfile"


	upd_lstfile_sql="update VRAP.TRBAT_PURG_EVNT set ARCHV_FILE_NM='$lstfile', updt_usr_id='$SCRIPTNAME',  updt_ts=current timestamp where PURG_EVNT_ID=$PURG_EVNT_ID and purg_stus_cd=14"

	print "\n$upd_lstfile_sql"																	>> $LOG_FILE
	  connect_db

	  db2 -stxw $upd_lstfile_sql																	>> $LOG_FILE

	  RETCODE=$?

	      if [[ $RETCODE != 0 ]]; then
		 print "ERROR: Updated Failed for update ARCHV_FILE_NM - $lstfile ...          "									>> $LOG_FILE
		 exit_error $RETCODE
	      fi


	  disconnect_db

	  fi

   else


#-----------------------------------------------------------------------------------#
#  Creating DELETE sql to collect the purge the data
#-----------------------------------------------------------------------------------#
	
	update_stus 22

	print "\n $STMNT_TXT"																		>> $LOG_FILE

	print "$STMNT_TXT" > $WRK_DIR/$sqlfile

	RETCODE=$?

         if [[ $RETCODE != 0 ]]; then
                print "\n Error Creating SQLFile - $WRK_DIR/$sqlfile"													>> $LOG_FILE
                exit_error $RETCODE "Error Creating SQLFile - $WRK_DIR/$sqlfile"
         fi

	print "\n Executing the Common_UDB_DML_Execution.ksh with following parameters .....  "										>> $LOG_FILE
        print "\n $REBATES_HOME/scripts/Common_UDB_DML_Execution.ksh -d $PARM_WRK_DIR -f $sqlfile -D $DB_NM"								>> $LOG_FILE

	$REBATES_HOME/scripts/Common_UDB_DML_Execution.ksh -d $PARM_WRK_DIR -f $sqlfile -D $DB_NM

	   RETCODE=$?

	  if [[ $RETCODE != 0 ]]; then

	    print "\n Error Exectuing $REBATES_HOME/scripts/Common_UDB_DML_Execution.ksh - Refer Common_UDB_DML_Execution log for details"				>> $LOG_FILE
	    exit_error $RETCODE "\n Error Exectuing $REBATES_HOME/scripts/Common_UDB_DML_Execution.ksh - Refer Common_UDB_DML_Execution log for details"

	    update_stus 92

	  else
	   print "\n Execution successful $REBATES_HOME/scripts/Common_UDB_DML_Execution.ksh "										>> $LOG_FILE
	
	   update_stus 50
	  fi


   fi
done < $WRK_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
  exit_error $RETCODE " Exiting Process with Error exectuing Script"													>> $LOG_FILE
else
  exit_success
fi  
