#!/bin/ksh
# This will rename the daily T_CLAIM files for out of balance processing.
. `dirname $0`/Common_RCI_Environment.ksh

# Changes made as part of APMCAS project to add files for T_CLAIM_AETNA source - 10/20/2012
# Changes made as part of Med Claims project to add files for T_CLAIM_RUC source - 01/01/2013

###### BCI  ######
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_ALV_RCIT_BASE_CLM_INV.out    $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_ALV_RCIT_BASE_CLM_INV.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RCIT_BASE_CLM_INV.out        $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RCIT_BASE_CLM_INV.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RXA_RCIT_BASE_CLM_INV.out    $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RXA_RCIT_BASE_CLM_INV.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_QL_RCIT_BASE_CLM_INV.out     $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_QL_RCIT_BASE_CLM_INV.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_MEDB_RCIT_BASE_CLM_INV.out   $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_MEDB_RCIT_BASE_CLM_INV.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_AETNA_RCIT_BASE_CLM_INV.out  $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_AETNA_RCIT_BASE_CLM_INV.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RUC_RCIT_BASE_CLM_INV.out    $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RUC_RCIT_BASE_CLM_INV.out.orig
###### APC  ######
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_ALV_RCIT_BASE_CLM_APC.out    $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_ALV_RCIT_BASE_CLM_APC.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RCIT_BASE_CLM_APC.out        $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RCIT_BASE_CLM_APC.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RXA_RCIT_BASE_CLM_APC.out    $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RXA_RCIT_BASE_CLM_APC.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_QL_RCIT_BASE_CLM_APC.out     $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_QL_RCIT_BASE_CLM_APC.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_MEDB_RCIT_BASE_CLM_APC.out   $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_MEDB_RCIT_BASE_CLM_APC.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_AETNA_RCIT_BASE_CLM_APC.out  $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_AETNA_RCIT_BASE_CLM_APC.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RUC_RCIT_BASE_CLM_APC.out    $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RUC_RCIT_BASE_CLM_APC.out.orig
###### OVRD_AUDT  ######
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_ALV_RCIT_CLM_OVRD_AUDT.out   $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_ALV_RCIT_CLM_OVRD_AUDT.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RCIT_CLM_OVRD_AUDT.out       $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RCIT_CLM_OVRD_AUDT.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RXA_RCIT_CLM_OVRD_AUDT.out   $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RXA_RCIT_CLM_OVRD_AUDT.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_QL_RCIT_CLM_OVRD_AUDT.out    $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_QL_RCIT_CLM_OVRD_AUDT.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_MEDB_RCIT_CLM_OVRD_AUDT.out  $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_MEDB_RCIT_CLM_OVRD_AUDT.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_AETNA_RCIT_CLM_OVRD_AUDT.out $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_AETNA_RCIT_CLM_OVRD_AUDT.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RUC_RCIT_CLM_OVRD_AUDT.out   $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RUC_RCIT_CLM_OVRD_AUDT.out.orig
###### DUP_REF  ######
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_ALV_RCIT_RVRS_DUP_REF.out    $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_ALV_RCIT_RVRS_DUP_REF.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RCIT_RVRS_DUP_REF.out        $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RCIT_RVRS_DUP_REF.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RXA_RCIT_RVRS_DUP_REF.out    $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RXA_RCIT_RVRS_DUP_REF.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_QL_RCIT_RVRS_DUP_REF.out     $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_QL_RCIT_RVRS_DUP_REF.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_MEDB_RCIT_RVRS_DUP_REF.out   $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_MEDB_RCIT_RVRS_DUP_REF.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_AETNA_RCIT_RVRS_DUP_REF.out  $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_AETNA_RCIT_RVRS_DUP_REF.out.orig
mv $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RUC_RCIT_RVRS_DUP_REF.out    $REBATES_HOME/SrcFiles/m_Extract_T_CLAIM_RUC_RCIT_RVRS_DUP_REF.out.orig

return $?
