# ClinGen Knowledge Dissemination

!!! warning "Work in Progress"
    This document is a draft. Sections marked with **[Verify]** require review by subject matter experts. Incomplete sections are noted explicitly.

## Overview

ClinGen (Clinical Genome Resource) generates expert-curated knowledge across multiple domains — variant pathogenicity, gene-disease validity, dosage sensitivity, actionability, and somatic clinical significance. Each knowledge type originates from a dedicated curation system and reaches the community through a combination of user interfaces (UIs), downloadable files, and application programming interfaces (APIs).

This document catalogs each knowledge resource, its authoritative source system, and the channels through which it is disseminated.

## Dissemination Channels at a Glance

| Knowledge Type | Source System | UI | API | File Downloads | ClinGen Website |
| -------------- | ------------- | -- | --- | -------------- | --------------- |
| Variant Pathogenicity (VCEP) | VCI / ERepo | ERepo | ERepo API | Not yet available | Search via ERepo |
| Gene-Disease Validity (GCEP) | GCI / GeneGraph | ClinGen website | Internal (GraphQL) | Scheduled releases | Search, download, release files |
| Dosage Sensitivity | ClinGen website | ClinGen website | Not available | Not available | Search, individual reports |
| Actionability | ACI / AKRepo | AKRepo, ClinGen website | AKRepo API | Not available | Search, download |
| Somatic (SCEP) | CIViC | CIViC | CIViC API **[Verify]** | CIViC releases **[Verify]** | Via ClinVar |
| Criteria Specifications | CSpec Editor / CSpec Repo | CSpec Repo | CSpec API | Individual specs | — |
| ClinVar (VP + Somatic summary) | ClinVar / clinvar-gks | ClinVar | ClinVar API | XML releases, clinvar-gks (forthcoming) | — |
| GenCC Gene Validity | GenCC | GenCC website | Not available | Not available | — |

## Expert Curated Knowledge

### Variant Pathogenicity Statements (VCEP)

**Source system:** Variant Curation Interface (VCI) &rarr; Evidence Repository (ERepo)

Expert-curated variant pathogenicity statements are produced by Variant Curation Expert Panels (VCEPs) using the VCI. Approved assertions are published to the Evidence Repository (ERepo), which serves as the system of record.

**Dissemination channels:**

- **UI:** The ERepo provides a searchable public interface for browsing individual assertions. The ClinGen website also provides search access to ERepo data. **[Verify: Does the ClinGen website search ERepo directly or mirror it?]**
- **API:** The ERepo exposes a public API for programmatic access to individual assertions.
- **File downloads:** A complete file-based dataset download of all published VCEP statements is not currently available. This capability may eventually be provided via the ERepo and surfaced through the ClinGen website.

**Data format:** Assertions use a SEPIO-based schema that predated and informed the current GA4GH GKS VA-Spec v1.0 Variant Pathogenicity Standard. Individual statements are versioned. Assertions are published automatically as VCEPs approve them and are available in the ERepo immediately.

---

### Gene-Disease Validity Statements (GCEP)

**Source system:** Gene Curation Interface (GCI) &rarr; GeneGraph DB

Expert-curated gene-disease validity statements are produced by Gene Curation Expert Panels (GCEPs) using the GCI. Approved assertions flow to GeneGraph, where they are versioned and standardized.

**Dissemination channels:**

- **UI:** The ClinGen website provides a searchable interface for browsing gene-disease validity data, with tabular data downloads of viewable results.
- **API:** GeneGraph exposes an internal GraphQL API used to serve data to the ClinGen website. There is currently no public API for GCEP statements.
- **File downloads:** GeneGraph generates full dataset release files on a scheduled basis. These are archived and made available for download through the ClinGen website. **[Verify: Confirm scheduled release cadence and archival policy.]**

**Data format:** Assertions use a SEPIO-based schema. The GA4GH GKS VA-Spec v1.0 Standard is developing a compliant representation for gene-disease validity statements. GeneGraph is a critical component of the publishing workflow — it handles versioning, internal API access, release file generation, and serves as the bridge between the GCI and the ClinGen website.

---

### Dosage Sensitivity Statements

**Source system:** ClinGen website (curation workflow details to be confirmed)

!!! note "Review Needed"
    The curation interface and publishing workflow for Dosage Sensitivity data require clarification. This section needs review — particularly how DCI (Dosage Curation Interface) data flows to the website.

**Dissemination channels:**

- **UI:** The ClinGen website provides a searchable interface for dosage sensitivity data. Individual reports are viewable and downloadable.
- **API:** Not currently available.
- **File downloads:** Full file-based dataset releases in a standardized format are not currently provided. Individual reports may be downloaded from the website. **[Verify: Confirm individual report download capability.]**

**Future considerations:** A GA4GH statement format could align dosage sensitivity records with the same foundational semantics used by VCI, GCI, and other ClinGen knowledge types.

---

### Actionability Statements

**Source system:** Actionability Curation Interface (ACI) &rarr; Actionability Knowledge Repository (AKRepo)

Expert actionability groups curate and publish clinical actionability statements using the ACI. Published statements are stored in the AKRepo.

**Dissemination channels:**

- **UI:** The AKRepo provides a searchable public interface. The ClinGen website also surfaces AKRepo data for browser-based searching and data download.
- **API:** The AKRepo exposes a public API for programmatic access.
- **File downloads:** Full file-based dataset releases in a standardized format are not currently provided. **[Verify: Confirm whether individual reports are downloadable.]**

**Future considerations:** As with dosage sensitivity, a GA4GH statement format could provide standardized representation aligned with other ClinGen knowledge types.

---

### Somatic Expert Statements (SCEP)

**Source system:** CIViC (Clinical Interpretation of Variants in Cancer)

!!! note "Review Needed"
    This section requires review by the somatic curation team (Alex/Kori). Details about CIViC's API and file download capabilities need verification.

Expert somatic working groups curate and publish somatic clinical significance statements through CIViC. Approved curations are additionally submitted in summary form to ClinVar's somatic dataset.

**Dissemination channels:**

- **UI:** CIViC provides a searchable public interface as the system of record for somatic curation data.
- **API:** CIViC provides an API. **[Verify: Confirm public API availability and capabilities.]**
- **File downloads:** CIViC provides downloadable release files. **[Verify: Confirm release file format and cadence.]**
- **ClinVar:** Summary somatic assertions are submitted to ClinVar and available through ClinVar's standard channels.

---

### Criteria Specifications (CSpec)

**Source system:** CSpec Editor &rarr; Criteria Specification Repository (CSpec Repo)

The Criteria Specification Repository hosts all expert specifications approved and published through the CSpec Editor. These specifications define the rules and criteria that VCEPs and other expert panels use during curation.

**Dissemination channels:**

- **UI:** The CSpec Repo provides a searchable public interface for browsing specifications.
- **API:** The CSpec Repo exposes a public API.
- **File downloads:** Individual specifications are downloadable. A full file-based release dataset is not currently generated, as specifications tend to be used independently rather than as a set. **[Discuss with DPWG whether periodic full releases would be valuable.]**

---

## Aggregated and Derived Data

### ClinVar (VP + Somatic Summary Data)

**Source system:** ClinVar (NCBI) with ClinGen collaboration via clinvar-gks

ClinVar is a globally contributed, aggregated public repository of variant classifications. ClinGen submits summaries of all VCEP and SCEP published statements to ClinVar. ClinGen collaborates with ClinVar to improve the quality and utility of its data.

ClinGen maintains an automated pipeline — **clinvar-gks** — that ingests, transforms, and disseminates ClinVar dataset release files. The forthcoming clinvar-gks datasets will provide the community with GA4GH-standardized representations of ClinVar XML data, with the goal of lowering the technical barrier to accurate use and providing access to the full depth of submitted data available in ClinVar.

---

### GenCC Gene Validity Data

**Source system:** Gene Curation Coalition (GenCC)

ClinGen's published summary GCEP gene-disease validity data is submitted to the GenCC dataset, where it is combined with assertions from other coalition submitters.

**Dissemination channels:**

- **UI:** The GenCC website provides a searchable interface with downloadable views of the data.
- **API:** Not currently available.
- **File downloads:** A standardized file-based release of the full dataset is not currently provided.

---

## Other ClinGen Data Sources

!!! note "Incomplete"
    The following data sources require further documentation. Their dissemination models are not yet fully characterized.

### Community Curation Data

The community curation dataset's public sharing model has not been determined. **[Discuss whether and how this dataset is intended to be shared publicly.]**

### ClinGen Allele Registry

The ClinGen Allele Registry (CAR) provides stable, unique identifiers (CAIDs) for human genetic alleles. It serves as a foundational reference for allele identity across ClinGen systems and external consumers.

**Dissemination channels:**

- **UI:** The Allele Registry provides a searchable public interface.
- **API:** A public RESTful API is available for allele lookup and registration.

### Linked Data Hub

The Linked Data Hub is a large-scale data integration layer that depends on ClinGen Allele Registry identifiers (CAIDs). It does not generate curated data itself but aggregates and links data from multiple sources.

**Dissemination channels:**

- **API:** API access only. No UI or file-based downloads are provided.
