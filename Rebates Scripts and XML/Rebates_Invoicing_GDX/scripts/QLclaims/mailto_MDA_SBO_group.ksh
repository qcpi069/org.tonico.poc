#!/usr/bin/ksh

## MDA_SBO_MAIL_LIST_FILE='/GDX/prod/control/reffile/MDA_SBO_maillist.ref'
## MAIL_SUBJECT='MDA weekly claims intake process auditing info'
## MAILFILE='/GDX/prod/temp/T20050627061100_P2494612/mailfile_sbo_copy'
## SCRIPT_DIR='/GDX/prod/scripts/QLclaims'

     echo "E-mailing to MDA SBO group...."

     MAILTO=`cat $MDA_SBO_MAIL_LIST_FILE`

     $SCRIPT_DIR/MDA_mail.ksh   \
             "$MAILTO"          \
             "$MAIL_SUBJECT"    \
             "$MAILFILE"

     if [[ $? = 0 ]] then
        echo "MDA SBO group was e-mailed"
        exit 0
     else
        echo "Problem encountered in mailing to MDA SBO group"
        exit 1
     fi
