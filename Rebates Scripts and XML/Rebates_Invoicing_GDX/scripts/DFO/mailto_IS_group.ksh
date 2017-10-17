#!/usr/bin/ksh

     echo "E-mailing to IS group...."

     MAILTO=`cat $SUPPORT_MAIL_LIST_FILE`

     $SCRIPT_DIR/DFO_mail.ksh   \
             "$MAILTO"          \
             "$MAIL_SUBJECT"    \
             "$MAILFILE"

     if [[ $? = 0 ]] then
        echo "IS group was e-mailed"
        exit 0
     else
        echo "Problem encountered in mailing to IS group"
        exit 1
     fi
