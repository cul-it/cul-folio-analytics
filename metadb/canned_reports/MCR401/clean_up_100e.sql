--This report gets 100 field subfiled "e" value to check for the wrongly entered entries of the subfiel.


SELECT 
    sr.instance_hrid,
    sr.instance_id,
    sr.field AS marc_field,
    sr.sf AS marc_field_subfield,
    sr.CONTENT marc_subfield_content,
    i.creation_date::date AS record_date_created,
    --h.permanent_location_name,
    --i.created_by AS record_created_by,
    i.__current AS "current",
    --jsonb_extract_path_text(i.jsonb, 'metadata', 'updatedByUserId')::uuid AS record_user_uuid,
    jsonb_extract_path_text(i.jsonb, 'metadata', 'updatedDate')::date AS record_updated_date 
  FROM folio_source_record.marc__t sr
  LEFT JOIN folio_inventory.instance AS i ON sr.instance_id = i.id 
  --LEFT JOIN folio_derived.holdings_ext h ON i.id = h.instance_id 
  WHERE (sr.field ='100' and sr.sf='e' AND (sr.content not ilike '%author%' ))
  and (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%speaker%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%petitioner%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%editor%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%interviewer%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%photographer%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%composer%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%sculptor%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%defendant%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%compiler%')
  AND (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%artist%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%creator%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%illustrator%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%plaintiff%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%vocalist%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%judge%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%performer%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%collector%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%translator%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%instumentalist%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%cartographer%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%librettist%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%architect%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%annotator%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%complainant%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%curator%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%singer%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%conductor%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%narrator%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%lyricist%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%painter%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%correspondent%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%poet%')
  AND (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%colligrapher%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%interviewee%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%audio producer%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%reporter%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%designer%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%director%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%economist%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%producer%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%commentator%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%organizer%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%contestant%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%writer%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%arranger%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%engineer%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%responsible party%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%coordinator%')
  AND  (sr.field ='100' and sr.sf='e' AND sr.content not ILIKE '%investigator%')
;
