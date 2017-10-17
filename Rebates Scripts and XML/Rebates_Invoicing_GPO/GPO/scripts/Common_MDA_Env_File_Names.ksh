#!/bin/ksh
############################################################
#
# Common named variables
#
############################################################
#
CMEFN_SCRIPT_NAME="Common_MDA_Env_File_Names.ksh"
export SCRIPTNAME=$FILE_BASE".ksh"
export LOG_FILE=$LOG_PATH/$FILE_BASE".log"
export LOG_FILE_ARCH=$LOG_ARCH_PATH/$FILE_BASE".log"
export OUTPUT_FILE=$LOG_PATH/$FILE_BASE"_output.dat"
export SQL_FILE_NAME=$SQL_PATH/$FILE_BASE".sql"
#
print " "                                                     >> $LOG_FILE
print " Starting  $CMEFN_SCRIPT_NAME"                         >> $LOG_FILE
print " "                                                     >> $LOG_FILE
print "#####################################################" >> $LOG_FILE
print "#                                                   #" >> $LOG_FILE
print "#  Environment variables set in $CMEFN_SCRIPT_NAME  #" >> $LOG_FILE
print "#  are:                                             #" >> $LOG_FILE
print "#                                                   #" >> $LOG_FILE
print "#  SCRIPTNAME = $SCRIPTNAME "                          >> $LOG_FILE
print "#  LOG_FILE = $LOG_FILE "                              >> $LOG_FILE
print "#  LOG_FILE_ARCH = $LOG_FILE_ARCH "                    >> $LOG_FILE
print "#  OUTPUT_FILE = $OUTPUT_FILE "                        >> $LOG_FILE
print "#  SQL_FILE_NAME = $SQL_FILE_NAME "                    >> $LOG_FILE
print "#                                                   #" >> $LOG_FILE
print "#                                                   #" >> $LOG_FILE
print "#####################################################" >> $LOG_FILE
print " "                                                     >> $LOG_FILE
print " "                                                     >> $LOG_FILE
print " Completed  $CMEFN_SCRIPT_NAME"                        >> $LOG_FILE
print " "                                                     >> $LOG_FILE
