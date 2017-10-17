#!/usr/bin/ksh

     echo "E-mailing to MDA support group...." >> $LOG_FILE

     MAILTO=`cat $MDA_SUPPORT_MAIL_LIST_FILE`

     $SCRIPT_DIR/DFO_mail.ksh   \
             "$MAILTO"          \
             "$MAIL_SUBJECT"    \
             "$MAILFILE"

     if [[ $? = 0 ]] then
        echo "MDA support group was e-mailed"
        exit 0
     else
        echo "Problem encountered in mailing to MDA support group"
        exit 1
     fi
