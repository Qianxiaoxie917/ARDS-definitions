WITH po AS (SELECT
        -- specimen_id only ever has 1 measurement for each itemid
        -- so, we may simply collapse rows using MAX()
        MAX(subject_id) AS subject_id
        , MAX(hadm_id) AS hadm_id
        , MAX(charttime) AS charttime
        -- specimen_id *may* have different storetimes, so this
        -- is taking the latest
        , le.specimen_id
        , MAX(CASE WHEN itemid = 50815 THEN valuenum ELSE NULL END) AS o2flow
        , MAX(CASE WHEN itemid = 50819 THEN valuenum ELSE NULL END) AS peep
    FROM `oxgenator.mimiciv_hosp.labevents` le
    WHERE le.itemid IN
        -- blood gases
        (
              50815 -- o2 flow
            , 50819 -- peep
        )
    GROUP BY le.specimen_id
    )


-- Highest/lowest blood gas values for arterial blood specimens
SELECT
    ie.subject_id
    , ie.stay_id
    , MIN(peep) AS peep_min, MAX(peep) AS peep_max
    , MIN(o2flow) AS o2flow_min, MAX(o2flow) AS o2flow_max
FROM `oxgenator.mimiciv_icu.icustays` ie
LEFT JOIN po
    ON ie.subject_id = po.subject_id
        AND po.charttime >= DATETIME_SUB(ie.intime, INTERVAL '6' HOUR)
        AND po.charttime <= DATETIME_ADD(ie.intime, INTERVAL '1' DAY)
GROUP BY ie.subject_id, ie.stay_id
