# ARDS-definitions: ARDS Definitions Code Repository 

This repository contains the code used for the paper "The New Global Definition of Acute Respiratory Distress Syndrome: Insights from the MIMIC-IV Database".


## Repository Structure and Description

The repository is organized as follows:


### Data Preprocessing

This section provides an overview of SQL scripts designed for processing the MIMIC-IV database. MIMIC-IV encompasses hospital and critical care data for patients admitted to the emergency department or Intensive Care Unit (ICU) from 2008 to 2019. Each script outputs a table named identically to the script. The scripts are contained in the folder [`Data_preprocessing`](Data_preprocessing/).

[`first_day_peep_o2flow.sql`](Data_preprocessing/first_day_peep_o2flow.sql): Merges data on PEEP and oxygen flow rates for the initial day of admission.

[`first_day_SF_ratio.sql`](Data_preprocessing/first_day_SF_ratio.sql): Aggregates first-day data on the SpO2/FiO2 ratio.

[`chest_notes.sql`](Data_preprocessing/chest_notes.sql): Extracts ARDS-related evidence from chest radiology reports.

[`ards_icd.sql`](Data_preprocessing/ards_icd.sql): Isolates ICD codes for patients diagnosed with ARDS or acute heart failure.

[`ecmo.sql`](Data_preprocessing/ecmo.sql): Retrieves data on patients who underwent ECMO.

[`ventilation_ards.sql`](Data_preprocessing/ventilation_ards.sql): Identifies initial ventilation status in ARDS patients.

[`mimiciv_ards.sql`](Data_preprocessing/mimiciv_ards.sql): Compiles a comprehensive table incorporating all previously mentioned datasets.


### Data Analysis

The folder [`Data_analysis`](Data_analysis/) is dedicated to the extraction and analysis of data using R. Some of the following scripts load `RData` files. They are created by [`MIMICIV_ARDS_whole_subset.Rmd`](Data_analysis/MIMICIV_ARDS_whole_subset.Rmd).

[`funs.R`](Data_analysis/funs.R): Script with some functions for data analysis. It is read by some of the following R Markdown files.

[`MIMICIV_ARDS_whole_subset.Rmd`](Data_analysis/MIMICIV_ARDS_whole_subset.Rmd): An R Markdown file used for selecting subsets according to both ARDS definitions.

[`MIMICIV_ARDS_patients_characteristic.Rmd`](Data_analysis/MIMICIV_ARDS_patients_characteristic.Rmd): The R Markdown file details the characteristics of ARDS patients.

[`MIMICIV_ARDS_main_analysis.Rmd`](Data_analysis/MIMICIV_ARDS_main_analysis.Rmd): This R Markdown document conducts the primary comparative analysis across the two ARDS definitions.

[`MIMICIV_ARDS_Ethnicity.Rmd`](Data_analysis/MIMICIV_ARDS_Ethnicity.Rmd): An R Markdown file focusing on the comparative analysis between Caucasian and African-American patient groups.




Please note that specific details of the scripts and their functions can be found within the respective folders. Feel free to contribute or raise an issue if you find anything that could be improved or updated.
