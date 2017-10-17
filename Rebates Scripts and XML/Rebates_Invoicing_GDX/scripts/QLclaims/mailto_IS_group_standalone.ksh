#!/usr/bin/ksh

     echo "E-mailing to IS group...."

export MAILTO=`cat /vracobol/prod/control/reffile/MDA_support_maillist.ref`
export MAIL_SUBJECT="Test email"
export MAILFILE="/vracobol/test/script/mailfile_test"
    
echo "email to these dudes: $MAILTO"
     /vracobol/prod/script/MDA_mail.ksh   \
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
