WITH

mortality_type AS (
SELECT
  icu.stay_id AS stay_id,
  CASE WHEN admissions.deathtime BETWEEN admissions.admittime and admissions.dischtime
  THEN 1 
  ELSE 0
  END AS mortality_in_Hospt, 
  CASE WHEN admissions.deathtime BETWEEN icu.intime and icu.outtime
  THEN 1
  ELSE 0
  END AS mortality_in_ICU,
  CASE WHEN DATETIME_DIFF(admissions.deathtime, icu.intime, DAY) <= 30 AND admissions.deathtime IS NOT NULL
       THEN 1
       ELSE 0
  END AS mortality_within_30_days,
  admissions.deathtime as deathtime, 
  icu.intime as ICU_intime,
  admissions.race
FROM `oxgenator.mimiciv_icu.icustays` AS icu
INNER JOIN `oxgenator.mimiciv_hosp.admissions` AS admissions
  ON icu.hadm_id = admissions.hadm_id),

---  table from 'mimiciv_vent_ards.sql'
vd_ards AS (

SELECT *
FROM `oxgenator.mimiciv_derived.ventilation_ards` 

),


-- Extract the SpO2 measurements that happen during ventilation
 ce AS (
  SELECT DISTINCT 
    chart.stay_id
    , chart.valuenum as spO2_Value
    , chart.charttime
  FROM `oxgenator.mimiciv_icu.chartevents` AS chart
    INNER JOIN vd_ards ON chart.stay_id = vd_ards.stay_id
      AND vd_ards.initial_time <= chart.charttime
      AND vd_ards.end_time >= chart.charttime
  WHERE chart.itemid in (220277, 646) 
    AND chart.valuenum IS NOT NULL
    -- exclude rows marked as warning
    AND (chart.warning <> 1 OR chart.warning IS NULL) --chart.warning IS DISTINCT FROM 1
    -- We remove oxygen measurements that are outside of the range [10, 100]
    AND chart.valuenum >= 10
    AND chart.valuenum <= 100
),


-- Extract the FiO2 measurements that happen during ventilation
 Fe AS (
  SELECT DISTINCT 
    chart.stay_id,
    CASE 
        -- Convert FiO2 values from fraction to percentage
        WHEN chart.valuenum > 0.2 AND chart.valuenum <= 1 THEN chart.valuenum * 100
        -- improperly input data - looks like O2 flow in litres
        WHEN chart.valuenum > 1 AND chart.valuenum < 20 THEN NULL 
        WHEN chart.valuenum >= 20 AND chart.valuenum <= 100 THEN chart.valuenum
        ELSE NULL 
    END AS FiO2_Value,
    chart.charttime
  FROM `oxgenator.mimiciv_icu.chartevents` AS chart
    INNER JOIN vd_ards ON chart.stay_id = vd_ards.stay_id
      AND vd_ards.initial_time <= chart.charttime
      AND vd_ards.end_time >= chart.charttime
  WHERE 
    chart.itemid = 223835 
    AND chart.valuenum IS NOT NULL
    -- exclude rows marked as warning
    AND (chart.warning <> 1 OR chart.warning IS NULL)
    -- We ensure only valid FiO2 values are included
    AND (
        (chart.valuenum > 0.2 AND chart.valuenum <= 1) 
        OR (chart.valuenum >= 20 AND chart.valuenum <= 100)
    )

)


-- Computing summaries of the blood oxygen saturation (SpO2)
, SpO2 AS (
  -- Edited from https://github.com/cosgriffc/hyperoxia-sepsis
  SELECT DISTINCT
      ce.stay_id
      -- We currently ignore the time aspect of the measurements.
      -- However, one ideally should take into account that
      -- certain measurements are less spread out than others.
   , COUNT(ce.spO2_Value) OVER(PARTITION BY ce.stay_id) AS nOxy
    , PERCENTILE_CONT(ce.spO2_Value, 0.5) OVER(PARTITION BY ce.stay_id) AS median_SpO2
    , AVG(ce.spO2_Value) OVER(PARTITION BY ce.stay_id) AS avg_SpO2
  FROM ce
), 

FiO2 AS (

SELECT DISTINCT Fe.stay_id 

, COUNT(Fe.FiO2_Value) OVER(PARTITION BY Fe.stay_id) AS nFiO2
    , PERCENTILE_CONT(Fe.FiO2_Value, 0.5) OVER(PARTITION BY Fe.stay_id) AS median_FiO2
    , AVG(Fe.FiO2_Value) OVER(PARTITION BY Fe.stay_id) AS avg_FiO2

FROM Fe

)

, SpO2_24 AS (
  -- Edited from https://github.com/cosgriffc/hyperoxia-sepsis
  SELECT DISTINCT
      ce.stay_id
      -- We currently ignore the time aspect of the measurements.
      -- However, one ideally should take into account that
      -- certain measurements are less spread out than others.
   , COUNT(ce.spO2_Value) OVER(PARTITION BY ce.stay_id) AS nOxy_24
    , PERCENTILE_CONT(ce.spO2_Value, 0.5) OVER(PARTITION BY ce.stay_id) AS median_SpO2_24
    , AVG(ce.spO2_Value) OVER(PARTITION BY ce.stay_id) AS avg_SpO2_24
  FROM ce
   INNER JOIN vd_ards ON ce.stay_id = vd_ards.stay_id
  WHERE DATETIME_DIFF(ce.charttime, vd_ards.initial_time, HOUR) <= 24
), 

FiO2_24 AS (

SELECT DISTINCT Fe.stay_id 

, COUNT(Fe.FiO2_Value) OVER(PARTITION BY Fe.stay_id) AS nFiO2_24
    , PERCENTILE_CONT(Fe.FiO2_Value, 0.5) OVER(PARTITION BY Fe.stay_id) AS median_FiO2_24
    , AVG(Fe.FiO2_Value) OVER(PARTITION BY Fe.stay_id) AS avg_FiO2_24

FROM Fe
 INNER JOIN vd_ards ON Fe.stay_id = vd_ards.stay_id
WHERE DATETIME_DIFF(Fe.charttime, vd_ards.initial_time, HOUR) <= 24

)

,height AS (
SELECT DISTINCT * FROM `oxgenator.mimiciv_derived.first_day_height`
),

weight AS (
SELECT DISTINCT * FROM `oxgenator.mimiciv_derived.first_day_weight`
),


-- `patients` on our Google cloud setup has each ICU stay duplicated 7 times.
-- We get rid of these duplicates.
pat AS (
	SELECT DISTINCT * FROM `oxgenator.mimiciv_hosp.patients`
),

age AS (
	SELECT DISTINCT * FROM `oxgenator.mimiciv_derived.age`
),


icu AS (SELECT *
        FROM   `oxgenator.mimiciv_icu.icustays`),
        
----there are duplicates in the final table, create two more tables to get rid of duplicates
pre_results AS (SELECT DISTINCT
icu.hadm_id AS HADM_id,       
icu.stay_id AS stay_id,       
icu.subject_id AS patient_ID,
pat.gender AS gender,
age.age AS age,
DATETIME_DIFF(icu.outtime, icu.intime, HOUR) / 24 AS icu_length_of_stay,
mortality_type.* EXCEPT(stay_id),
DENSE_RANK() OVER (PARTITION BY icu.subject_id ORDER BY icu.intime) = 1 AS first_stay,
icd.* EXCEPT(hadm_id), ecmo.itemid, 
apsiii.apsiii,
sofa.sofa_24hours AS sofatotal,
height.height AS height,
weight.weight as weight,
icu.first_careunit as unittype,
fpo.o2flow_min as o2flow_min,
fpo.o2flow_max as o2flow_max,
fba.pao2fio2ratio_min as pao2fio2ratio_min,
fba.pao2fio2ratio_max as pao2fio2ratio_max,
fsr.spo2fio2ratio_min as spo2fio2ratio_min,
fsr.spo2fio2ratio_max as spo2fio2ratio_max,
fpo.peep_min as peep_min,
fpo.peep_max as peep_max,
SpO2.* EXCEPT(stay_id), FiO2.* EXCEPT(stay_id), 
SpO2_24.* EXCEPT(stay_id), FiO2_24.* EXCEPT(stay_id), vd_ards.vent_duration, vd_ards.ventialtion_status, vd_ards.vent_status, chest.bilateral_infiltrates as chest_ards
FROM icu
LEFT JOIN age 
  ON icu.hadm_id = age.hadm_id
LEFT JOIN pat
  ON icu.subject_id = pat.subject_id
LEFT JOIN `oxgenator.mimiciv_note.chest_notes` AS chest
  ON icu.subject_id = chest.subject_id
LEFT JOIN height
  ON icu.stay_id = height.stay_id
LEFT JOIN weight
  ON icu.stay_id = weight.stay_id
LEFT JOIN mortality_type
  ON icu.stay_id = mortality_type.stay_id
LEFT JOIN `oxgenator.mimiciv_derived.ards_icd` AS icd 
  ON icu.hadm_id = icd.hadm_id
LEFT JOIN `oxgenator.mimiciv_derived.ecmo` AS ecmo 
  ON icu.hadm_id = ecmo.hadm_id
LEFT JOIN `oxgenator.mimiciv_derived.apsiii` AS apsiii
  ON icu.stay_id = apsiii.stay_id
LEFT JOIN `oxgenator.mimiciv_derived.sofa` sofa 
  ON icu.stay_id = SOFA.stay_id
LEFT JOIN vd_ards
  ON icu.stay_id = vd_ards.stay_id
LEFT JOIN SpO2
  ON icu.stay_id = SpO2.stay_id
LEFT JOIN FiO2
  ON icu.stay_id = FiO2.stay_id
LEFT JOIN SpO2_24
  ON icu.stay_id = SpO2_24.stay_id
LEFT JOIN FiO2_24
  ON icu.stay_id = FiO2_24.stay_id
LEFT JOIN `oxgenator.mimiciv_derived.first_day_bg_art` AS fba
  ON icu.stay_id = fba.stay_id
LEFT JOIN `oxgenator.mimiciv_derived.first_day_peep_o2flow` AS fpo
  ON icu.stay_id = fpo.stay_id
LEFT JOIN `oxgenator.mimiciv_derived.first_day_SF_ratio` AS fsr
  ON icu.stay_id = fsr.stay_id
  ),
  
tmp_results AS (

SELECT *, ROW_NUMBER() OVER (PARTITION BY patient_ID, HADM_id, stay_id ORDER BY patient_ID) AS pat_RN
FROM pre_results

)
  
  
  
SELECT * EXCEPT(pat_RN)

FROM tmp_results

WHERE pat_RN = 1

  
  
  