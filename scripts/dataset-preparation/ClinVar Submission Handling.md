# ClinVar Submission Record Validation & Processing

This document is being written to help clarify the key requirements used by ClinVar to allow authorized submitters to add, update and remove records (aka. submissions) to/from the ClinVar public dataset. It focuses only on the method ClinVar applies to defining a record or submission in ClinVar and how that is used to allow or prevent submitters to affect change to the records they own.

Below are an ordered set of topics that define essential concepts and build to a comprehensive picture of how ClinVar's submission record validation & processing works.

## Classification

A classification is an individual submitter's assertion about a variant in the context of a type of statement that ClinVar allows supports (e.g. variant pathogenicity, drug response, oncogenicity). Submitters typically manage multiple classifications in their own external systems to arrive at a classification that they want to share in ClinVar. Over time the submitter may re-evaluate or modify a given classification, which is why it is important to both allow the submitter to reference a pre-existing classification in ClinVar and to provide an optional mechanism for the submitter to store their system's identifier with the record in ClinVar.

alternate label: *assertion, statement, submission, interpretation (previously used terminology)*

## variant

The variant is the subject of all classifications that are submitted to clinvar. The variant is a definitive value in a classification record. It is assumed that the variation would NEVER change over time for given classification. ClinVar rejects submissions if the submitter attempts to udpate an SCV and change the variant.

alternate label: *allele, variation, measure, measure set*

## disease

alternate label: *condition, phenotype, trait, trait set*

## natural key

Natural keys are a type of unique key in a database that is formed from attributes that already exist in the real world or business domain. These attributes are naturally used to identify records and typically have meaning outside of the database context. True natural keys SHOULD never change values over time since they represent the identity of the record, thus changing it would be a different record. However, software and database designers may mistakenly identify natural keys that MUST be unique at a given point in time, but may actually be allowed to change over time and thus is not really a reliable means to identifying a record in a system that needs to track a given record over time.

Folks may consider the variant and disease values for a given submitter's classification to be a *natural key* but it has been proven in ClinVar that the disease term may change slightly over time or be omitted completely if one cannot be pinned down as definitive for the life of the classification. However, changing the variant on a classification would cross the line of changing the fundamental definition of the original classification and thus be considered a different classification. ClinVar does not allow the variant to be changed on classification updates, but it will be flexible on the disease and trust that the submitter does not change the disease/condition so dramatically as to create a different classification.

## primary key

A primary key is formally defined as column or set of columns in a database table that uniquely identifies each record (row) within that table. It's a fundamental concept in relational database design, ensuring data integrity and enabling efficient data retrieval and relationships between tables. The primary key serves as the main way to identify and access specific records in the table.

Typically, primary keys are a single column that are controlled and managed by the system that owns the records. Once a classification is validated and processed into the ClinVar dataset it is assigned an SCV accession which is reasonably considered the primary key for all classifications in clinvar.

Examples of other primary keys in ClinVar are submitter ids, rcv accessions, vcv accessions, and variation ids.

alternate label: *unique key, identifier, id*

## local key

The field, *'local key'*, is used in ClinVar submissions for an optional identifier value that a submitter can provide for a classification being submitted. This value is the fully controlled and managed by the submitter and ClinVar has no dependency or rules for it. This optional feature is provided so submitters can map their own system's classifications with ClinVar's SCV accession ids. Submitters can submit their system's identifier or contrive any unique string within the set of SCV accessions they've submitted to ClinVar to distinguish and map them back to their classification records.

> NOTE: There are many examples of a single SCV getting different local key values on subsequent updates to clinvar, but the primary approach submitter's use is to provide a consistent value.  In ClinGen's Variant Curation Interface (VCI) system, the record id from the VCI is automatically submitted to clinvar as the local key and used when a new release is provided to allow the VCI to get the SCV that was assigned to it. By using the local key consistently external system's can provide various options for how they retain mappings back to ClinVar SCV records.

alternate label: *submitter's identifier, submitter's key, external id*


## submission

A submission is a record or a set of fields prescribed by ClinVar to represent a classification of a variant associated with a disease/condition. ClinVar makes a couple presumptions about classificatoin submissions:
1. submitters will manage their classifications over time and potentially re-evaluate and update them and
2. submitters may modify the disease since disease identity can be more complex requiring tweaks to improve the initially intended disease concept.

Currently, the primary submission represents a submitter's classification (frmrly interpretation) of the association of a variant with a disease or condition. Once a submission is validated and officially added to ClinVar it is referred to as an SCV and it gets an SCV accession identifier and version and ClinVar will not allow the submitter to change the variant on a .<br/>

  > NOTE: It is possible that ClinVar will be expanding the type of records (e.g. functional data) which may change the "identifying" attributes or values. For the purposes of this document we are assuming all submissions or records are classification records that are defined by the variant, disease and submitter.

alternate label: *classification submission, classification record*

### batch submission

A set of submission records that are submitted to ClinVar at one time, usually more than one. Submitters typically submit their variant classification records to ClinVar in a single Excel file which allows them to batch multiple records. This file is then uploaded and *submitted* via the submitter's account on the ClinVar submitter portal. The activity of submitting a single submission or a batch of submission to ClinVar is also called *submission*. And to be clear, ClinVar allows the submitter to name their submission in case they want to track the various events and batches or submission records over time that were submitted. So, the term submission can be taken out of context quite easily. Just note, when ther term "submission name" is used the reference is to the batch or single submission event whereby ClinVar received an official request with one or more records to validate and process.

alternate label: *submission file*

## SCV

SCV stands for Submitted ClinVar Variant. It is the ClinVar assigned primary key for any validated and processed classification submission. It is also referred to as the SCV accession id. There are also VCV and RCV accession ids created and managed by ClinVar which are not relevant for this document. All accession records in ClinVar are versioned. When the processed submission is added to ClinVar they add a authorized unique identifier in the format SCV999999 and it is initialized to version 1. When a processed submission is updated the version is incremented.


## versioning classifications

A version is defined as a point in time snapshot of the state of a classification. As classifications are created, curated, approved, shared, re-evaluated, re-shared, etc.. the owner of that classification must choose when that record is finalized and able to be shared. It is assumed that once a classification is shared it should be able to be identified and distinguished from any subsequent finalized updates to that same classification. ClinVar versions a submitter's classification whenever they re-submit the same classification. The version is a sequential number starting at 1 and incremented with each update. ClinVar provides boundaries around what it will allow the submitter to change from one version to the next. ClinVar expects the submitter to indicate if a submission is 'N' novel or 'U' an update. If it is novel then it must NOT have the same variant and disease/condition combination as any other classification from that same submitter. If it is an update then it MUST have the same variant even though the disease/condition may change presuming it does not create a 2nd classification with the same variant and disease/condition for that submitter.

Ideally, ClinVar would prefer that individual submitters not submit multiple classifications on the same variant for less valuable classifications (e.g. to assert each individual disease that is benign for a given variant) but some submitters have done this. Some variants have disease associations with different diseases and therefore may need to be classified independently (e.g. RYR1 )

# ClinVar vs GenCC: validation, processing and releases

GenCC has a much smaller and more controlled set of submitters. All of GenCC submitters are considered to have the same weight or influence so there is no need to group submitters or submissions by review status (aka. clinvar star levels). In essesnce, GenCC submitters are all "experts".  GenCC submissions are defined by Gene, Disease and Mode of Inheritance (MOI). It seems likely that GenCC submitters may start a Gene Disease Validity (GDV) classification for a given Gene-Disease-MOI but may tweak it over time, even after it is initially shared or released. (need confirmation). Like ClinVar, I believe it would be safe to say that the Gene should  NEVER change on a previously submitted GDV classification. Presumably the disease and moi may be altered in the event that the GenCC curators and consortium members settle on how to group and identify certain diseases. So, similary to ClinVar we may want to allow this. We may want to control the release processing for the entire GenCC dataset if there are users in the community that would benefit from a stable reference to an historical snapshot that is maintained by GenCC. But, there is little other benefit to a snapshot release process since the GenCC processing does not generate it's own accession-like records.

## validation & processing

The individual and cross field validation in ClinVar is a bit extensive, please review the submission form from the clinvar site for details.
GenCC should validate that a Gene and Disease are provided and valid. (NOTE: I don't believe that the disease can be omitted). I'm not clear whether the MOI is required many entries seem to have the HPO term for "Unknown" which may be the default.  The evaluated date, classification code and assertion criteria url all seem to be required and should be validated as well. The text blurb and pmids may also need some validation but it is unclear how extensive it should be.

### novel vs udpate (local key vs accession)

ClinVar submission validation does not require a local key nor does it validate it in any way (AFAIK). ClinVar does require the submitter to specify whether or not the submission is a Novel 'N' or Update 'U'. If it is an update then the submitter must identify the existing SCV accession id that is being targeted. Also, if it is an update the variation id being submitted must match the variation id of the existing SCV version.
I believe this is a reasonable approach for GenCC. Having GenCC author and manage accession ids for each submission (SGV ids) would provide the level of control that would make the management of the system and processing of submission more reliable and straightforward. It would require that submitters annotate their submissions with the N or U and if it is a U they'd have to supply the SGV id they are updating. While this is a new burden on submitters, it should be reasonably easy to provide reports for submitters to download from GenCC that contain the mapping of their local key to the SGV id.
I also think it would be wise to create a version on every SGV so we can retain a publicly referenceable accession.version format for the community to reference.

## releases

The release concept in ClinVar is for the release of a new "snapshot" of ClinVar's data at a point in time. ClinVar adds value to the submitted records by aggregating them into RCVs (variant-disease pairs) and VCVs (variant). These aggregate accessions (RCV and VCV) are derived by ClinVar based on a set of new submissions. ClinVar has chosen a weekly candence to collect and process submissions, recalculate the impact on all VCVs and RCVs and release the entire new ClinVar dataset to the public (both the UI and FTP files).

ClinVar could have potentially recalculated any impacted VCVs and RCVs after each individual SCV that is processed but this level of re-evaluation would create a significant amount of versioning or noise that is not useful to the community. So batch processing and release management is the right choice for ClinVar.
