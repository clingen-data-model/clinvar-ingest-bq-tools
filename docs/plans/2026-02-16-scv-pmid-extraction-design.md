# SCV PMID Extraction Enhancement

## Summary

Add two new columns to `scv_summary` table to capture unique, sorted PMIDs for each SCV:
- `interpretation_pmids` - Citations supporting the classification decision
- `observation_pmids` - Citations from clinical observations

These fields enable downstream systems to detect evidence changes between ClinVar releases.

## Data Sources

### Interpretation PMIDs
- **Source**: `clinical_assertion.content` → `$.Interpretation` → Citations
- **Parser**: `clinvar_ingest.parseCitations()`
- **Filter**: `cit_id.source = 'PubMed'`

### Observation PMIDs
- **Source**: `clinical_assertion_observation.content` → `$.ObservedData` → Citations
- **Parser**: `clinvar_ingest.parseObservedData()` → `citation` array
- **Filter**: `cit_id.source = 'PubMed'`

### Excluded
- AttributeSet citations (e.g., assertion method citations) are intentionally excluded

## Implementation

### New CTEs in `03-scv-summary-proc.sql`

```sql
-- Interpretation PMIDs (from classification citations)
scv_interpretation_pmids AS (
  SELECT
    ca.id,
    STRING_AGG(DISTINCT cit_id.id, ',' ORDER BY cit_id.id) as interpretation_pmids
  FROM `%s.clinical_assertion` ca,
    UNNEST(`clinvar_ingest.parseCitations`(
      JSON_EXTRACT(ca.content, r'$.Interpretation')
    )) as cit,
    UNNEST(cit.id) as cit_id
  WHERE
    cit_id.source = 'PubMed'
    AND ca.statement_type IS NOT NULL
  GROUP BY ca.id
),

-- Observation PMIDs (from observed data citations)
scv_observation_pmids AS (
  SELECT
    REGEXP_EXTRACT(cao.id, r'^SCV[0-9]+') as id,
    STRING_AGG(DISTINCT cit_id.id, ',' ORDER BY cit_id.id) as observation_pmids
  FROM `%s.clinical_assertion_observation` cao,
    UNNEST(`clinvar_ingest.parseObservedData`(cao.content)) as od,
    UNNEST(od.citation) as cit,
    UNNEST(cit.id) as cit_id
  WHERE
    cit_id.source = 'PubMed'
  GROUP BY 1
)
```

### SELECT Statement Additions

```sql
SELECT
  -- ... existing columns ...
  am.value as assertion_method,
  am.url as assertion_method_url,
  sip.interpretation_pmids,
  sop.observation_pmids
FROM
  `%s.clinical_assertion` ca
-- ... existing joins ...
LEFT JOIN scv_interpretation_pmids sip
ON
  sip.id = ca.id
LEFT JOIN scv_observation_pmids sop
ON
  sop.id = ca.id
WHERE
  ca.statement_type IS NOT NULL
```

## Output Format

- **Type**: STRING (nullable)
- **Format**: Comma-separated, sorted, unique PMIDs (e.g., `"12345678,23456789,34567890"`)
- **NULL**: When no PMIDs exist for that category

## Change Detection Use Case

Downstream systems compare PMID strings between releases:
- If `interpretation_pmids` changes → classification evidence modified
- If `observation_pmids` changes → observation evidence modified
- Sorted order ensures consistent comparison (no false positives from reordering)

## Files to Modify

- `scripts/dataset-preparation/03-scv-summary-proc.sql` - Add CTEs and columns
- `scripts/dataset-preparation/03-scv-summary-proc-draft.sql` - Can be removed after implementation
