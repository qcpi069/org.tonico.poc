export HOME_DIR="/GDX/prod"

export UNIQUE_RUN_ID="T20051003104920_P9138326"
export CLIENT_NAME="PHARMASSESS"
export PROCESS_MONTH="SEP" 
export PROCESS_YEAR="2005"
export DATA_LOAD_FILE="mda.vrap.tclaims.dat.T20051003104920"
mda.vrap.tclaims.dat.T20051003104920

export TEMP_DIR="$HOME_DIR/temp/$UNIQUE_RUN_ID"
export CLIENT_DIR="$HOME_DIR/clients/$CLIENT_NAME"
export RUN_STATUS="$CLIENT_DIR/runstatus"
export STAGING_DIR="$HOME_DIR/staging"
export SCRIPT_DIR="$HOME_DIR/scripts/DFO"
export REF_DIR="$HOME_DIR/control/reffile"
export MAILFILE="$TEMP_DIR/mailfile"
export LOG_FILE="$HOME_DIR/log/restart_$UNIQUE_RUN_ID.log"
export TEMP_DATA_DIR="$HOME_DIR/temp/$UNIQUE_RUN_ID/dat"
export MAIL_SUBJECT="DFO process email subject"
export DBA_DATA_LOAD_DIR="/GDX/prod/control/dataload"

export CONTRACT_ADMIN_MAIL_LIST_FILE="$REF_DIR/DFO_contract_admin_maillist.ref"
export SUPPORT_MAIL_LIST_FILE="$REF_DIR/DFO_support_maillist.ref"
export MDA_SUPPORT_MAIL_LIST_FILE="$REF_DIR/DFO_notify_MDA.ref"
export CLIENTSTATUS="$HOME_DIR/client_status"
export MAIL_SUBJECT="In restarting after load failure"

#        run the kornshell to send a trigger to analytics 
#        indicating that the current client is done for this month
         $SCRIPT_DIR/DFO_ftp_to_dalcdcp.ksh $CLIENT_NAME >>$LOG_FILE 2>&1

#        clean up the staging area since we're done, we no longer need the input
#        file, anyways it's in $CLIENT_DIR/compressed_ftp_claims
         rm $STAGING_DIR/*$CLIENT_NAME*
         if [[ $? != 0 ]] then
            echo "problems removing $STAGING_DIR " >> $LOG_FILE
         fi

#        update the status for the client for this current process run
         print "completed" > $RUN_STATUS
                    
#        run the kornshell to check if all DFO clients are 'done'... then MDA 
#        processing can be initiated for this time frame
         $SCRIPT_DIR/DFO_chk_all_clts_complete.ksh $CLIENT_NAME >>$LOG_FILE 2>&1

#        we'll try to send the duplicates first

#        This kornshell will send the rejected duplicates
#        (in TCLAIM_EXT_EXCP) to the client via email
#        no need to send a client name since the DBA load script
#        will only load 1 load data set at a time and will not run
#        if there are rows in TCLAIM_EXT_EXCP.  Handle duplicates will
#        place the duplicate rows in 
#        $CLIENT_DIR/rejected/$UNIQUE_RUN_ID.duplicates
         
####         $SCRIPT_DIR/DFO_handle_duplicates.ksh $CLIENT_NAME $TEMP_DATA_DIR >>$LOG_FILE 

#        This kornshell will sent the rejects to the client,
#        store this concatenated rejected file in 
#        $CLIENT_DIR/rejected/$UNIQUE_RUN_ID.rejects
#        and send out a summary for this client to internal
#        Caremark personel with intake/rejected/accepted counts
         
         $SCRIPT_DIR/DFO_handle_rejects_integration.ksh $CLIENT_NAME $TEMP_DATA_DIR >>$LOG_FILE

         echo "Done baby!!!"  >>$LOG_FILE 
  exit
