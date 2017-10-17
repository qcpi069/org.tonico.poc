#!/usr/bin/ksh

#================================================
#ACCEPTS ONE COMMAND LINE PARAMETER.
#================================================

  if [[ $# != 1 ]] then
     echo "mailto_CLIENT_group.ksh <CLIENT NAME>"
     exit 1
  fi


     echo "E-mailing to CLIENT group for $CLIENT_NAME...."

     MAILTO=`cat $CLIENT_DIR/client_maillist.ref`

     $SCRIPT_DIR/DFO_mail.ksh   \
             "$MAILTO"          \
             "$MAIL_SUBJECT"    \
             "$MAILFILE"

     if [[ $? = 0 ]] then
        echo "CLIENT group ($CLIENT_NAME) was e-mailed"
        cp -p $MAILFILE $CLIENT_DIR/last_client_email.txt
        exit 0
     else
        echo "Problem encountered in mailing to CLIENT group"
        cp -p $MAILFILE $CLIENT_DIR/last_client_email.txt
        exit 1
     fi
