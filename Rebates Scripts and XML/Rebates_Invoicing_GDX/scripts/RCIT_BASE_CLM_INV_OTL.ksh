#!/bin/ksh
#set -x

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

  . `dirname $0`/Common_GDX_Environment.ksh
  
  if [[ $REGION = "prod" ]];   then
      if [[ $QA_REGION = "true" ]];   then
          # Running in the QA region
          export ALTER_EMAIL_ADDRESS=""
          EMAIL_TO_LIST="GDXITD@caremark.com"
	  EMAIL_CC_LIST="_GDXDEVTest@caremark.com"
          EMAIL_FROM_LIST="GDXITD@caremark.com"
          SYSTEM="QA"
      else
          # Running in Prod region
          export ALTER_EMAIL_ADDRESS=""
          EMAIL_TO_LIST="GDXITD@caremark.com"
	  EMAIL_CC_LIST="_GDXDEVTest@caremark.com"
          EMAIL_FROM_LIST="GDXITD@caremark.com"          
          SYSTEM="PRODUCTION"
      fi
  else
      # Running in Development region
      export ALTER_EMAIL_ADDRESS="prakash.jha@caremark.com"
      EMAIL_TO_LIST="prakash.jha@caremark.com"
      EMAIL_CC_LIST="navneet.deswal@caremark.com"
      EMAIL_FROM_LIST="GDXITD@caremark.com"      
      SYSTEM="DEVELOPMENT"
  fi


#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error
#   usage: exit_error |Error Code|
{
    RETCODE=$1

    if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
    fi

    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh
    
    #If log file exists then archive it.
    if [ -s $LOG_FILE ]; then
       cp $LOG_FILE $LOG_FILE_ARCH
    fi

    exit $RETCODE
}



#-------------------------------------------------------------------------#
# Function to update_breakpoint_table
#-------------------------------------------------------------------------#
function update_breakpoint_table
#   usage: update_breakpoint_table  
{
         # Update break point divsion table
	 sql="update VACTUATE.RCIT_BASE_CLM_INV_OTL 
	 set START_TIME = $starttime, 
	 END_TIME = $endtime, 
	 status = '$status'         
	 where MODEL_TYPE_CODE = '${model}' and 
	 INV_ELIG_DT='${dt}' and 
	 BATCH_GID=${gid}"
	 
	 db2 -px "$sql"  
	 RETCODE=$?
	 
	 if [[ $RETCODE -gt 1 ]]; then
	   print "Query\n" >> $LOG_FILE
	   print $sql >> $LOG_FILE
	   print "ERROR: Update query failed "  >> $LOG_FILE
	   print "Return code is : <$RETCODE>"  >> $LOG_FILE
	   print "SQL Query failed : <$RETCODE>"  >> $LOG_FILE
	   exit_error $RETCODE
	 fi
}

#-------------------------------------------------------------------------#
# Function to update counts before update is made
#-------------------------------------------------------------------------#
function update_pre_count
{
         # Update pre update count in the table
         sql="UPDATE VACTUATE.RCIT_BASE_CLM_INV_OTL A
		SET (A.PRE_UPDATE_COUNT) = (select count(*) 
			 from VRAP.RCIT_BASE_CLM_INV B
			 where 
		         B.model_typ_cd = A.MODEL_TYPE_CODE AND
			 B.INV_ELIG_DT = A.INV_ELIG_DT AND
	                 B.btch_gid = A.BATCH_GID
		   group by b.model_typ_cd,B.INV_ELIG_DT,B.btch_gid) 
		 WHERE A.PRE_UPDATE_COUNT is null"

         db2 -px "$sql"
         RETCODE=$?

         if [[ $RETCODE -gt 1 ]]; then
           print "Query\n" >> $LOG_FILE
           print $sql >> $LOG_FILE
           print "ERROR: Update query failed "  >> $LOG_FILE
           print "Return code is : <$RETCODE>"  >> $LOG_FILE
           print "SQL Query failed : <$RETCODE>"  >> $LOG_FILE
           exit_error $RETCODE
         fi
}

#-------------------------------------------------------------------------#
# Function to update counts before update is made
#-------------------------------------------------------------------------#
function update_post_count
{
         # Update pre update count in the table
         sql="UPDATE VACTUATE.RCIT_BASE_CLM_INV_OTL A
		SET (A.POST_UPDATE_COUNT) = (select count(*) 
			 from VRAP.RCIT_BASE_CLM_INV B
			 where 
			 nvl(B.clt_id,0)=nvl(B.rbat_id,0) and 
		         B.model_typ_cd = A.MODEL_TYPE_CODE AND
			 B.INV_ELIG_DT = A.INV_ELIG_DT AND
	                 B.btch_gid = A.BATCH_GID
		   group by b.model_typ_cd,B.INV_ELIG_DT,B.btch_gid)"

         db2 -px "$sql"
         RETCODE=$?

         if [[ $RETCODE -gt 1 ]]; then
           print "Query\n" >> $LOG_FILE
           print $sql >> $LOG_FILE
           print "ERROR: Update query failed "  >> $LOG_FILE
           print "Return code is : <$RETCODE>"  >> $LOG_FILE
           print "SQL Query failed : <$RETCODE>"  >> $LOG_FILE
           exit_error $RETCODE
         fi
}


#-------------------------------------------------------------------------#
# Function to create query
#-------------------------------------------------------------------------#
function create_update_query
#   usage: create_update_query  
{
    sql="MERGE INTO VRAP.RCIT_BASE_CLM_INV a
	USING (SELECT rbat_id,bus_seg_cd FROM CLIENT_REG.CRT_CLNT) b
	ON a.rbat_id = b.rbat_id
	AND model_typ_cd = '$model'
	AND INV_ELIG_DT = '$dt'
	AND btch_gid = $gid
	WHEN MATCHED THEN
	UPDATE SET a.bus_seg_cd = b.bus_seg_cd,
	           a.clt_id = a.rbat_id"
}


#-------------------------------------------------------------------------#
# Setting initial value of Variables
#-------------------------------------------------------------------------#

   RETCODE=0
   FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
   JOBNAME=${FILE_BASE}
   SCRIPTNAME=${FILE_BASE}.ksh
   EMAILPARM4='  '
   EMAILPARM5='  '
   
   #Output Files
   BREAKPOINT_RECORDS=$OUTPUT_PATH/${FILE_BASE}_Breakpoint.dat
   UPDATE_QUERY_RESULTS=$OUTPUT_PATH/${FILE_BASE}_Update_Query.dat
   EMAIL_BODY=$OUTPUT_PATH/${FILE_BASE}_EmailBody.dat
   
   rm -f $EMAIL_BODY
   rm -f $BREAKPOINT_RECORDS
   rm -f $UPDATE_QUERY_RESULTS
   
   # LOG FILES
   LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}.log."`date +"%Y%m%d_%H%M%S"`
   LOG_FILE="${LOG_PATH}/${FILE_BASE}.log"
   
   
#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
   {
      print "\n************************************************************"
      print `date +"%D %r %Z"` " - Starting the script $SCRIPTNAME ......"
      print "Running in SYSTEM = $SYSTEM"
      print "**************************************************************\n"
   } > $LOG_FILE

#-------------------------------------------------------------------------#
# Connect to UDB.
#-------------------------------------------------------------------------#

   print "\nConnecting to GDX database......" >> $LOG_FILE
   db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD" >> $LOG_FILE
   RETCODE=$?
   print "Connect to $DATABASE: RETCODE=<" $RETCODE ">" >> $LOG_FILE

   if [[ $RETCODE != 0 ]]; then
      print "ERROR: couldn't connect to database......">> $LOG_FILE
      exit_error $RETCODE
   fi
   

#***********************************************
# Base Query to select records
#************************************************
  
   print "\nReading Break Point division table ">> $LOG_FILE       
   sql="select * from VACTUATE.RCIT_BASE_CLM_INV_OTL where STATUS = 'NOT STARTED' or STATUS = 'ERROR'"
   
   db2 -px "$sql">$BREAKPOINT_RECORDS
   RETCODE=$?
   print ' RETCODE=<'$RETCODE'>'>> $LOG_FILE
        
   if [[ $RETCODE = 0 ]]; then
      print "\nUpdate Pre records count before updating the table">> $LOG_FILE
      update_pre_count  
      
      print "\nStaring update in bacthes">> $LOG_FILE
      #****************************************************************
      # Continue below logic to update records  
      #****************************************************************  
      while read model dt gid TOTAL_COUNT PRE_UPDATE_COUNT POST_UPDATE_COUNT START_TIME END_TIME STATUS; do
         print "\nStart updation or records for the below mentioned criteria " >> $LOG_FILE
         print "MODEL = " ${model} >> $LOG_FILE  
         print "DATE  = " ${dt} >> $LOG_FILE 
         print "ID    = " ${gid} >> $LOG_FILE 
         print "Total Count = " ${TOTAL_COUNT} >> $LOG_FILE 
         print "Pre Update Count = " ${PRE_UPDATE_COUNT} >> $LOG_FILE 
         print "Post Update Count = " ${POST_UPDATE_COUNT} >> $LOG_FILE 
         print "Start Time = " ${START_TIME} >> $LOG_FILE 
         print "End Time = " ${END_TIME} >> $LOG_FILE 
         print "Status = " ${STATUS} >> $LOG_FILE 
	 
	 export model
	 export date
	 export gid
    
         export starttime='CURRENT TIMESTAMP'
	 export endtime='NULL'
	 export status='PROCESSING'
	 
         update_breakpoint_table
         
         create_update_query
         
         #Run Update Query
         db2 -px "$sql" >> $UPDATE_QUERY_RESULTS
         RETCODE=$?
         
         if [[ $RETCODE -gt 1 ]]; then
            export starttime='START_TIME'
	    export endtime='CURRENT TIMESTAMP'
	    export status='ERROR'
	 	 
	    update_breakpoint_table
	    
            print " " >> $LOG_FILE
            print "ERROR: Update query failed "  >> $LOG_FILE
            print "Return code is : <$RETCODE>"  >> $LOG_FILE
            print "SQL Query failed : <$RETCODE>"  >> $LOG_FILE
            exit_error $RETCODE
         fi
	          
	 #Run Commit Command	
         db2 -px "commit" >> $UPDATE_QUERY_RESULTS
         RETCODE=$?       
         if [[ $RETCODE -gt 1 ]]; then
            export starttime='START_TIME'
	    export endtime='CURRENT TIMESTAMP'
	    export status='ERROR'
	 	 
	    update_breakpoint_table
	    
            print " " >> $LOG_FILE
            print "ERROR: Commit Failed "  >> $LOG_FILE
            print "Return code is : <$RETCODE>"  >> $LOG_FILE
            print "SQL Query failed : <$RETCODE>"  >> $LOG_FILE
            exit_error $RETCODE
         fi         
         
         export starttime='START_TIME'
	 export endtime='CURRENT TIMESTAMP'
	 export status='COMPLETE'
	 
	 update_breakpoint_table
               
      done <$BREAKPOINT_RECORDS
   fi 


print "\nUpdate Post records count After updating the table">> $LOG_FILE
update_post_count

#-------------------------------------------------------------------------#
# Finish the script and log the time.
#-------------------------------------------------------------------------#
{
   print "\n*************************************************************"
   print `date +"%D %r %Z"` " - Finishing the script $SCRIPTNAME ......"
   print "Final return code is : <" $RETCODE ">"
   print "*************************************************************"
}  >> $LOG_FILE

# Move Log file to archive folder
mv $LOG_FILE $LOG_FILE_ARCH

echo " " > $EMAIL_BODY
echo "${JOBNAME} Completed Successfully!!!" >> $EMAIL_BODY

mailx -r $EMAIL_FROM_LIST -c $EMAIL_CC_LIST -s "${JOBNAME} Completed.." $EMAIL_TO_LIST < $EMAIL_BODY

exit $RETCODE
