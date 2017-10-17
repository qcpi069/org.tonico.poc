#!/usr/bin/ksh

     echo "E-mailing to ACTUATE group...."

     MAILTO=`cat $ACTUATE_SUPPORT_MAIL_LIST_FILE`

     $SCRIPT_DIR/MDA_mail.ksh   \
             "$MAILTO"          \
             "$MAIL_SUBJECT"    \
             "$MAILFILE"

     if [[ $? = 0 ]] then
        echo "ACTUATE group was e-mailed"
        exit 0
     else
        echo "Problem encountered in mailing to ACTUATE group"
        exit 1
     fi
