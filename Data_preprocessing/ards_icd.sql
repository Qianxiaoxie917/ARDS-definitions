----select ARDS patients from icd codes (9 and 10)
WITH icd_presence AS (
SELECT
icd.hadm_id, icd.icd_code,
CASE WHEN icd.icd_version = 9
THEN SAFE_CAST(SUBSTR(icd.icd_code, 0, 5) as INT64) 
END AS icd_num,
CASE WHEN icd.icd_version = 10
THEN icd.icd_code END AS icd_num_string, icd_version
FROM `oxgenator.mimiciv_hosp.diagnoses_icd` AS icd)

SELECT
icd_presence.hadm_id AS hadm_id,
COUNT(CASE WHEN icd_presence.icd_code  LIKE 'J80%' or icd_presence.icd_code LIKE '51882%' THEN 1 END) > 0 AS has_ards_disease,
COUNT(CASE WHEN icd_presence.icd_code  LIKE 'I50%'   or 
icd_presence.icd_num = 428  THEN 1 END) > 0 AS has_heart_failure_disease
FROM icd_presence
GROUP BY icd_presence.hadm_id
