DROP TABLE `clinvar_ingest.clinvar_statement_category`;
CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_statement_categories` (
    code STRING,
    label STRING
);
INSERT INTO `clinvar_ingest.clinvar_statement_categories` (
    code,
    label
)
VALUES
    ('G',    'Germline'),
    ('S',    'Somatic')
;

DROP TABLE `clinvar_ingest.clinvar_statement_type`;
CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_statement_types` (
    code STRING,
    category_code STRING,
    label STRING
);
INSERT INTO `clinvar_ingest.clinvar_statement_types` (
    code,
    category_code,
    label
)
VALUES
    ('GermlineClassification',     'G', 'Germline'),
    ('SomaticClinicalImpact',      'S', 'Clinical Impact'),
    ('OncogenicityClassification', 'S', 'Oncogenicity')
;
-- issue!! the statement type should be linked to the proposition_type table since
--      a proposition type can belong to one and only one statement type.

CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_clinsig_types` (
    statement_type STRING,
    code STRING,
    label STRING,
    significance INT64,
    original_proposition_type STRING,
    original_code_order INT64,
    original_description_order INT64,
    gks_proposition_type STRING,
    gks_code_order INT64,
    gks_description_order INT64,
    direction STRING,
    strength_code STRING,
    strength_label STRING,
    classification_code STRING,
    penetrance_level STRING,
    code_system STRING
);
INSERT INTO `clinvar_ingest.clinvar_clinsig_types` (
    statement_type,
    code,
    label,
    significance,
    original_proposition_type,
    original_code_order,
    original_description_order,
    gks_proposition_type,
    gks_code_order,
    gks_description_order,
    direction,
    strength_code,
    strength_label,
    classification_code,
    penetrance_level,
    code_system
)
VALUES
    -- Pathogenic statements
    ('GermlineClassification',    'b',         'Benign',                            0, 'path',    30,  30, 'path',  30,  30,  'disputes',  'definitive', 'Definitive', 'benign',                            null,          'ACMG Guidelines, 2015'),
    ('GermlineClassification',    'lb',        'Likely benign',                     0, 'path',    31,  31, 'path',  31,  31,  'disputes',  'likely',     'Likely',     'likely benign',                     null,          'ACMG Guidelines, 2015'),
    ('GermlineClassification',    'b/lb',      'Benign/Likely benign',              0, 'path',    32,  32, 'path',  32,  32,  'disputes',  null,         null,         'benign/likely benign',              null,          'ClinVar'),
    ('GermlineClassification',    'vus',       'Uncertain significance',            1, 'path',    20,  20, 'path',  20,  20,  'neutral',   null,         null,         'uncertain significance',            null,          'ACMG Guidelines, 2015'),
    ('GermlineClassification',    'vus-h',     'VUS-high',                          1, 'path',    21,  21, 'path',  21,  21,  'neutral',   null,         null,         'vus-high',                          null,          'SVC v4'),
    ('GermlineClassification',    'vus-m',     'VUS-mid',                           1, 'path',    22,  22, 'path',  22,  22,  'neutral',   null,         null,         'vus-mid',                           null,          'SVC v4'),
    ('GermlineClassification',    'vus-l',     'VUS-low',                           1, 'path',    23,  23, 'path',  23,  23,  'neutral',   null,         null,         'vus-low',                           null,          'SVC v4'),
    ('GermlineClassification',    'ura',       'Uncertain risk allele',             1, 'path',    25,  25, 'path',  25,  25,  'neutral',   null,         null,         'uncertain risk allele',             'risk allele', 'ClinGen Low Penetrance and Risk Allele Recommendations, 2024'),
    ('GermlineClassification',    'p',         'Pathogenic',                        2, 'path',    10,  10, 'path',  10,  10,  'supports',  'definitive', 'Definitive', 'pathogenic',                        null,          'ACMG Guidelines, 2015'),
    ('GermlineClassification',    'lp',        'Likely pathogenic',                 2, 'path',    11,  11, 'path',  11,  11,  'supports',  'likely',     'Likely',     'likely pathogenic',                 null,          'ACMG Guidelines, 2015'),
    ('GermlineClassification',    'p/lp',      'Pathogenic/Likely pathogenic',      2, 'path',    12,  12, 'path',  12,  12,  'supports',  null,         null,         'pathogenic/Likely pathogenic',      null,          'ClinVar'),
    ('GermlineClassification',    'p-lp',      'Pathogenic, low penetrance',        2, 'path',    13,  13, 'path',  13,  13,  'supports',  'definitive', 'Definitive', 'pathogenic, low penetrance',        'low',         'ClinGen Low Penetrance and Risk Allele Recommendations, 2024'),
    ('GermlineClassification',    'lp-lp',     'Likely pathogenic, low penetrance', 2, 'path',    14,  14, 'path',  14,  14,  'supports',  'likely',     'Likely',     'likely pathogenic, low penetrance', 'low',         'ClinGen Low Penetrance and Risk Allele Recommendations, 2024'),
    ('GermlineClassification',    'era',       'Established risk allele',           2, 'path',    15,  15, 'path',  15,  15,  'supports',  'definitive', 'Definitive', 'established risk allele',           'risk allele', 'ClinGen Low Penetrance and Risk Allele Recommendations, 2024'),
    ('GermlineClassification',    'lra',       'Likely risk allele',                2, 'path',    16,  16, 'path',  16,  16,  'supports',  'likely',     'Likely',     'likely risk allele',                'risk allele', 'ClinGen Low Penetrance and Risk Allele Recommendations, 2024'),
    -- Oncogenic
    ('OncogenicityClassification',  'b',       'Benign',                            0, 'onco',    30,  30, 'onco',  30,  30,  'disputes',  'definitive', 'Definitive', 'benign',                            null,          'ClinGen/CGC/VICC Guidelines for Oncogenicity, 2022'),
    ('OncogenicityClassification',  'lb',      'Likely benign',                     0, 'onco',    31,  31, 'onco',  31,  31,  'disputes',  'likely',     'Likely',     'likely benign',                     null,          'ClinGen/CGC/VICC Guidelines for Oncogenicity, 2022'),
    ('OncogenicityClassification',  'b/lb',    'Benign/Likely benign',              0, 'onco',    32,  32, 'onco',  32,  32,  'disputes',  null,         null,         'benign/likely benign',              null,          'ClinVar'),
    ('OncogenicityClassification',  'vus',     'Uncertain significance',            1, 'onco',    20,  20, 'onco',  20,  20,  'neutral',   null,         null,         'uncertain significance',            null,          'ClinGen/CGC/VICC Guidelines for Oncogenicity, 2022'),
    ('OncogenicityClassification',  'o',       'Oncogenic',                         2, 'onco',    10,  10, 'onco',   10, 10,  'supports',  'definitive', 'Definitive', 'oncogenic',                         null,          'ClinGen/CGC/VICC Guidelines for Oncogenicity, 2022'),
    ('OncogenicityClassification',  'lo',      'Likely oncogenic',                  2, 'onco',    11,  11, 'onco',   11, 11,  'supports',  'likely',     'Likely',     'likely oncogenic',                  null,          'ClinGen/CGC/VICC Guidelines for Oncogenicity, 2022'),
    -- ClinVar Other propositions
    ('GermlineClassification',      'aff',     'Affects',                           2, 'aff',     100, 100, 'oth',  100, 100, 'supports',   null,        null,         'affects',                           null,          'ClinVar'),
    ('GermlineClassification',      'assoc',   'association',                       2, 'assoc',   110, 110, 'oth',  110, 110, 'supports',   null,        null,         'association',                       null,          'ClinVar'),
    ('GermlineClassification',      'assocnf', 'association not found',             0, 'assoc',   111, 111, 'oth',  111, 111, 'disputes',   null,        null,         'association not found',             null,          'ClinVar'),
    ('GermlineClassification',      'cdfs',    'conflicting data from submitters',  1, 'cdfs',    115, 115, 'cdfs', 115, 115, 'neutral',    null,        null,         'conflicting data from submitters',  null,          'ClinVar'),
    ('GermlineClassification',      'cs',      'confers sensitivity',               2, 'cs',      120, 120, 'oth',  120, 120, 'supports',   null,        null,         'confers sensitivity',               null,          'ClinVar'),
    ('GermlineClassification',      'dr',      'drug response',                     2, 'dr',      130, 130, 'dr',   130, 130, 'supports',   null,        null,         'drug response',                     null,          'ClinVar'),
    ('GermlineClassification',      'np',      'not provided',                      0, 'np',      140, 140, 'oth',  140, 140, 'supports',   null,        null,         'not provided',                      null,          'ClinVar'),
    ('GermlineClassification',      'oth',     'other',                             0, 'oth',     150, 150, 'oth',  150, 150, 'supports',   null,        null,         'other',                             null,          'ClinVar'),
    ('GermlineClassification',      'protect', 'protective',                        0, 'protect', 160, 160, 'oth',  160, 160, 'supports',   null,        null,         'protective',                        null,          'ClinVar'),
    ('GermlineClassification',      'rf',      'risk factor',                       2, 'rf',      170, 170, 'oth',  170, 170, 'supports',   null,        null,         'risk factor',                       null,          'ClinVar'),
    -- SomaticImpact
    ('SomaticClinicalImpact',       't1',      'Tier I (Strong)',                   2, 'sci', 10, 10, 'sci', 10, 10,  'supports',  'strong',     'Strong',     'tier 1',                            null,          'AMP/ASCO/CAP (AAC) Guidelines, 2017'),
    ('SomaticClinicalImpact',       't2',      'Tier II (Potential)',               2, 'sci', 11, 11, 'sci', 11, 11,  'supports',  'potential',  'Potential',  'tier 2',                            null,          'AMP/ASCO/CAP (AAC) Guidelines, 2017'),
    ('SomaticClinicalImpact',       't3',      'Tier III Unknown',                  1, 'sci', 20, 20, 'sci', 20, 20,  'neutral',   null,         null,         'tier 3',                            null,          'AMP/ASCO/CAP (AAC) Guidelines, 2017'),
    ('SomaticClinicalImpact',       't4',      'Tier IV (Benign)/Likely benign',    0, 'sci', 32, 32, 'sci', 32, 32,  'disputes',  null,         null,         'tier 4',                            null,          'AMP/ASCO/CAP (AAC) Guidelines, 2017');

-- drop the non-GERMLINE rows from the clinsig_types table (on stage only)
BEGIN
    DECLARE project_id STRING;

    SET project_id = (SELECT
        catalog_name as paroject_id
    FROM `INFORMATION_SCHEMA.SCHEMATA`
    WHERE schema_name = 'clinvar_ingest');

    IF (project_id = 'clingen-stage') THEN
        CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_clinsig_types`
        AS
        SELECT
            code,
            label,
            significance,
            original_proposition_type,
            original_code_order,
            original_description_order,
            gks_proposition_type,
            gks_code_order,
            gks_description_order,
            direction,
            strength_code,
            strength_label,
            classification_code,
            penetrance_level
        FROM `clinvar_ingest.clinvar_clinsig_types`
        WHERE statement_type = 'GermlineClassification';

    END IF;

END;

CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_proposition_types` (
    code STRING,
    label STRING,
    display_order INT64,
    conflict_detectable BOOL,
    gks_type STRING,
    gks_predicate STRING
);

INSERT INTO `clinvar_ingest.clinvar_proposition_types` (
    code,
    label,
    display_order,
    conflict_detectable,
    gks_type,
    gks_predicate
)
VALUES
    ('path',    'Pathogenicity',                    10, TRUE,  'VariantPathogenicityProposition',                    'isCausalFor'),
    ('sci',     'Somatic Clinical Impact',          11, FALSE, 'VariantClinicalSignificanceProposition',             'isClinicallySignificantFor'),
    ('onco',    'Oncogenicity',                     12, TRUE,  'VariantOncogenicityProposition',                     'isOncogenicFor'),
-- other germline proposition types
    ('aff',     'Affects',                          20, FALSE, 'ClinvarAffectsProposition',                          'hasAffectFor'),
    ('assoc',   'Association',                      30, FALSE, 'ClinvarAssociationProposition',                      'isAssociatedWith'),
    ('cdfs',    'Conflicting Data From Submitters', 35, FALSE, 'ClinvarConflictingDataFromSubmitterProposition',     'isConflictingDataFromSubmittersFor'),
    ('cs',      'Confers Sensitivity',              40, FALSE, 'ClinvarConfersSensitivityProposition',               'confersSensitivityFor'),
    ('dr',      'Drug Response',                    50, FALSE, 'ClinvarDrugResponseProposition',                     'hasDrugResponseFor'),
    ('np',      'Not Provided',                     60, FALSE, 'ClinvarNotProvidedProposition',                      'hasNoProvidedClassificationFor'),
    ('oth',     'Other',                            70, FALSE, 'ClinvarOtherProposition',                            'isClinvarOtherAssociationFor'),
    ('protect', 'Protective',                       80, FALSE, 'ClinvarProtectiveProposition',                       'isProtectiveFor'),
    ('rf',      'Risk Factor',                      90, FALSE, 'ClinvarRiskFactorProposition',                       'isRiskFactorFor');

CREATE OR REPLACE TABLE `clinvar_ingest.scv_clinsig_map` (
    scv_term STRING,
    cv_clinsig_type STRING
);

INSERT INTO `clinvar_ingest.scv_clinsig_map` (
    scv_term,
    cv_clinsig_type
)
VALUES
    ('affects', 'aff'),
    ('associated with leiomyomas', 'np'),
    ('association', 'assoc'),
    ('association not found', 'assocnf'),
    ('benign', 'b'),
    ('benign/likely benign', 'b/lb'),
    ('cancer', 'oth'),
    ('confers sensitivity', 'cs'),
    ('conflicting data from submitters', 'cdfs'),
    ('drug response', 'dr'),
    ('drug-response', 'dr'),
    ('established risk allele', 'era'),
    ('likely benign', 'lb'),
    ('likely oncogenic', 'lo'),
    ('likely pathogenic', 'lp'),
    ('likely pathogenic - adrenal bilateral pheochromocy', 'lp'),
    ('likely pathogenic - adrenal pheochromocytoma', 'lp'),
    ('likely pathogenic, low penetrance', 'lp-lp'),
    ('likely risk allele', 'lra'),
    ('moderate', 'p'),
    ('mut', 'p'),
    ('mutation', 'p'),
    ('no known pathogenicity', 'b'),
    ('non-pathogenic', 'b'),
    ('not provided', 'np'),
    ('oncogenic', 'o'),
    ('other', 'oth'),
    ('pathogenic', 'p'),
    ('pathogenic, low penetrance', 'p-lp'),
    ('pathogenic variant for bardet-biedl syndrome', 'p'),
    ('pathogenic/likely pathogenic', 'p/lp'),
    ('pathologic', 'p'),
    ('poly', 'b'),
    ('probable-non-pathogenic', 'lb'),
    ('probable-pathogenic', 'lp'),
    ('probably not pathogenic', 'lb'),
    ('probably pathogenic', 'lp'),
    ('protective', 'protect'),
    ('risk factor', 'rf'),
    ('suspected benign', 'lb'),
    ('suspected pathogenic', 'lp'),
    ('tier i - strong', 't1'),
    ('tier ii - potential', 't2'),
    ('tier iii - unknown', 't3'),
    ('tier iv - benign/likely benign', 't4'),
    ('uncertain', 'vus'),
    ('uncertain risk allele', 'ura'),
    ('uncertain significance', 'vus'),
    ('unknown', 'vus'),
    ('unknown significance', 'vus'),
    ('untested', 'np'),
    ('variant of unknown significance', 'vus'),
    ('vsb', 'lb'),
    ('vlb', 'lb'),
    ('vous', 'vus'),
    ('vus', 'vus'),
    ('vus-high', 'vus-h'),
    ('vus-mid', 'vus-m'),
    ('vus-low', 'vus-l'),
    ('vlm', 'lp'),
    ('uncertain significance: likely benign', 'vus'),
    ('uncertain significance: likely pathogenic','vus'),
    ('na','oth');


-- Maps the stable SCV-level integer ranks to their normalized group names and GKS codes.
-- NOTE: This mapping is strictly for single-submitter (SCV) records.
-- Aggregated ranks (e.g., Rank 2) do not have a 1:1 submission level code here.
CREATE OR REPLACE TABLE `clinvar_ingest.submission_level` (
  rank INT64,                    -- The stable SCV integer rank (4, 3, 1, 0, -1, -3)
  label STRING,      -- The consolidated, readable group name
  code STRING   -- The short code (PG, EP, CP, NOCP, NOCL, FLAG)
);

INSERT INTO `clinvar_ingest.submission_level` (rank, label, code) VALUES
(4, 'practice guidelines', 'PG'),
(3, 'expert panel', 'EP'),
(1, 'criteria provided', 'CP'),
(0, 'no assertion criteria provided', 'NOCP'),
(-1, 'no classification', 'NOCL'),
(-3, 'flagged', 'FLAG');

-- Table 1: Logic Mapping (The "When")
CREATE OR REPLACE TABLE `clinvar_ingest.status_rules` (
  review_status STRING,      -- Primary Key (e.g., 'criteria provided, single submitter')
  is_scv BOOLEAN,            -- Context (Individual vs Aggregated)
  rule_type STRING,          -- Logical State (SINGLE, CONFLICT, MULTIPLE_AGREE, etc.)
  conflict_detectable BOOLEAN
);


INSERT INTO `clinvar_ingest.status_rules` (review_status, is_scv, rule_type, conflict_detectable) VALUES
-- Authority Ranks: Rule Agnostic (Logic doesn't change the star label)
('practice guideline', FALSE, NULL, NULL),
('practice guideline', TRUE,  NULL, NULL),
('reviewed by expert panel', FALSE, NULL, NULL),
('reviewed by expert panel', TRUE,  NULL, NULL),

-- Aggregated Ranks (2 Stars): Logic Sensitive
('criteria provided, multiple submitters, no conflicts', FALSE, 'MULTIPLE_AGREE', TRUE),
('criteria provided, multiple submitters', FALSE, 'MULTIPLE_AGREE', FALSE),

-- Single/Conflict Ranks (1 Star): Logic Sensitive
('criteria provided, single submitter', FALSE, 'SINGLE', NULL),
('criteria provided, single submitter', TRUE,  'SINGLE', NULL),
('criteria provided, conflicting classifications', FALSE, 'CONFLICT', TRUE),
('criteria provided, conflicting interpretations', FALSE, 'CONFLICT', TRUE),

-- No Data / Flagged (0 and Negative Ranks): Rule Agnostic
('no assertion criteria provided', FALSE, NULL, NULL),
('no assertion criteria provided', TRUE,  NULL, NULL),
('flagged submission', TRUE, NULL, NULL),
('no classification provided', FALSE, NULL, NULL),
('no classification provided', TRUE,  NULL, NULL),
('no assertion provided', FALSE, NULL, NULL),
('no assertion provided', TRUE,  NULL, NULL),
('no classification for the single variant', FALSE, NULL, NULL),
('no interpretation for the single variant', FALSE, NULL, NULL),
('no classifications from unflagged records', FALSE, NULL, NULL);


-- Table 2: Temporal Metadata (The "What")
CREATE OR REPLACE TABLE `clinvar_ingest.status_definitions` (
  review_status STRING,      -- Matches rules table
  rank INT64,                -- The Star-Rating
  start_release_date DATE,
  end_release_date DATE
);

INSERT INTO `clinvar_ingest.status_definitions` (review_status, rank, start_release_date, end_release_date) VALUES
-- Current Terminology
('practice guideline', 4, '1900-01-01', '9999-12-31'),
('reviewed by expert panel', 3, '1900-01-01', '9999-12-31'),
('criteria provided, multiple submitters, no conflicts', 2, '1900-01-01', '9999-12-31'),
('criteria provided, multiple submitters', 2, '2024-01-26', '9999-12-31'),
('criteria provided, conflicting classifications', 1, '2024-01-26', '9999-12-31'),
('criteria provided, single submitter', 1, '1900-01-01', '9999-12-31'),
('no assertion criteria provided', 0, '1900-01-01', '9999-12-31'),
('no classification provided', -1, '2024-01-26', '9999-12-31'),

-- Legacy Terminology (Kept for historical data alignment)
('criteria provided, conflicting interpretations', 1, '1900-01-01', '2024-01-07'),
('no assertion provided', -1, '1900-01-01', '2024-01-07'),
('no classification for the single variant', -2, '2024-01-26', '9999-12-31'),
('no interpretation for the single variant', -2, '1900-01-01', '2024-01-07'),
('no classifications from unflagged records', -3, '2023-11-21', '9999-12-31'),
('flagged submission', -3, '2023-11-21', '9999-12-31');

-- CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_status` (
--     rank INT64,
--     label STRING,
--     scv BOOL,
--     conflict_detectable BOOL,
--     conflicting BOOL,
--     multiple BOOL,
--     start_release_date DATE,
--     end_release_date DATE
-- );

-- INSERT INTO `clinvar_ingest.clinvar_status` (
--     rank,
--     label,
--     scv,
--     start_release_date,
--     end_release_date,
--     conflict_detectable,
--     conflicting,
--     multiple
-- )
-- VALUES
--     -- scv review statuses - MUST have unique rank values
--     -- or downstream reporting will be wrong - THESE are NOT lossy
--     (-3, 'flagged submission', TRUE, DATE'2023-11-21', DATE'9999-12-31', NULL, NULL, NULL),
--     (-1, 'no classification provided', TRUE, DATE'2024-01-26', DATE'9999-12-31', NULL, NULL, NULL),
--     (-1, 'no assertion provided', TRUE, DATE'1900-01-01', DATE'2024-01-07', NULL, NULL, NULL),
--     (0,  'no assertion criteria provided', TRUE, DATE'1900-01-01', DATE'9999-12-31', NULL, NULL, NULL),
--     (1,  'criteria provided, single submitter', TRUE, DATE'1900-01-01', DATE'9999-12-31', NULL, NULL, NULL),
--     (3,  'reviewed by expert panel', TRUE, DATE'1900-01-01', DATE'9999-12-31', NULL, NULL, NULL),
--     (4,  'practice guideline', TRUE, DATE'1900-01-01', DATE'9999-12-31', NULL, NULL, NULL),
--     -- vcv/rcv review statuses, THESE are lossy conversions from review status to rank and back again.
--     (-3, 'no classifications from unflagged records', FALSE, DATE'2023-11-21', DATE'9999-12-31', NULL, NULL, NULL),
--     (-2, 'no interpretation for the single variant', FALSE, DATE'1900-01-01', DATE'2024-01-07', NULL, NULL, NULL),
--     (-2, 'no classification for the single variant', FALSE, DATE'2024-01-26', DATE'9999-12-31', NULL, NULL, NULL),
--     (-1, 'no classification provided', FALSE, DATE'2024-01-26', DATE'9999-12-31', NULL, NULL, NULL),
--     (-1, 'no assertion provided', FALSE, DATE'1900-01-01', DATE'2024-01-07', NULL, NULL, NULL),
--     (0,  'no assertion criteria provided', FALSE, DATE'1900-01-01', DATE'9999-12-31', NULL, NULL, NULL),

--     (1,  'criteria provided, single submitter', FALSE, DATE'1900-01-01', DATE'9999-12-31', NULL, FALSE, FALSE),
--     (1,  'criteria provided, conflicting interpretations', FALSE, DATE'1900-01-01', DATE'2024-01-07', TRUE, TRUE, TRUE),
--     (1,  'criteria provided, conflicting classifications', FALSE, DATE'2024-01-26', DATE'9999-12-31', TRUE, TRUE, TRUE),

--     -- used for somatic impact aggregate submissions because they don't do any conflict resolution
--     -- This causes a fk integrity issue when looking up by rank on scv=FALSE statuses - needs to be fixed
--     (2,  'criteria provided, multiple submitters', FALSE, DATE'2024-01-26', DATE'9999-12-31', FALSE, FALSE, TRUE),
--     (2,  'criteria provided, multiple submitters, no conflicts', FALSE, DATE'1900-01-01', DATE'9999-12-31', TRUE, FALSE, TRUE),

--     (3,  'reviewed by expert panel', FALSE, DATE'1900-01-01', DATE'9999-12-31', NULL, NULL, NULL),
--     (4,  'practice guideline', FALSE, DATE'1900-01-01', DATE'9999-12-31', NULL, NULL, NULL)
--  ;





--  the items below may predate Jan.01.2023
-- (2,  'classified by multiple submitters', FALSE),
-- (1,  'classified by single submitter', FALSE),
-- (-1, 'not classified by submitter', FALSE),
-- (4,  'reviewed by professional society', FALSE) ;
