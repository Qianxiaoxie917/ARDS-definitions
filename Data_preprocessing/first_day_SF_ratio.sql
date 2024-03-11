-- The aim of this query is to pivot entries related to blood gases
-- which were found in LABEVENTS
WITH bg AS (
    SELECT
        -- specimen_id only ever has 1 measurement for each itemid
        -- so, we may simply collapse rows using MAX()
        MAX(subject_id) AS subject_id
        , MAX(charttime) AS charttime
        -- fix a common unit conversion error for fio2
        -- atmospheric o2 is 20.89%, so any value <= 20 is unphysiologic
        -- usually this is a misplaced O2 flow measurement
        , MAX(CASE WHEN itemid = 50816 THEN
                CASE
                    WHEN valuenum > 20 AND valuenum <= 100 THEN valuenum
                    WHEN
                        valuenum > 0.2 AND valuenum <= 1.0 THEN valuenum * 100.0
                    ELSE NULL END
            ELSE NULL END) AS fio2
    FROM `oxgenator.mimiciv_hosp.labevents` le
    WHERE le.itemid IN
        -- blood gases
        (
            50816 -- fio2
        )
    GROUP BY le.specimen_id
)

, stg_spo2 AS (
    SELECT subject_id, charttime
        -- avg here is just used to group SpO2 by charttime
        , MAX(valuenum) AS spo2
    FROM `oxgenator.mimiciv_icu.chartevents`
    WHERE itemid = 220277 -- O2 saturation pulseoxymetry
        AND valuenum > 0 AND valuenum <= 100
    GROUP BY subject_id, charttime
)

, stg_fio2 AS (
    SELECT subject_id, charttime
        -- pre-process the FiO2s to ensure they are between 21-100%
        , MAX(
            CASE
                WHEN valuenum > 0.2 AND valuenum <= 1
                    THEN valuenum * 100
                -- improperly input data - looks like O2 flow in litres
                WHEN valuenum > 1 AND valuenum < 20
                    THEN NULL
                WHEN valuenum >= 20 AND valuenum <= 100
                    THEN valuenum
                ELSE NULL END
        ) AS fio2
    FROM `oxgenator.mimiciv_icu.chartevents`
    WHERE itemid = 223835 -- Inspired O2 Fraction (FiO2)
        AND valuenum > 0 AND valuenum <= 100
    GROUP BY subject_id, charttime
),

stg AS (

SELECT subject_id, charttime, MIN(fio2) AS fio2
FROM (
    SELECT subject_id, charttime, fio2 FROM bg
    UNION ALL
    SELECT subject_id, charttime, fio2 FROM stg_fio2
) AS combined
GROUP BY subject_id, charttime

)


, stg2 AS (
    SELECT 
        stg.*
        , ROW_NUMBER() OVER (
            PARTITION BY stg.subject_id, stg.charttime 
            ORDER BY 
                CASE 
                    WHEN s1.spo2 IS NULL THEN 3
                    WHEN s1.spo2 > 97 THEN 2 
                    ELSE 1 
                END, 
                s1.charttime DESC
        ) AS lastrowspo2
        , s1.spo2
    FROM stg
    LEFT JOIN stg_spo2 s1
        ON stg.subject_id = s1.subject_id
        AND s1.charttime BETWEEN DATETIME_SUB(stg.charttime, INTERVAL '4' HOUR) AND stg.charttime
),

SF AS (
SELECT
    stg2.subject_id
    , stg2.charttime, spo2
    , fio2
    , CASE
        WHEN spo2 IS NULL THEN NULL
        WHEN spo2 > 97 THEN NULL
        WHEN fio2 IS NOT NULL
            -- multiply by 100 because fio2 is in a % but should be a fraction
            THEN 100 * spo2 / fio2
        ELSE NULL
    END AS spo2fio2ratio
FROM stg2
WHERE lastrowspo2 = 1 -- only the most recent valid SpO2
)


-- Highest/lowest blood gas values for arterial blood specimens
SELECT
    ie.subject_id
    , ie.stay_id
    , MIN(spo2fio2ratio) AS spo2fio2ratio_min
    , MAX(spo2fio2ratio) AS spo2fio2ratio_max
FROM `oxgenator.mimiciv_icu.icustays` ie
LEFT JOIN SF
       ON ie.subject_id = SF.subject_id
        AND SF.charttime >= DATETIME_SUB(ie.intime, INTERVAL '6' HOUR)
        AND SF.charttime <= DATETIME_ADD(ie.intime, INTERVAL '1' DAY)
GROUP BY ie.subject_id, ie.stay_id
