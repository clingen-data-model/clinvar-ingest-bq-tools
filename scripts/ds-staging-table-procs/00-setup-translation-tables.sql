-- CREATE OR REPLACE TABLE `clinvar_ingest.cvc_context_types` (code STRING, label STRING, display_order INT64);  

-- INSERT INTO `clinvar_ingest.cvc_context_types` (code, label, display_order) 
-- VALUES 
--     ('gd','Germline Disease', 10),
--     ('sc','Somatic Cancer',   20),
--     ('pg','Pharmacogenomic',  30),
--     ('ot','Other',            40);

CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_clinsig_types` (
    code STRING, label STRING, significance INT64, 
    clinvar_prop_type STRING, clinvar_code_order INT64, 
    clinvar_desc_order INT64, cvc_prop_type STRING, 
    cvc_code_order INT64, cvc_desc_order INT64, 
    direction STRING, strength_code STRING, strength_label STRING, 
    classification_code STRING, penetrance_level STRING
);  
INSERT INTO `clinvar_ingest.clinvar_clinsig_types` (
    code, 
    label, 
    significance, 
    clinvar_prop_type, 
    clinvar_code_order, 
    clinvar_desc_order, 
    cvc_prop_type, 
    cvc_code_order, 
    cvc_desc_order, 
    direction, 
    strength_code, 
    strength_label, 
    classification_code, 
    penetrance_level
) 
VALUES 
    -- Pathogenic statements
    ('b',       'Benign',                            0, '?',    30,  30, '?',  30,  30,  'refutes',   'cg000101', 'definitive',    'cg000001', null),
    ('lb',      'Likely benign',                     0, '?',    31,  31, '?',  31,  31,  'refutes',   'cg000102', 'likely',        'cg000002', null),
    ('b/lb',    'Benign/Likely benign',              0, '?',    32,  32, '?',  32,  32,  'refutes',   'cg000102', 'likely',        'cg000003', null),
    ('vus',     'Uncertain significance',            1, '?',    20,  20, '?',  20,  20,  'none',      'cg000103', 'inconclusive',  'cg000004', null),
    ('ura',     'Uncertain risk allele',             1, '?',    21,  21, '?',  21,  21,  'none',      'cg000103', 'inconclusive',  'cg000005', 'risk allele'),
    ('p',       'Pathogenic',                        2, '?',    10,  10, '?',  10,  10,  'supports',  'cg000101', 'definitive',    'cg000006', null),
    ('lp',      'Likely pathogenic',                 2, '?',    11,  11, '?',  11,  11,  'supports',  'cg000102', 'likely',        'cg000007', null),
    ('p/lp',    'Pathogenic/Likely pathogenic',      2, '?',    12,  12, '?',  12,  12,  'supports',  'cg000102', 'likely',        'cg000008', null),
    ('p-lp',    'Pathogenic, low penetrance',        2, '?',    13,  13, '?',  13,  13,  'supports',  'cg000101', 'definitive',    'cg000009', 'low'),
    ('lp-lp',   'Likely pathogenic, low penetrance', 2, '?',    14,  14, '?',  14,  14,  'supports',  'cg000102', 'likely',        'cg000010', 'low'),
    ('era',     'Established risk allele',           2, '?',    15,  15, '?',  15,  15,  'supports',  'cg000101', 'definitive',    'cg000011', 'risk allele'),
    ('lra',     'Likely risk allele',                2, '?',    16,  16, '?',  16,  16,  'supports',  'cg000102', 'likely',        'cg000012', 'risk allele'),
    ('cdfs',    'conflicting data from submitters',  1, '?',    40,  40, '?',  40,  40,  'none',      'cg000103', 'inconclusive',  'cg000013', null),
    -- ClinVarDrugResponse statements
    ('dr',      'drug response',                     2, 'dr',      130, 130, 'dr',   130, 130, 'supports',  'cg000100', 'not specified', 'cg000014', null),
    -- ClinVarNonAssertion statements
    ('np',      'not provided',                      0, '?',      140, 140, 'oth',  140, 140, 'none',      'cg000100', 'not specified', 'cg000015', null),
    -- ClinVarOther statements
    ('rf',      'risk factor',                       2, 'rf',      170, 170, 'oth',  170, 170, 'none',      'cg000100', 'not specified', 'cg000016', null),
    ('aff',     'Affects',                           2, 'aff',     100, 100, 'oth',  100, 100, 'none',      'cg000100', 'not specified', 'cg000017', null),
    ('assoc',   'association',                       2, 'assoc',   110, 110, 'oth',  110, 110, 'none',      'cg000100', 'not specified', 'cg000018', null),
    ('assocnf', 'association not found',             0, 'assoc',   111, 111, 'oth',  111, 111, 'none',      'cg000100', 'not specified', 'cg000019', null),
    ('cs',      'confers sensitivity',               2, 'cs',      120, 120, 'oth',  120, 120, 'none',      'cg000100', 'not specified', 'cg000020', null),
    ('oth',     'other',                             0, 'oth',     150, 150, 'oth',  150, 150, 'none',      'cg000100', 'not specified', 'cg000021', null),
    ('protect', 'protective',                        0, 'protect', 160, 160, 'oth',  160, 160, 'none',      'cg000100', 'not specified', 'cg000022', null),
    -- SomaticImpact
    ('t1', 'Tier I - Strong',                        2, 'somatic', 10, 10, 'somatic', 10, 10,  'supports',  'cg000100', 'definitive',    'cg000023', null),
    ('t2', 'Tier II - Potential',                    2, 'somatic', 11, 11, 'somatic', 11, 11,  'supports',  'cg000102', 'likely',        'cg000024', null),
    ('t3', 'Tier III - Unknown',                     1, 'somatic', 20, 20, 'somatic', 20, 20,  'none',      'cg000103', 'inconclusive',  'cg000025', null),
    ('t4', 'Tier IV - Benign/Likely benign',         0, 'somatic', 32, 32, 'somatic', 32, 32,  'refutes',   'cg000102', 'likely',        'cg000026', null),
    -- Oncogenic
    ('o',       'Oncogenic',                         2, '?',    10,  10, 'onco',   10, 10,  'supports',  'cg000101', 'definitive',    'cg000027', null),
    ('lo',      'Likely oncogenic',                  2, '?',    11,  11, 'onco',   11, 11,  'supports',  'cg000102', 'likely',        'cg000028', null);


CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_proposition_types` (code STRING, label STRING, display_order INT64);  
INSERT INTO `clinvar_ingest.clinvar_proposition_types` (code, label, display_order) 
VALUES 
    ('path', 'Pathogenicity', 10),
    ('dr',   'DrugResponse', 11),  
    ('oth',  'Other', 12),
    ('somatic', 'SomaticClinicalImpact', 20),
    ('onco', 'Oncogenicity', 30);

    -- ('rf',   'RiskFactor',30),
    -- ('np',   'NotProvided',60),
    -- put affects, associated, confresSensitivity and protect in other category
    -- ('aff',  'Affects',20),
    -- ('assoc','Associated',30),
    -- ('cs',   'ConfersSensitivity',40),
    -- ('protect','Protective',80),


CREATE OR REPLACE TABLE `clinvar_ingest.scv_clinsig_map` (scv_term STRING, cv_clinsig_type STRING);  
INSERT INTO `clinvar_ingest.scv_clinsig_map` (scv_term, cv_clinsig_type) VALUES 
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
    ('vlm', 'lp'),
    ('uncertain significance: likely benign', 'vus'),
    ('uncertain significance: likely pathogenic','vus'),
    ('na','oth');

CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_status` (rank INT64, label STRING, scv BOOL);
INSERT INTO `clinvar_ingest.clinvar_status` (rank, label, scv) 
VALUES
    (-3, 'no classifications from unflagged records', FALSE),
    (-3, 'flagged submission', TRUE),
    (-2, 'no interpretation for the single variant', FALSE),
    (-2, 'no classification for the single variant', FALSE),
    (-1, 'no assertion provided', TRUE),
    (-1, 'no classification provided', TRUE),
    (-1, 'not classified by submitter', FALSE),
    (0,  'no assertion criteria provided', TRUE),
    (1,  'criteria provided, single submitter', TRUE),
    (1,  'classified by single submitter', FALSE),
    (1,  'criteria provided, conflicting interpretations', FALSE),
    (1,  'criteria provided, conflicting classifications', FALSE),
    (2,  'criteria provided, multiple submitters, no conflicts', FALSE),
    (2,  'criteria provided, multiple submitters', FALSE),
    (2,  'classified by multiple submitters', FALSE),
    (3,  'reviewed by expert panel', TRUE),
    (4,  'practice guideline', TRUE),
    (4,  'reviewed by professional society', FALSE) ;

 