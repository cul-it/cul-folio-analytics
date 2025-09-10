-- MSQ101
-- remove_voyager_patron_ids.sql
-- written by: Peter Martinez
-- reviewed by: Sharon Markus, Joanne Leary
-- last updated: 8-28-25
-- This query removes patron identifiers and other patron-related data from these tables in 
-- the Metadb reporting database. The tables were migrated to Metadb from the CUL Voyager legacy system.
-- These tables contain static data, so this update script will only be run one time by our hosting team.
-- Voyager Tables impacted:
-- CALL_SLIP.PATRON_ID
-- HOLD_RECALL.PATRON_ID
-- LINE_ITEM.REQUESTOR ( Updating to ‘yes’ if populated)
-- CALL_SLIP.NOTE 
-- CALL_SLIP_ARCHIVE.NOTE
-- HOLD_RECALL.PATRON_COMMENT
-- HOLD_RECALL_ARCHIVE.PATRON_COMMENT


UPDATE 
	vger.call_slip
SET 
	patron_id = 0
;

UPDATE 
	vger.hold_recall 
SET 
	patron_id = 0
;

UPDATE 
	vger.line_item 
SET 
	requestor = 'yes'
WHERE
	requestor IS NOT NULL 
	AND requestor <> ''
;

UPDATE 
vger.call_slip
SET 
note = NULL	
;

UPDATE 
vger.hold_recall
SET
patron_comment = NULL
;

UPDATE 
vger.call_slip_archive
SET 
note = NULL	
;

UPDATE 
vger.hold_recall_archive 
SET 
patron_comment = NULL
;
