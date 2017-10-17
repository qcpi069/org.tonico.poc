#!/usr/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSDY7000_KS_7450J_mf_refresh_views.ksh
# Title         : Refresh Mainframe KSCC tables from datamart views
#
# Description   : This script will refresh the Mainframe KSCC tables 
#                 from datamart views of tables extracted from Oracle Silver. 
# 
# Abends        : If count parm does not match insert results then set bad 
#                 return code.
#                 
#
# Parameters    : None 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 11-11-06   qcpi768     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

  cd $SCRIPT_PATH

#####################################################
# begin script functions
#
function Refresh_Table
#   usage: Refresh_Table |tablename|, returns return code 
{       
   typeset RC

   print "start mf_refresh_$1 "  `date` 
   print "start mf_refresh_$1 "  `date`                               >> $LOG_FILE 

   sqml $XML_PATH/mf_refresh_$1.xml                                    >> $LOG_FILE 
   RC=$?
   print "sqml retcode from mf_refresh_$1 was " $RC "   "`date` 
   print "sqml retcode from mf_refresh_$1 was " $RC "   "`date`        >> $LOG_FILE 
   return $RC
}


#
# end script functions
#####################################################

SCRIPT=RPS_KSDY7000_KS_7450J_mf_refresh_views
JOB=ks7450j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
RETCODE=0

echo $SCRIPT " start time: "`date` 
echo $SCRIPT " start time: "`date`                                     > $LOG_FILE



# okay
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc000"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# okay
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc001"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# okay
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc002"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# works but kinda slow, 20 minutes, over a million rows
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc007"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi


# okay - 5408 rows, deletes dependent children kscc017 and kscc012
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc013"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
# okay - 7156 rows - note: load AFTER kscc013
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc017"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
# okay - 7343 rows - note: load AFTER kscc017
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc012"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi


# okay
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc015"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# okay
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc026"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# okay - zero rows
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc210"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# okay
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc211"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi

# okay
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc212"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
 

# okay
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc214"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
 

# okay
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc215"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
 
# okay
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc216"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
 
# okay
if [[ $RETCODE == 0 ]]; then    
   TBLNAME="kscc217"
   Refresh_Table $TBLNAME
   export RETCODE=$?
fi
 
echo $SCRIPT " end time: "`date`                                      
echo $SCRIPT " end time: "`date`                                       >> $LOG_FILE 

#
# send email for script errors
#
if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "                          >> $LOG_FILE 
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   exit $RETCODE
fi


mv $LOG_FILE       $LOG_ARCH_PATH/ 
exit $RETCODE
