 #!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : Purge_TAR_Gzip_DataFiles.ksh
# Title         : Archive the Data Files created by Purge_Archive_Data script.
#
# Parameters    :  
#
# Description   : Looks at the trigger file ARCH_FILE_DTL.trg in .../TgtFiles/Data_Archive/Work_Dir
#		  Reads the list file for the files to archive and calls archive and compress scripts
#		  Moves the compressed archive file into TSMARCHIVE/<#> #-- Retention year
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
# Date       User ID     Description
#----------  --------    -------------------------------------------------#
# 08-10-17   qcpue98u    ITPR019305 Rebates System Archiving 
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

   update_error_stus

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
   } >> $tmp_LOG_FILE


  append_log

   # Check if error message needs to be CCed (when email ID is passed)
   if [[ $CC_EMAIL_LIST = '' ]]; then
        mailx -s "$EMAIL_SUBJECT" $TO_MAIL  < $LOG_FILE
        echo ''
   else 
        mailx -s "$EMAIL_SUBJECT" -c $CC_EMAIL_LIST $TO_MAIL  < $LOG_FILE
	echo ''
   fi

  cp $LOG_FILE  $LOG_FILE_ARCH
   exit $RETCODE
}

#-------------------------------------------------------------------------#
# function to Connect DB
#-------------------------------------------------------------------------#
function connect_db {
  db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"									>> $tmp_LOG_FILE

   RETCODE=$?

  if [[ $RETCODE != 0 ]]; then
    print "aborting script - Error connecting to DB - $DATABASE"									>> $tmp_LOG_FILE
    print " "																>> $tmp_LOG_FILE
    exit_error $RETCODE 
  fi
}



#-------------------------------------------------------------------------#
# function to Disconnect form DB
#-------------------------------------------------------------------------#
function disconnect_db {
  db2 -stvx connect reset														>> $tmp_LOG_FILE
  db2 -stvx quit

  RETCODE=$?

  if [[ $RETCODE != 0 ]]; then

    print "aborting script - Error disconnecting from DB - $DATABASE"                                                                        >> $tmp_LOG_FILE
    print " " 

    exit_error $RETCODE
 fi
}


#-------------------------------------------------------------------------#
# function update error status to event table
#-------------------------------------------------------------------------#

function update_error_stus {
upd_stus_error="update VRAP.TRBAT_PURG_EVNT set PURG_STUS_CD=95, updt_usr_id='$SCRIPTNAME',  updt_ts=current timestamp where PURG_EVNT_ID=$purge_evnt_id and purg_stus_cd=14"

  connect_db

  db2 -stxw $upd_stus_error															>> $tmp_LOG_FILE

  RETCODE=$?

      if [[ $RETCODE != 0 ]]; then
         print "ERROR: Updated Failed for update stauts - 95 ...          "									>> $tmp_LOG_FILE
         exit_error $RETCODE
      fi


  disconnect_db

}


#-----------------------------------------------------------------------------------------#
# Check if the LOG_FILE size is greater than 5MB and move the log file to archive.
#-----------------------------------------------------------------------------------------#

function  append_log {

#Get the size of the LOGFILE
if [[ -s $LOG_FILE ]]; then
   FILE_SIZE=$(ls -l "$LOG_FILE" | awk '{ print $5 }')
fi

LOG_FILE_SIZE_MAX=5000000

# Removing the $LOGFILE as size is more than 5MB
if [[ $FILE_SIZE -gt $LOG_FILE_SIZE_MAX ]]; then
        mv -f $LOG_FILE $LOG_FILE_ARCH
        cat $tmp_LOG_FILE >> $LOG_FILE
       rm -f $tmp_LOG_FILE
else
   cat $tmp_LOG_FILE >> $LOG_FILE
   rm -f $tmp_LOG_FILE
fi


print " "                                                                      >> $LOG_FILE
print "LOGFILE SIZE  = >$FILE_SIZE<"                                           >> $LOG_FILE
print $FILE_SIZE
print " "                                                                      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
print `date +"%D %r %Z"`						       >> $LOG_FILE
print "********************************************"			       >> $LOG_FILE

print " "                                                                      >> $LOG_FILE
print " "    

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
LOG_FILE=${LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')".log"
tmp_LOG_FILE=${LOG_DIR}/$(echo $SCRIPTNAME|awk -F. '{print $1}')"_"$PRCS_ID".log"
WRK_DIR=$REBATES_HOME/TgtFiles/Data_Archive/Work_Dir
DATA_DIR=$REBATES_HOME/TgtFiles/Data_Archive/Data_Dir
ARCH_DIR=$REBATES_HOME/TgtFiles/Data_Archive/Arch_Dir


PARM_WRK_DIR="TgtFiles/Data_Archive/Work_Dir"
PARM_DATA_DIR="TgtFiles/Data_Archive/Data_Dir"
PARM_ARCH_DIR="TgtFiles/Data_Archive/Arch_Dir"

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#

print "********************************************"												>> $tmp_LOG_FILE
print "Starting the script $SCRIPTNAME ............"												>> $tmp_LOG_FILE
print `date +"%D %r %Z"`															>> $tmp_LOG_FILE
print "********************************************"												>> $tmp_LOG_FILE

print "\n PRCS_ID for Script run --- $PRCS_ID "													>> $tmp_LOG_FILE

lstfile_sql="select ARCHV_FILE_NM from VRAP.TRBAT_PURG_EVNT where purg_stus_cd=14 and ARCHV_FILE_NM is not null fetch first 1 rows only with ur"
rec_cnt_sql="select count(1) from VRAP.TRBAT_PURG_EVNT where purg_stus_cd=14 and ARCHV_FILE_NM is not null fetch first 1 rows only with ur"
TSM_DIR_sql="select rtrim(cd_nmon_txt) from VRAP.TVNDR_REBT_CD where typ_cd=215 and cd_nb=1 with ur"

connect_db

typeset -i rec_avail=`db2 -x $rec_cnt_sql`													>> $tmp_LOG_FILE

RETCODE=$?
if [[ $RETCODE != 0 ]]; then
   print "\n Error fetching Record Count -  $rec_cnt_sql"											>> $tmp_LOG_FILE
fi

if [[ $rec_avail != 0 ]]; then

	typeset lstfile=`db2 -x $lstfile_sql`													>> $tmp_LOG_FILE

	RETCODE=$?
	if [[ $RETCODE != 0 ]]; then
	   print "\n Error fetching listfile name -  $lstfile_sql"										>> $tmp_LOG_FILE
	fi

	typeset  TSM_DIR=`db2 -x $TSM_DIR_sql`													>> $tmp_LOG_FILE

	TSM_DIR=$( echo $TSM_DIR | sed "s/ //g" )

	echo "$TSM_DIR"

	RETCODE=$?
	if [[ $RETCODE != 0 ]]; then
	   print "\n Error fetching TSM_DIR name -  $TSM_DIR_sql"										>> $tmp_LOG_FILE
	fi

	print "\n $lstfile"															>> $tmp_LOG_FILE

	#-------------------------------------------------------------------------#
	# Build Variables to hold rentention period and tar file name
	#-------------------------------------------------------------------------#


	filename=`echo $lstfile | awk -F'[.]' '{print $1}'`


	rtntn_prd=$(echo $filename | awk 'BEGIN{FS="[_]"}{print $(NF)}')
	purge_evnt_id=$(echo $filename | awk 'BEGIN{FS="[_]"}{print $(NF-2)}')

	tarname=$(echo $filename | sed -e 's/_'"$rtntn_prd"'//g')".tar"
	targzname=$tarname".gz"


	print "\n Retention Year -- $rtntn_prd"													>> $tmp_LOG_FILE
	print "\n Event Id       -- $purge_evnt_id"												>> $tmp_LOG_FILE
	print "\n Tar Filename   -- $tarname"													>> $tmp_LOG_FILE


	#-------------------------------------------------------------------------#
	# Validate  TSM Archive Directory existence
	#-------------------------------------------------------------------------#


	print "Validate TSM Archive directory presence - $TSM_DIR/$rtntn_prd" 									>> $tmp_LOG_FILE

	  if [[ -d ${TSM_DIR}/$rtntn_prd ]]; then
	     print " TSM Archive Directory - ${TSM_DIR}/$rtntn_prd "										>> $tmp_LOG_FILE
	   else

		mkdir "$TSM_DIR/$rtntn_prd"
		RETCODE=$?
	       if [[ $RETCODE != 0 ]]; then
		  print "Error creating Archive Directory $TSM_DIR/$rtntn_prd " 								>> $tmp_LOG_FILE
		else
		  print "Created Archive Directory $TSM_DIR/$rtntn_prd "									>> $tmp_LOG_FILE
		fi
	  fi

	#-------------------------------------------------------------------------#
	# Call Common File Tar script to archive the file
	#-------------------------------------------------------------------------#


	$REBATES_HOME/scripts/Common_File_TAR.ksh -s $PARM_DATA_DIR -f $lstfile -i indirect -o $PARM_ARCH_DIR -t $tarname 

	RETCODE=$?

	if [[ $RETCODE != 0 ]]; then

	    print "\n Error Exectuing $REBATES_HOME/scripts/Common_File_TAR.ksh - Refer Common_File_Tar Execution log for details"              >> $tmp_LOG_FILE

	    exit_error $RETCODE
		  
	else
	   print "\n Execution successful $REBATES_HOME/scripts/Common_File_TAR.ksh "								>> $tmp_LOG_FILE
		
	fi

	#-------------------------------------------------------------------------#
	# Call Common GZIP script  to compress the archive file
	#-------------------------------------------------------------------------#


	$REBATES_HOME/scripts/Common_Gzip_Process.ksh -a c -d $ARCH_DIR -s $tarname -D $ARCH_DIR -t $targzname 

	RETCODE=$?

	if [[ $RETCODE != 0 ]]; then

	   print "\n Error Exectuing $REBATES_HOME/scripts/Common_Gzip_Process.ksh - Refer Common_Gzip_Process script Execution log for details"  >> $tmp_LOG_FILE
	    exit_error $RETCODE

	else
	   print "\n Execution successful $REBATES_HOME/scripts/Common_Gzip_Process.ksh"							>> $tmp_LOG_FILE

	fi

	echo "cp $ARCH_DIR/$targzname $TSM_DIR/$rtntn_prd/$targzname"


	cp $ARCH_DIR/$targzname $TSM_DIR/$rtntn_prd/$targzname

	RETCODE=$?

	if [[ $RETCODE != 0 ]]; then
		print "\n Error moving $DATA_DIR/$targzname file to $TSM_DIR/$rtntn_prd/"							>> $tmp_LOG_FILE
	    exit_error $RETCODE
	fi


	#-------------------------------------------------------------------------#
	# update Event status to Delete Ready - 20
	#-------------------------------------------------------------------------#


	upd_stus_sql="update VRAP.TRBAT_PURG_EVNT set ARCHV_FILE_NM='$targzname', PURG_STUS_CD=20, updt_usr_id='$SCRIPTNAME',  updt_ts=current timestamp where PURG_EVNT_ID=$purge_evnt_id and purg_stus_cd=14"


	  connect_db

	  db2 -stxw $upd_stus_sql														>> $tmp_LOG_FILE

	  RETCODE=$?

	      if [[ $RETCODE != 0 ]]; then
		 print "ERROR: Updated Failed for update stauts - 20 ...          "								>> $tmp_LOG_FILE
		 exit_error $RETCODE
	      fi


	  disconnect_db


	print "********************************************"											>> $tmp_LOG_FILE
	print "....Completed executing " $SCRIPTNAME " ...."											>> $tmp_LOG_FILE
	print `date +"%D %r %Z"`														>> $tmp_LOG_FILE
	print "********************************************"											>> $tmp_LOG_FILE

	rm -f $ARCH_DIR/$tarname
	rm -f $ARCH_DIR/$targzname
	append_log

	#-------------------------------------------------------------------------#
	# End of Script
	#-------------------------------------------------------------------------#

else
  
   print "No Event to process /Archive/compress"												>> $tmp_LOG_FILE
   print "  "																	>> $tmp_LOG_FILE
   print "********************************************"												>> $tmp_LOG_FILE

   append_log

   exit $RETCODE

fi

