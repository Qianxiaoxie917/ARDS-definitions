WITH ECMO_ids AS(

SELECT *
FROM `oxgenator.mimiciv_icu.d_items`
WHERE label LIKE '%ECMO%'
   OR label LIKE '%Extracorporeal%'
   OR label LIKE '%Membrane Oxygenation%'
   OR label LIKE '%Extracorporeal Membrane Oxygenation%'
   OR label LIKE '%Veno-arterial%'
   OR label LIKE '%Veno-venous%'
   OR label LIKE '%Extracorporeal Carbon Dioxide Removal%'
   OR label LIKE '%Carbon Dioxide Removal%'
   OR label LIKE '%ECCOR%'
   OR label LIKE '%ECCO2R%'
   OR label LIKE '%Extracorporeal CO2 Elimination%'
   OR label LIKE '%Low-flow ECMO%'
   
),


ID1 AS (

SELECT itemid
FROM  ECMO_ids
where linksto = 'chartevents'

),

ID2 AS (

SELECT itemid
FROM  ECMO_ids
where linksto = 'procedureevents'


),

SELECT *
FROM `oxgenator.mimiciv_icu.chartevents`
WHERE itemid IN (SELECT itemid FROM ID1)


SELECT *
FROM `oxgenator.mimiciv_icu.procedureevents`
WHERE itemid IN (SELECT itemid FROM ID1)


SELECT *
FROM `oxgenator.mimiciv_hosp.d_icd_diagnoses` 
WHERE icd_code  LIKE '%5A1522F%' 
   OR icd_code  LIKE '%5A1522G%' 
   OR icd_code  LIKE '%5A1522H%' 
   OR icd_code  LIKE '%39.65%' 









