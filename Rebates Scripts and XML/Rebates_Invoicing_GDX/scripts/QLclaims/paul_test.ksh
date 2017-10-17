#!/usr/bin/ksh

echo "testing for Paul BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
#!/bin/ksh
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Script Name: newactuate_bkup
#
# Author: Joseph Sajkiewicz, Caremark,Rx, INC. MidRange Group
#
# Description: This script backs up the three selected directories for
#              Actuate, object,admin, and request. The script uses a
#              combination of a find and cpio with the dumpv option to
#              backup to similarly named directories in the backup_lfs
#              directories.
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~ HISTORY ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 03/31/2004    Modified by: Paul Perreault
#               Added the server name to the backup directory.
#               Defined the var HOSTNAME
#               Change BKUPDIR="encyc_`date +"%m%d%y"`" to the following
#               BKUPDIR=$HOSTNAME"_encyc_`date +"%y%b%d_%T"`
#
#               BACKUP FILE NAME = loki_encyc_04Mar31_13:40:05
#               LOG FILE NAME = loki_bkuplog.04Mar31_13:40:05
#
#
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
DIR="/backup_lfs/logs"
#HOSTNAME=`hostname`
if [[ $# != 1 ]] then
        echo "USAGE: newactuate_bkup.ksh <Volume>"
        exit 1
else
        export VOLUME=$1
fi
echo $VOLUME
HOSTNAME=`hostname`
