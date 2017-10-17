#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GDWKSUN1_GD_0122J_QL_tdrug_load.ksh 
# Title         : vrap.TDRUG import process
#
# Description   : Loads vrap.TDRUG data file from QL mainframe into the tables
#									VRAP.TDRUG     
#
# Parameters    : None. 
#  
# Input         : vrap.TDRUG.dat
# 
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 09/09/2015  qcpi733     Removed calls to Common_Prcs* scripts and 
#                         associated variables.
# 08/17/2007  Gries	  PSP changes
# 03-09-2006  S.  Hull    Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/Common_GDX_Environment.ksh

SUBDIR="QLdata"
LOG_FILE="$LOG_PATH/GDX_GDWKSUN1_GD_0122J_QL_tdrug_load.log"
SCRIPT=$(basename $0)
cp -f $LOG_FILE $LOG_ARCH_PATH/GDX_GDWKSUN1_GD_0122J_QL_tdrug_load.log.`date +"%Y%j%H%M"`
rm -f $LOG_FILE

CALLED_SCRIPT=$SUBSYSTEM"GDX_GDWKSUN1_GD_0122J_QL_tdrug_load.ksh"
print "Starting " $CALLED_SCRIPT                    >> $LOG_FILE

#OK_FILE="$INPUT_PATH/$SUBDIR/mda.vrap.tdrug.ok"
DAT_FILE="$INPUT_PATH/$SUBDIR/mda.vrap.tdrug.dat"

ARCH_DAT_FILE="$DAT_FILE $INPUT_PATH/$SUBDIR/vrap.TDRUG.old"
print "Archive Data file           " $ARCH_DAT_FILE  >> $LOG_FILE
cp -f $DAT_file $ARCH_DAT_FILE


#################################################################################
#
# 1.  Check for File Existance 
#
#################################################################################

if [[ ! -s $DAT_FILE ]]; then         # is $myfile a regular file?
  print "Something wrong with/or missing input file $DAT_FILE  "     >> $LOG_FILE
  RETCODE=1
  return $RETCODE   
fi
  
#################################################################################
#
# ?.  Set up the SQL and Connect to the Database 
#
#################################################################################

SQL_STRING="import from $DAT_FILE of asc "
SQL_STRING=$SQL_STRING"method L (1 11, 12 15, 16 16, 17 18, 19 20 ,21 22, 23 24, 25 26, 27 28, 29 30, 31 39, "
SQL_STRING=$SQL_STRING" 40 44, 45 48 ,49 50, 51 51, 52 55, 56 66, 67 68, 69 72, 73 73, 74 79, 80 83 ,84 84, " 
SQL_STRING=$SQL_STRING" 85 95, 96 125, 126 129, 130 159, 160 163, 164 193, 194 197 ,198 209, 210 214, 215 218, " 
SQL_STRING=$SQL_STRING" 219 222, 223 234, 235 246, 247 249 ,250 257, 258 263, 264 267, 268 278, 279 289, 290 293, " 
SQL_STRING=$SQL_STRING" 294 295 ,296 303, 304 313, 314 317, 318 329, 330 342, 343 346, 347 347, 348 351, 352 355, "
SQL_STRING=$SQL_STRING" 356 359, 361 364, 365 365, 366 369, 370 370, 371 371, 372 385, 386 395, 396 421, 422 447, "
SQL_STRING=$SQL_STRING" 448 451, 452 460, 17 26, 1 11, 1 9, 1 9, 623 626, 627 628, 629 632, 633 636, 637 640) " 
SQL_STRING=$SQL_STRING" commitcount 10000 "
SQL_STRING=$SQL_STRING" replace into vrap.tdrug  " 
SQL_STRING=$SQL_STRING" (DRUG_NDC_ID, NHU_TYP_CD, LMT_STBLTY_CD, GPI_GRP, GPI_CLS, GPI_SUB_CLS,"
SQL_STRING=$SQL_STRING" GPI_NM, GPI_EXT_NM, GPI_FORM, GPI_STRGH, DRUG_PROD_ID, NDC5_NB, DEA_CLS_CD, "
SQL_STRING=$SQL_STRING" RTE_OF_ADMIN_CD, STRGE_COND_CD, DSG_FORM_CD, MTRC_STRGH_UM_CD, DRUG_PKG_UM_CD," 
SQL_STRING=$SQL_STRING" LAYOUT_FORMAT_CD, UNIT_DOSE_CD, FORMLY_THERACLS_CD, DRUG_PRC_CLS_CD, DRUG_BRAND_CD, "
SQL_STRING=$SQL_STRING" GENC_NDC_IN, DRUG_NM, DRUG_MULT_SRC_IN, DRUG_MFR_NM, DISCNTU_IN, DRUG_INGRED_NM, ALRGY_PTRN_NB, "
SQL_STRING=$SQL_STRING" DRUG_PKG_SIZE_QTY, DRUG_PTRN_CD, RX_IN, DRUG_MAINT_IN, METRIC_STRGH_QTY, DRUG_ABBR_PROD_NM, "
SQL_STRING=$SQL_STRING" DRUG_ABBR_DSG_NM, DRUG_ABBR_STRGH_NM, DRUG_CD_NM, DRUG_DESI_IN, DRUG_THOU_NDC_ID, "
SQL_STRING=$SQL_STRING" DRUG_HUND_NDC_ID, GENC_AVAIL_IN, THERAPTC_EQVLT_CD, GENC_PROD_PKG_NB, DISCONTU_DT, THERPTC_CLS_CD,"
SQL_STRING=$SQL_STRING" DRUG_USG_PKG_QTY, TOTL_PKG_QTY, MULT_INGRED_IN, SHIP_STRGE_CD, INV_DRUG_PRC_CLS,"
SQL_STRING=$SQL_STRING" PT_CONSULT_PTRN_CD, CTS_DRUG_IN, REIMB_COND_CD, LABELER_TYPE_CD, PRICING_SPREAD_CD, BRAND_NAME_CD, "
SQL_STRING=$SQL_STRING" MULT_SRC_CD, DRG_ABV_PRU_EXT_NM, DRG_ABV_STG_EXT_NM, HSC_TS, HSU_TS, DGH_EXT_MNT_IN, DGH_GCN_CD, " 
SQL_STRING=$SQL_STRING" GPI_LC10_ID, NDC_LC11_ID, NDC_LC9_ID, NDC_LD9_ID, DRUG_INNERPACK_CD, LMT_DSTR_CD, VTNR_DRUG_CD, MEDI_BLK_CD, MEDI_DRUG_RPKG_CD)"  


###################################################################################
#
# Import drug class data with replace option into table 
# vrap.tdrug
#
#    NOTE:  Please note there is not SQL connect step.  The calls to the common process
#           logging establishes the DB2 connection for this process.  
#
###################################################################################

print $SQL_STRING  >> $LOG_FILE 
db2 -p $SQL_STRING >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Script " $CALLED_SCRIPT "failed in the vrap.tdrug step." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">" >> $LOG_FILE
   RETCODE=1
   return $RETCODE
fi   


###################################################################################
#
# Update the  vrap.tdrug table. 
#
###################################################################################

SQL_UPDATE_STRING="update vrap.tdrug td " 
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" set td.ndc_lc11_id_nm = RTRIM(DRUG_ABBR_PROD_NM) || ' ' || RTRIM(DRUG_ABBR_DSG_NM) || ' '|| "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" RTRIM(DRUG_ABBR_STRGH_NM) || ' ' || RTRIM(CHAR(CAST(DRUG_PKG_SIZE_QTY AS INTEGER))) || '.' || "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" RTRIM(CHAR(MOD(CAST(DRUG_PKG_SIZE_QTY*100 AS INTEGER), 100))), "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" td.ndc_lc9_id_nm  = (select n9.NDC_LC9_ID_NM from "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" (SELECT td9n.NDC_LC9_ID, td9n.NDC_LC9_ID_NM  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" FROM (SELECT td9.NDC_LC9_ID, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" RTRIM(td9.DRUG_ABBR_PROD_NM) || ' ' || "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" RTRIM(td9.DRUG_ABBR_DSG_NM)  || ' ' || " 
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" RTRIM(td9.DRUG_ABBR_STRGH_NM) NDC_LC9_ID_NM, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" ROW_NUMBER() OVER( PARTITION BY td9.NDC_LC9_ID ORDER BY td9.DRUG_NDC_ID, td9.NHU_TYP_CD) "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" RANK_NDC_LC9_ID_NM  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" FROM VRAP.TDRUG td9) td9n " 
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" WHERE td9n.RANK_NDC_LC9_ID_NM = 1) n9 "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" where n9.ndc_lc9_id = td.ndc_lc9_id), "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" td.gpi_lc10_id_nm = (select g.GPI_LC10_ID_NM from "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" (SELECT tdgn.GPI_LC10_ID, tdgn.GPI_LC10_ID_NM "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"   FROM ( SELECT tdg.GPI_LC10_ID, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" tdg.DRUG_ABBR_PROD_NM GPI_LC10_ID_NM, "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" ROW_NUMBER() OVER( PARTITION BY tdg.GPI_LC10_ID ORDER BY tdg.DRUG_NDC_ID, tdg.NHU_TYP_CD) AS "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  RANK_GPI_LC10_ID_NM "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" FROM VRAP.TDRUG tdg) tdgn  "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING"  WHERE tdgn.RANK_GPI_LC10_ID_NM = 1) g "
SQL_UPDATE_STRING=$SQL_UPDATE_STRING" where g.gpi_lc10_id = td.gpi_lc10_id) " 

db2 -p $SQL_UPDATE_STRING >> $LOG_FILE


RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Script " $CALLED_SCRIPT "failed in the Update vrap.tdrug step." >> $LOG_FILE
   print "DB2 return code is : <" $RETCODE ">" >> $LOG_FILE
   RETCODE=1
   return $RETCODE
fi 

#rm -f $OK_FILE
rm -f $DAT_FILE

print "....Completed executing " $CALLED_SCRIPT " ...."   >> $LOG_FILE

return $RETCODE
