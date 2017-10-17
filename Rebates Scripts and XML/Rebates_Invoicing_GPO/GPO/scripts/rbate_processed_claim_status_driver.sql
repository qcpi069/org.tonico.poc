set timing on
whenever sqlerror exit 1
SPOOL /staging/apps/rebates/prod/output/rbate_processed_claim_status_driver.log
alter session enable parallel dml; 
exec PK_REBATE_DRIVERS.processed_claim_status_driver('200441');
EXIT
