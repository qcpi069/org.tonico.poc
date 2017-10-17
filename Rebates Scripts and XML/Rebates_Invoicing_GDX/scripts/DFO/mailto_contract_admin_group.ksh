#!/usr/bin/ksh

     echo "E-mailing to contract admin group...." >> $LOG_FILE

     MAILTO=`cat $CONTRACT_ADMIN_MAIL_LIST_FILE`

##     cat $MAIL_BODY_FILE                    | \
##         sed s/CLIENT_NAME/$CLIENT_NAME/    | \
##         sed s/MONTH/$PROCESS_MONTH/        | \
##         sed s/YEAR/$PROCESS_YEAR/            \
##     > $MAILFILE
     
##     echo "WJP try 1 " >>$LOG_FILE 
##     cat $MAILFILE >> $LOG_FILE
    
     $SCRIPT_DIR/DFO_mail.ksh   \
             "$MAILTO"          \
             "$MAIL_SUBJECT"    \
             "$MAILFILE"
 
     if [[ $? = 0 ]] then
        echo "Contract admin group was e-mailed...." >> $LOG_FILE
        exit 0
     else
        echo "Problem encountered in mailing to Contract admin group" >> $LOG_FILE
        exit 1
     fi
