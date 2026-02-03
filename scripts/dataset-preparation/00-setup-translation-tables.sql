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
    code_system STRING,
    final_proposition_type STRING,
    final_predicate STRING
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
    code_system,
    final_proposition_type,
    final_predicate
)
VALUES
    -- Pathogenic statements
    ('GermlineClassification',    'b',         'Benign',                            0, 'path',    30,  30, 'path',  30,  30,  'disputes',  'definitive', 'Definitive', 'benign',                            null,          'ACMG Guidelines, 2015',                                        'VariantPathogenicityProposition', 'isCausalFor'),
    ('GermlineClassification',    'lb',        'Likely benign',                     0, 'path',    31,  31, 'path',  31,  31,  'disputes',  'likely',     'Likely',     'likely benign',                     null,          'ACMG Guidelines, 2015',                                        'VariantPathogenicityProposition', 'isCausalFor'),
    ('GermlineClassification',    'b/lb',      'Benign/Likely benign',              0, 'path',    32,  32, 'path',  32,  32,  'disputes',  null,         null,         'benign/likely benign',              null,          'ClinVar',                                                      'VariantPathogenicityProposition', 'isCausalFor'),
    ('GermlineClassification',    'vus',       'Uncertain significance',            1, 'path',    20,  20, 'path',  20,  20,  'neutral',   null,         null,         'uncertain significance',            null,          'ACMG Guidelines, 2015',                                        'VariantPathogenicityProposition', 'isCausalFor'),
    ('GermlineClassification',    'ura',       'Uncertain risk allele',             1, 'path',    21,  21, 'path',  21,  21,  'neutral',   null,         null,         'uncertain risk allele',             'risk allele', 'ClinGen Low Penetrance and Risk Allele Recommendations, 2024', 'VariantPathogenicityProposition', 'isCausalFor'),
    ('GermlineClassification',    'cdfs',      'conflicting data from submitters',  1, 'path',    40,  40, 'path',  40,  40,  'neutral',   null,         null,         'conflicting data from submitters',  null,          'ClinVar',                                                      'VariantPathogenicityProposition', 'isCausalFor'),
    ('GermlineClassification',    'p',         'Pathogenic',                        2, 'path',    10,  10, 'path',  10,  10,  'supports',  'definitive', 'Definitive', 'pathogenic',                        null,          'ACMG Guidelines, 2015',                                        'VariantPathogenicityProposition', 'isCausalFor'),
    ('GermlineClassification',    'lp',        'Likely pathogenic',                 2, 'path',    11,  11, 'path',  11,  11,  'supports',  'likely',     'Likely',     'likely pathogenic',                 null,          'ACMG Guidelines, 2015',                                        'VariantPathogenicityProposition', 'isCausalFor'),
    ('GermlineClassification',    'p/lp',      'Pathogenic/Likely pathogenic',      2, 'path',    12,  12, 'path',  12,  12,  'supports',  null,         null,         'pathogenic/Likely pathogenic',      null,          'ClinVar',                                                      'VariantPathogenicityProposition', 'isCausalFor'),
    ('GermlineClassification',    'p-lp',      'Pathogenic, low penetrance',        2, 'path',    13,  13, 'path',  13,  13,  'supports',  'definitive', 'Definitive', 'pathogenic, low penetrance',        'low',         'ClinGen Low Penetrance and Risk Allele Recommendations, 2024', 'VariantPathogenicityProposition', 'isCausalFor'),
    ('GermlineClassification',    'lp-lp',     'Likely pathogenic, low penetrance', 2, 'path',    14,  14, 'path',  14,  14,  'supports',  'likely',     'Likely',     'likely pathogenic, low penetrance', 'low',         'ClinGen Low Penetrance and Risk Allele Recommendations, 2024', 'VariantPathogenicityProposition', 'isCausalFor'),
    ('GermlineClassification',    'era',       'Established risk allele',           2, 'path',    15,  15, 'path',  15,  15,  'supports',  'definitive', 'Definitive', 'established risk allele',           'risk allele', 'ClinGen Low Penetrance and Risk Allele Recommendations, 2024', 'VariantPathogenicityProposition', 'isCausalFor'),
    ('GermlineClassification',    'lra',       'Likely risk allele',                2, 'path',    16,  16, 'path',  16,  16,  'supports',  'likely',     'Likely',     'likely risk allele',                'risk allele', 'ClinGen Low Penetrance and Risk Allele Recommendations, 2024', 'VariantPathogenicityProposition', 'isCausalFor'),
    -- Oncogenic
    ('OncogenicityClassification',  'b',       'Benign',                            0, 'onco',    30,  30, 'onco',  30,  30,  'disputes',  'definitive', 'Definitive', 'benign',                            null,          'ClinGen/CGC/VICC Guidelines for Oncogenicity, 2022',           'VariantOncogenicityProposition', 'isOncogenicFor'),
    ('OncogenicityClassification',  'lb',      'Likely benign',                     0, 'onco',    31,  31, 'onco',  31,  31,  'disputes',  'likely',     'Likely',     'likely benign',                     null,          'ClinGen/CGC/VICC Guidelines for Oncogenicity, 2022',           'VariantOncogenicityProposition', 'isOncogenicFor'),
    ('OncogenicityClassification',  'b/lb',    'Benign/Likely benign',              0, 'onco',    32,  32, 'onco',  32,  32,  'disputes',  null,         null,         'benign/likely benign',              null,          'ClinVar',                                                      'VariantOncogenicityProposition', 'isOncogenicFor'),
    ('OncogenicityClassification',  'vus',     'Uncertain significance',            1, 'onco',    20,  20, 'onco',  20,  20,  'neutral',   null,         null,         'uncertain significance',            null,          'ClinGen/CGC/VICC Guidelines for Oncogenicity, 2022',           'VariantOncogenicityProposition', 'isOncogenicFor'),
    ('OncogenicityClassification',  'o',       'Oncogenic',                         2, 'onco',    10,  10, 'onco',   10, 10,  'supports',  'definitive', 'Definitive', 'oncogenic',                         null,          'ClinGen/CGC/VICC Guidelines for Oncogenicity, 2022',           'VariantOncogenicityProposition', 'isOncogenicFor'),
    ('OncogenicityClassification',  'lo',      'Likely oncogenic',                  2, 'onco',    11,  11, 'onco',   11, 11,  'supports',  'likely',     'Likely',     'likely oncogenic',                  null,          'ClinGen/CGC/VICC Guidelines for Oncogenicity, 2022',           'VariantOncogenicityProposition', 'isOncogenicFor'),
    -- ClinVarDrugResponse statements
    ('GermlineClassification',      'dr',      'drug response',                     2, 'dr',      130, 130, 'dr',   130, 130, 'supports',   null,        null,         'drug response',                     null,          'ClinVar',                                                      'ClinvarDrugResponseProposition',       'hasDrugResponseFor'),
    -- ClinVarNonAssertion statements
    ('GermlineClassification',      'np',      'not provided',                      0, 'np',      140, 140, 'oth',  140, 140, 'supports',   null,        null,         'not provided',                      null,          'ClinVar',                                                      'ClinvarNotProvidedProposition',        'hasNoProvidedClassificationFor'),
    -- ClinVarOther statements
    ('GermlineClassification',      'rf',      'risk factor',                       2, 'rf',      170, 170, 'oth',  170, 170, 'supports',   null,        null,         'risk factor',                       null,          'ClinVar',                                                      'ClinvarRiskFactorProposition',         'isRiskFactorFor'),
    ('GermlineClassification',      'aff',     'Affects',                           2, 'aff',     100, 100, 'oth',  100, 100, 'supports',   null,        null,         'affects',                           null,          'ClinVar',                                                      'ClinvarAffectsProposition',            'hasAffectFor'),
    ('GermlineClassification',      'assoc',   'association',                       2, 'assoc',   110, 110, 'oth',  110, 110, 'supports',   null,        null,         'association',                       null,          'ClinVar',                                                      'ClinvarAssociationProposition',        'isAssociatedWith'),
    ('GermlineClassification',      'assocnf', 'association not found',             0, 'assoc',   111, 111, 'oth',  111, 111, 'disputes',   null,        null,         'association not found',             null,          'ClinVar',                                                      'ClinvarAssociationProposition',        'isAssociatedWith'),
    ('GermlineClassification',      'cs',      'confers sensitivity',               2, 'cs',      120, 120, 'oth',  120, 120, 'supports',   null,        null,         'confers sensitivity',               null,          'ClinVar',                                                      'ClinvarConfersSensitivityProposition', 'confersSensitivityFor'),
    ('GermlineClassification',      'oth',     'other',                             0, 'oth',     150, 150, 'oth',  150, 150, 'supports',   null,        null,         'other',                             null,          'ClinVar',                                                      'ClinvarOtherProposition',              'isClinvarOtherAssociationFor'),
    ('GermlineClassification',      'protect', 'protective',                        0, 'protect', 160, 160, 'oth',  160, 160, 'supports',   null,        null,         'protective',                        null,          'ClinVar',                                                      'ClinvarProtectiveProposition',         'isProtectiveFor'),
    -- SomaticImpact
    ('SomaticClinicalImpact',       't1',      'Tier I',                            2, 'somatic', 10, 10, 'somatic', 10, 10,  'supports',  'strong',     'Strong',     'tier 1',                            null,          'AMP/ASCO/CAP (AAC) Guidelines, 2017',                          'VariantClinicalSignificanceProposition', 'isClinicallySignificantFor'),
    ('SomaticClinicalImpact',       't2',      'Tier II',                           2, 'somatic', 11, 11, 'somatic', 11, 11,  'supports',  'potential',  'Potential',  'tier 2',                            null,          'AMP/ASCO/CAP (AAC) Guidelines, 2017',                          'VariantClinicalSignificanceProposition', 'isClinicallySignificantFor'),
    ('SomaticClinicalImpact',       't3',      'Tier III',                          1, 'somatic', 20, 20, 'somatic', 20, 20,  'neutral',   null,         null,         'tier 3',                            null,          'AMP/ASCO/CAP (AAC) Guidelines, 2017',                          'VariantClinicalSignificanceProposition', 'isClinicallySignificantFor'),
    ('SomaticClinicalImpact',       't4',      'Tier IV',                           0, 'somatic', 32, 32, 'somatic', 32, 32,  'disputes',  null,         null,         'tier 4',                            null,          'AMP/ASCO/CAP (AAC) Guidelines, 2017',                          'VariantClinicalSignificanceProposition', 'isClinicallySignificantFor');

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
    display_order INT64
);

INSERT INTO `clinvar_ingest.clinvar_proposition_types` (
    code,
    label,
    display_order
)
VALUES

    ('path',    'Pathogenicity', 10),
    ('somatic', 'Somatic Clinical Impact', 11),
    ('onco',    'Oncogenicity', 12),
-- other germline proposition types
    ('aff',     'Affects', 20),
    ('assoc',   'Association', 30),
    ('cs',      'Confers Sensitivity', 40),
    ('dr',      'Drug Response', 50),
    ('np',      'Not Provided', 60),
    ('oth',     'Other', 70),
    ('protect', 'Protective', 80),
    ('rf',      'Risk Factor', 90);


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
    ('vus-mid', 'vus'),
    ('vlm', 'lp'),
    ('uncertain significance: likely benign', 'vus'),
    ('uncertain significance: likely pathogenic','vus'),
    ('na','oth');

CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_status` (
    rank INT64,
    label STRING,
    scv BOOL,
    start_release_date DATE,
    end_release_date DATE
);

INSERT INTO `clinvar_ingest.clinvar_status` (
    rank,
    label,
    scv,
    start_release_date,
    end_release_date
)
VALUES
    -- scv review statuses - MUST have unique rank values
    -- or downstream reporting will be wrong - THESE are NOT lossy
    (-3, 'flagged submission', TRUE, DATE'2023-11-21', DATE'9999-12-31'),
    (-1, 'no classification provided', TRUE, DATE'2024-01-26', DATE'9999-12-31'),
    (-1, 'no assertion provided', TRUE, DATE'1900-01-01', DATE'2024-01-07'),
    (0,  'no assertion criteria provided', TRUE, DATE'1900-01-01', DATE'9999-12-31'),
    (1,  'criteria provided, single submitter', TRUE, DATE'1900-01-01', DATE'9999-12-31'),
    (3,  'reviewed by expert panel', TRUE, DATE'1900-01-01', DATE'9999-12-31'),
    (4,  'practice guideline', TRUE, DATE'1900-01-01', DATE'9999-12-31'),
    -- vcv/rcv review statuses, THESE are lossy conversions from review status to rank and back again.

    (-3, 'no classifications from unflagged records', FALSE, DATE'2023-11-21', DATE'9999-12-31'),

    (-2, 'no interpretation for the single variant', FALSE, DATE'1900-01-01', DATE'2024-01-07'),
    (-2, 'no classification for the single variant', FALSE, DATE'2024-01-26', DATE'9999-12-31'),

    (1,  'criteria provided, conflicting interpretations', FALSE, DATE'1900-01-01', DATE'2024-01-07'),
    (1,  'criteria provided, conflicting classifications', FALSE, DATE'2024-01-26', DATE'9999-12-31'),

    (2,  'criteria provided, multiple submitters, no conflicts', FALSE, DATE'1900-01-01', DATE'9999-12-31')

    -- used for somatic impact aggregate submissions because they don't do any conflict resolution
    (2,  'criteria provided, multiple submitters', FALSE, DATE'2024-01-26', DATE'9999-12-31')
;



--  the items below may predate Jan.01.2023
-- (2,  'classified by multiple submitters', FALSE),
-- (1,  'classified by single submitter', FALSE),
-- (-1, 'not classified by submitter', FALSE),
-- (4,  'reviewed by professional society', FALSE) ;
