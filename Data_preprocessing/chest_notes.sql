WITH chest0 AS (
    SELECT * 
    FROM `oxgenator.mimiciv_note.radiology` 
    WHERE text LIKE '%CHEST%' 
)

SELECT *, CAST(1 AS INT64) AS bilateral_infiltrates
FROM chest0
WHERE 
(
    REGEXP_CONTAINS(text, r'bilateral (\w)* ?(\w)* ?(opaci|infil|haziness)') 
    OR REGEXP_CONTAINS(text, r'(?i)(opaci|infil|hazy|haziness)([\w ]+)bilaterally') 
    OR REGEXP_CONTAINS(text, r'(?i)(edema)')
)
AND NOT 
(
    REGEXP_CONTAINS(text, r'(?i)\b(no|without)\b[\w\s]*(bilateral (\w)* ?(\w)* ?(opaci|infil|haziness)|edema|(opaci|infil|hazy|haziness)([\w ]+)bilaterally)\b')
    OR REGEXP_CONTAINS(text, r'(?i)\bthere (is no|is no evidence of)\b[\w\s]*(bilateral (\w)* ?(\w)* ?(opaci|infil|haziness)|edema|(opaci|infil|hazy|haziness)([\w ]+)bilaterally)\b')
)

