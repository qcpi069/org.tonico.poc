#!/bin/ksh
#--------------------------------------------------------------------------#
#   Date                 Description
# ----------  ----------  -------------------------------------------------#
# 10-13-2010    is90001   initial creation                                 #
#                         This script will do a db2 "truncate" on a table  #
#                         The input into this is the owner.table_name      #
#--------------------------------------------------------------------------#

. `dirname $0`/Common_RCI_Environment.ksh

. /home/user/udbcae/sqllib/db2profile

export DT=`date +"%Y%j%H%M"`

echo "
connect to $DATABASE user $LOADER_CONNECT_ID using $LOADER_CONNECT_PWD;
LOAD FROM /dev/null OF DEL REPLACE INTO $1 nonrecoverable
;
" | db2 +p -vt -z $LOG_DIR/truncate.$1.$DT.log
#-------------------


