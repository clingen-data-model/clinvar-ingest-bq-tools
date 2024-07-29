"use strict";
/**
 * This module provides utility functions for parsing the `content` JSON objects
 * in the clinvar bigquery schema.
 * The module exports functions for parsing the following content types:
 * - AttributeSet, Citation, Comment, XRef, Attribute, HGVS, SequenceLocation, Software,
 * - NucleotideExpression, ProteinExpression, Method, Sample, and FamilyInfo,
 * - ObservedData, SetElement, TraitRelationship, and ClinicalAssertionTrait.
 */
/**
 * Builds a CommentOutput object based on the provided CommentInput.
 * @param item - The CommentInput object.
 * @returns The corresponding CommentOutput object.
 */
function buildCommentOutput(item) {
    return {
        text: item.$ ? item.$ : null,
        type: item['@Type'] ? item['@Type'] : null,
        source: item['@DataSource'] ? item['@DataSource'] : null
    };
}
/**
 * Builds an array of CommentOutput objects based on the provided CommentInput argument.
 * @param items - The array of CommentInput objects or a single CommentInput object
 * @returns An array of CommentOutput objects.
 */
function buildCommentsOutput(items) {
    if (!Array.isArray(items)) {
        items = [items];
    }
    return items.map((item) => (Object.assign({}, buildCommentOutput(item))));
}
/**
 * Parses the JSON input and returns an array of CommentOutput objects.
 * @param json - The JSON input string.
 * @returns An array of CommentOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseComments(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let comments = data && data.Comment ? data.Comment : [];
    return buildCommentsOutput(comments);
}
/**
 * Builds a CitationOutput object based on the provided CitationInput.
 * @param item - The CitationInput object.
 * @returns The corresponding CitationOutput object.
 */
function buildCitationOutput(item) {
    let id = item.ID && item.ID.$ ? item.ID.$ : null;
    let source = item.ID && item.ID['@Source'] ? item.ID['@Source'] : null;
    let curie = id && source ? `${source}:${id}` : null;
    return {
        id: id,
        source: source,
        url: item.URL && item.URL.$ ? item.URL.$ : null,
        text: item.CitationText && item.CitationText.$ ? item.CitationText.$ : null,
        type: item['@Type'] ? item['@Type'] : null,
        abbrev: item['@Abbrev'] ? item['@Abbrev'] : null,
        curie: curie
    };
}
/**
 * Builds an array of CitationOutput objects based on the provided CitationInput argument.
 * @param items - The array of CitationInput objects or a single CitationInput object
 * @returns An array of CitationOutput objects.
 */
function buildCitationsOutput(items) {
    if (!Array.isArray(items)) {
        items = [items];
    }
    return items.map((item) => (Object.assign({}, buildCitationOutput(item))));
}
/**
 * Parses the JSON input and returns an array of CitationOutput objects.
 * @param json - The JSON input string.
 * @returns An array of CitationOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseCitations(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let citations = data && data.Citation ? data.Citation : [];
    return buildCitationsOutput(citations);
}
/**
 * Builds a XRefOutput object based on the provided XRefInput.
 * @param item - The XRefInput object.
 * @returns The corresponding XRefOutput object.
 */
function buildXRefOutput(item) {
    return {
        db: item['@DB'] ? item['@DB'] : null,
        id: item['@ID'] ? item['@ID'] : null,
        url: item['@URL'] ? item['@URL'] : null,
        type: item['@Type'] ? item['@Type'] : null,
        status: item['@Status'] ? item['@Status'] : null
    };
}
/**
 * Builds an array of XRefOutput objects based on the provided XRefInput argument.
 * @param items - The array ofXRefInput objects or a single XRefInput object
 * @returns An array of XRefOutput objects.
 */
function buildXRefsOutput(items) {
    if (!Array.isArray(items)) {
        items = [items];
    }
    return items.map((item) => (Object.assign({}, buildXRefOutput(item))));
}
/**
 * Parses the JSON input and returns an array of XRefOutput objects.
 * @param json - The JSON input string.
 * @returns An array of XRefOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseXRefs(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let xrefs = data && data.XRef ? data.XRef : [];
    return buildXRefsOutput(xrefs);
}
/**
 * Builds a XRefItemOutput object based on the provided XRefItemInput.
 * @param item - The XRefItemInput object.
 * @returns The corresponding XRefItemOutput object.
 */
function buildXRefItemOutput(item) {
    return {
        db: item.db ? item.db : null,
        id: item.id ? item.id : null,
        type: item.type ? item.type : null,
        url: item.url ? item.url : null,
        status: item.status ? item.status : null,
        ref_field: item.ref_field ? item.ref_field : null
    };
}
/**
 * Parses the JSON input and returns an array of XRefItemOutput objects.
 * @param xref_json_list - The array of JSON input strings containing the XRefItemInput data.
 * @returns An array of XRefItemOutput objects.
 */
function parseXRefItems(json_array) {
    return json_array.map((json) => {
        let data;
        try {
            data = JSON.parse(json);
        }
        catch (e) {
            throw new Error('Invalid JSON input');
        }
        return buildXRefItemOutput(data);
    });
}
/**
 * Builds a AttributeOutput object based on the provided AttributeInput.
 * @param item - The AttributeInput object.
 * @returns The corresponding AttributeOutput object.
 */
function buildAttributeOutput(item) {
    return {
        type: item['@Type'] ? item['@Type'] : null,
        value: item.$ ? item.$ : null,
        integer_value: item['@integerValue'] ? parseInt(item['@integerValue'], 10) : null,
        date_value: item['@dateValue'] ? new Date(item['@dateValue']) : null
    };
}
/**
 * Parses the JSON input and returns an Attribute object.
 * @param json - The JSON input string.
 * @returns An AttributeOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseAttribute(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    return buildAttributeOutput(data);
}
/**
 * Builds a AttributeSetOutput object based on the provided AttributeSetInput.
 * @param item - The AttributeSetInput object.
 * @returns The corresponding AttributeSetOutput object.
 */
function buildAttributeSetOutput(item) {
    return {
        attribute: item.Attribute ? buildAttributeOutput(item.Attribute) : null,
        citation: item.Citation ? buildCitationsOutput(item.Citation) : null,
        xref: item.XRef ? buildXRefsOutput(item.XRef) : null,
        comment: item.Comment ? buildCommentsOutput(item.Comment) : null
    };
}
/**
 * Builds an array of AttributeSetOutput objects based on the provided AttributeSetInput argument.
 * @param items - The array of AttributeSetInput objects or a single AttributeSetInput object
 * @returns An array of AttributeSetOutput objects.
 */
function buildAttributeSetsOutput(items) {
    if (!Array.isArray(items)) {
        items = [items];
    }
    return items.map((item) => (Object.assign({}, buildAttributeSetOutput(item))));
}
/**
 * Parses the JSON input and returns an array of AttrCitXRefCmntOutput objects.
 * @param json - The JSON input string.
 * @returns An array of AttrCitXRefCmntOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseAttributeSet(json) {
    let data; // Declare the variable 'data'
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let attributeSets = data && data.AttributeSet ? data.AttributeSet : [];
    return buildAttributeSetsOutput(attributeSets);
}
/**
 * Builds a NucleotideExpressionOutput object based on the provided NucleotideExpressionInput.
 * @param item - The NucleotideExpressionInput object.
 * @returns The corresponding NucleotideExpressionOutput object.
 */
function buildNucleotideExpressionOutput(item) {
    return {
        expression: item.Expression ? item.Expression.$ : null,
        sequence_type: item['@sequenceType'] ? item['@sequenceType'] : null,
        sequence_accession_version: item['@sequenceAccessionVersion'] ? item['@sequenceAccessionVersion'] : null,
        sequence_accession: item['@sequenceAccession'] ? item['@sequenceAccession'] : null,
        sequence_version: item['@sequenceVersion'] ? item['@sequenceVersion'] : null,
        change: item['@change'] ? item['@change'] : null,
        assembly: item['@Assembly'] ? item['@Assembly'] : null,
        submitted: item['@Submitted'] ? item['@Submitted'] : null,
        mane_select: item['@MANESelect'] ? item['@MANESelect'] === 'true' : null,
        mane_plus_clinical: item['@MANEPlusClinical'] ? item['@MANEPlusClinical'] === 'true' : null
    };
}
/**
 * Parses the JSON input and returns a NucleotideExpressionOutput object.
 * @param json - The JSON input string.
 * @returns A NucleotideExpressionOutput object.
 * @throws {Error} If the JSON input is invalid.
 */
function parseNucleotideExpression(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let nucleotideExpression = data && data.NucleotideExpression ? data.NucleotideExpression : {};
    return buildNucleotideExpressionOutput(nucleotideExpression);
}
/**
 * Builds a ProteinExpressionOutput object based on the provided ProteinExpressionInput.
 * @param item - The ProteinExpressionInput object.
 * @returns The corresponding ProteinExpressionOutput object.
 */
function buildProteinExpressionOutput(item) {
    return {
        expression: item.Expression ? item.Expression.$ : null,
        sequence_accession_version: item['@sequenceAccessionVersion'] ? item['@sequenceAccessionVersion'] : null,
        sequence_accession: item['@sequenceAccession'] ? item['@sequenceAccession'] : null,
        sequence_version: item['@sequenceVersion'] ? item['@sequenceVersion'] : null,
        change: item['@change'] ? item['@change'] : null
    };
}
/**
 * Parses the JSON input and returns a ProteinExpressionOutput object.
 * @param json - The JSON input string.
 * @returns A ProteinExpressionOutput object.
 * @throws {Error}  If the JSON input is invalid.
 */
function parseProteinExpression(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let proteinExpression = data && data.ProteinExpression ? data.ProteinExpression : {};
    return buildProteinExpressionOutput(proteinExpression);
}
/**
 * Builds an HGVSOutput object based on the provided HGVSInput.
 * @param item - The HGVSInput object.
 * @returns The corresponding HGVSOutput object.
 */
function buildHGVSOutput(item) {
    return {
        nucleotide_expression: item.NucleotideExpression ? buildNucleotideExpressionOutput(item.NucleotideExpression) : null,
        protein_expression: item.ProteinExpression ? buildProteinExpressionOutput(item.ProteinExpression) : null,
        molecular_consequence: item.MolecularConsequence ? buildXRefsOutput(item.MolecularConsequence) : null,
        type: item['@Type'] ? item['@Type'] : null,
        assembly: item['@Assembly'] ? item['@Assembly'] : null
    };
}
/**
 * Builds an array of HGVSOutput objects based on the provided HGVSInput argument.
 * @param items - The array of HGVSInput objects or a single HGVSInput object
 * @returns An array of HGVSOutput objects.
 */
function buildHGVSArrayOutput(items) {
    if (!Array.isArray(items)) {
        items = [items];
    }
    return items.map((item) => (Object.assign({}, buildHGVSOutput(item))));
}
/**
 * Parses the JSON input and returns an HGVSOutput array.
 * @param json - The JSON input string.
 * @returns An array of HGVSOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseHGVS(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let hgvs = data && data.HGVS ? data.HGVS : [];
    return buildHGVSArrayOutput(hgvs);
}
/**
 * Builds a SequenceLocationOutput object based on the provided SequenceLocationInput.
 * @param item - The SequenceLocationInput object.
 * @returns The corresponding SequenceLocationOutput object.
 */
function buildSequenceLocationOutput(item) {
    return {
        for_display: item['@forDisplay'] ? item['@forDisplay'] : null,
        assembly: item['@Assembly'] ? item['@Assembly'] : null,
        assembly_accession_version: item['@AssemblyAccessionVersion'] ? item['@AssemblyAccessionVersion'] : null,
        assembly_status: item['@AssemblyStatus'] ? item['@AssemblyStatus'] : null,
        accession: item['@Accession'] ? item['@Accession'] : null,
        chr: item['@Chr'] ? item['@Chr'] : null,
        start: item['@start'] ? item['@start'] : null,
        stop: item['@stop'] ? item['@stop'] : null,
        inner_start: item['@innerStart'] ? item['@innerStart'] : null,
        inner_stop: item['@innerStop'] ? item['@innerStop'] : null,
        outer_start: item['@outerStart'] ? item['@outerStart'] : null,
        outer_stop: item['@outerStop'] ? item['@outerStop'] : null,
        variant_length: item['@variantLength'] ? item['@variantLength'] : null,
        display_start: item['@display_start'] ? item['@display_start'] : null,
        display_stop: item['@display_stop'] ? item['@display_stop'] : null,
        position_vcf: item['@positionVCF'] ? item['@positionVCF'] : null,
        reference_allele_vcf: item['@referenceAlleleVCF'] ? item['@referenceAlleleVCF'] : null,
        alternate_allele_vcf: item['@alternateAlleleVCF'] ? item['@alternateAlleleVCF'] : null,
        strand: item['@Strand'] ? item['@Strand'] : null,
        reference_allele: item['@referenceAllele'] ? item['@referenceAllele'] : null,
        alternate_allele: item['@alternateAllele'] ? item['@alternateAllele'] : null,
        for_display_length: item['@forDisplayLength'] ? item['@forDisplayLength'] : null
    };
}
/**
 * Parses the JSON input and returns an array of SequenceLocationOutput objects.
 * @param json - The JSON input string.
 * @returns An array of SequenceLocationOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseSequenceLocations(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let sequenceLocations = data && data.SequenceLocation ? data.SequenceLocation : [];
    if (!Array.isArray(sequenceLocations)) {
        sequenceLocations = [sequenceLocations];
    }
    return sequenceLocations.map((item) => (Object.assign({}, buildSequenceLocationOutput(item))));
}
/**
 * Builds a SoftwareOutput object based on the provided SoftwareInput.
 * @param item - The SoftwareInput object.
 * @returns The corresponding SoftwareOutput object.
 */
function buildSoftwareOutput(item) {
    return {
        name: item['@name'] ? item['@name'] : null,
        version: item['@version'] ? item['@version'] : null,
        purpose: item['@purpose'] ? item['@purpose'] : null
    };
}
/**
 * Builds an array of SoftwareOutput objects based on the provided SoftwareInput.
 * @param items - The SoftwareInput object or an array of SoftwareInput objects.
 * @returns An array of SoftwareOutput objects.
 */
function buildSoftwaresOutput(items) {
    if (!Array.isArray(items)) {
        items = [items];
    }
    return items.map((item) => (Object.assign({}, buildSoftwareOutput(item))));
}
/**
 * Parses the JSON input and returns an array of SoftwareOutput objects.
 * @param json - The JSON input string.
 * @returns An array of SoftwareOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseSoftware(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let software = data && data.Software ? data.Software : [];
    return buildSoftwaresOutput(software);
}
/**
 * Builds a MethodAttributeOutput object based on the provided MethodAttributeInput.
 * @param item - The MethodAttributeInput object.
 * @returns The corresponding MethodAttributeOutput object.
 */
function buildMethodAttributeOutput(item) {
    return {
        attribute: item.Attribute ? buildAttributeOutput(item.Attribute) : null
    };
}
function buildMethodAttributesOutput(items) {
    if (!Array.isArray(items)) {
        items = [items];
    }
    return items.map((item) => (Object.assign({}, buildMethodAttributeOutput(item))));
}
/**
 * Parses the JSON input and returns an array of MethodAttributeOutput objects.
 * @param json - The JSON input string.
 * @returns An array of MethodAttributeOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseMethodAttributes(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let methodAttributes = data && data.MethodAttribute ? data.MethodAttribute : [];
    return buildMethodAttributesOutput(methodAttributes);
}
/**
 * Builds a ObsMethodAttributeOutput object based on the provided ObsMethodAttributeInput.
 * @param item - The ObsMethodAttributeInput object.
 * @returns The corresponding ObsMethodAttributeOutput object.
 */
function buildObsMethodAttributeOutput(item) {
    return {
        attribute: item.Attribute ? buildAttributeOutput(item.Attribute) : null,
        comment: item.Comment ? buildCommentOutput(item.Comment) : null
    };
}
/**
 * Builds an array of ObsMethodAttributeOutput objects based on the provided ObsMethodAttributeInput.
 * @param items - The ObsMethodAttributeInput object or an array of ObsMethodAttributeInput objects.
 * @returns An array of ObsMethodAttributeOutput objects.
 */
function buildObsMethodAttributesOutput(items) {
    if (!Array.isArray(items)) {
        items = [items];
    }
    return items.map((item) => (Object.assign({}, buildObsMethodAttributeOutput(item))));
}
/**
 * Parses the JSON input and returns an array of ObsMethodAttributeOutput objects.
 * @param json - The JSON input string.
 * @returns An array of ObsMethodAttributeOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseObsMethodAttributes(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let obsMethodAttributes = data && data.ObsMethodAttribute ? data.ObsMethodAttribute : [];
    return buildObsMethodAttributesOutput(obsMethodAttributes);
}
/**
 * Builds a MethodOutput object based on the provided MethodInput.
 * @param item - The MethodInput object.
 * @returns The corresponding MethodOutput object.
 */
function buildMethodOutput(item) {
    return {
        name_platform: item.NamePlatform && item.NamePlatform.$ ? item.NamePlatform.$ : null,
        type_platform: item.TypePlatform && item.TypePlatform.$ ? item.TypePlatform.$ : null,
        purpose: item.Purpose && item.Purpose.$ ? item.Purpose.$ : null,
        result_type: item.ResultType && item.ResultType.$ ? item.ResultType.$ : null,
        min_reported: item.MinReported && item.MinReported.$ ? parseInt(item.MinReported.$, 10) : null,
        max_reported: item.MaxReported && item.MaxReported.$ ? parseInt(item.MaxReported.$, 10) : null,
        reference_standard: item.ReferenceStandard && item.ReferenceStandard.$ ? item.ReferenceStandard.$ : null,
        description: item.Description && item.Description.$ ? item.Description.$ : null,
        source_type: item.SourceType && item.SourceType.$ ? item.SourceType.$ : null,
        method_type: item.MethodType && item.MethodType.$ ? item.MethodType.$ : null,
        citation: item.Citation ? buildCitationsOutput(item.Citation) : null,
        xref: item.XRef ? buildXRefsOutput(item.XRef) : null,
        software: item.Software ? buildSoftwaresOutput(item.Software) : null,
        method_attribute: item.MethodAttribute ? buildMethodAttributesOutput(item.MethodAttribute) : null,
        obs_method_attribute: item.ObsMethodAttribute ? buildObsMethodAttributesOutput(item.ObsMethodAttribute) : null
    };
}
function buildMethodsOutput(items) {
    if (!Array.isArray(items)) {
        items = [items];
    }
    return items.map((item) => (Object.assign({}, buildMethodOutput(item))));
}
/**
 * Parses the JSON input and returns an array of MethodOutput objects.
 * @param json - The JSON input string.
 * @returns An array of MethodOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseMethods(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let methods = data && data.Method ? data.Method : [];
    return buildMethodsOutput(methods);
}
/**
 * Builds a ObservedDataOutput object based on the provided ObservedDataInput.
 * @param item - The ObservedDataInput object.
 * @returns The corresponding ObservedDataOutput object.
 */
function buildObservedDataOutput(item) {
    return {
        attribute: item.Attribute ? buildAttributeOutput(item.Attribute) : null,
        severity: item.Severity ? item.Severity : null,
        citation: item.Citation ? buildCitationsOutput(item.Citation) : null,
        xref: item.XRef ? buildXRefsOutput(item.XRef) : null,
        comment: item.Comment ? buildCommentsOutput(item.Comment) : null
    };
}
function buildObservedDatasOutput(items) {
    if (!Array.isArray(items)) {
        items = [items];
    }
    return items.map((item) => (Object.assign({}, buildObservedDataOutput(item))));
}
/**
 * Parses the JSON input and returns an array of ObservedDataOutput objects.
 * @param json - The JSON input string.
 * @returns An array of ObservedDataOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseObservedData(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let observedData = data && data.ObservedData ? data.ObservedData : [];
    return buildObservedDatasOutput(observedData);
}
/**
 * Builds a SetElementOutput object based on the provided SetElementInput.
 * @param item - The SetElementInput object.
 * @returns The corresponding SetElementOutput object.
 */
function buildSetElementOutput(item) {
    return {
        element_value: item.ElementValue && item.ElementValue.$ ? item.ElementValue.$ : null,
        type: item.ElementValue && item.ElementValue['@Type'] ? item.ElementValue['@Type'] : null,
        citation: item.Citation ? buildCitationsOutput(item.Citation) : null,
        xref: item.XRef ? buildXRefsOutput(item.XRef) : null,
        comment: item.Comment ? buildCommentsOutput(item.Comment) : null
    };
}
/**
 * Builds an array of SetElementOutput objects based on the provided SetElementInput.
 * @param items - The SetElementInput object or an array of SetElementInput objects.
 * @returns An array of SetElementOutput objects.
 */
function buildSetElementsOutput(items) {
    if (!Array.isArray(items)) {
        items = [items];
    }
    return items.map((item) => (Object.assign({}, buildSetElementOutput(item))));
}
/**
 * Parses the JSON input and returns an array of SetElementOutput objects.
 * @param json - The JSON input string.
 * @returns An array of SetElementOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseSetElement(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let setElements = data && data.SetElement ? data.SetElement : [];
    return buildSetElementsOutput(setElements);
}
/**
 * Builds a FamilyInfoOutput object based on the provided FamilyInfoInput.
 * @param item - The FamilyInfoInput object.
 * @returns The corresponding FamilyInfoOutput object.
 */
function buildFamilyInfoOutput(item) {
    return {
        family_history: item.FamilyHistory ? item.FamilyHistory : null,
        num_families: item['@NumFamilies'] ? parseInt(item['@NumFamilies'], 10) : null,
        num_families_with_variant: item['@NumFamiliesWithVariant'] ? parseInt(item['@NumFamiliesWithVariant'], 10) : null,
        num_families_with_segregation_observed: item['@NumFamiliesWithSegregationObserved'] ? parseInt(item['@NumFamiliesWithSegregationObserved'], 10) : null,
        pedigree_id: item['@PedigreeID'] ? item['@PedigreeID'] : null,
        segregation_observed: item['@SegregationObserved'] ? item['@SegregationObserved'] : null
    };
}
/**
 * Parses the JSON input and returns a FamilyInfoOutput object.
 * @param json - The JSON input string.
 * @returns A FamilyInfoOutput object.
 * @throws {Error} If the JSON input is invalid.
 */
function parseFamilyInfo(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let familyInfo = data && data.FamilyInfo ? data.FamilyInfo : {};
    return buildFamilyInfoOutput(familyInfo);
}
/**
 * Builds a TraitRelationshipOutput object based on the provided TraitRelationshipInput.
 * @param item - The TraitRelationshipInput object.
 * @returns The corresponding TraitRelationshipOutput object.
 */
function buildTraitRelationshipOutput(item) {
    return {
        name: item.Name ? buildSetElementsOutput(item.Name) : null,
        symbol: item.Symbol ? buildSetElementsOutput(item.Symbol) : null,
        attribute_set: item.AttributeSet ? buildAttributeSetsOutput(item.AttributeSet) : null,
        citation: item.Citation ? buildCitationsOutput(item.Citation) : null,
        xref: item.XRef ? buildXRefsOutput(item.XRef) : null,
        source: item.Source ? item.Source : null,
        type: item['@Type'] ? item['@Type'] : null
    };
}
/**
 * Builds an array of TraitRelationshipOutput objects based on the provided TraitRelationshipInput.
 * @param items - The TraitRelationshipInput object or an array of TraitRelationshipInput objects.
 * @returns An array of TraitRelationshipOutput objects.
 */
function buildTraitRelationshipsOutput(items) {
    if (!Array.isArray(items)) {
        items = [items];
    }
    return items.map((item) => (Object.assign({}, buildTraitRelationshipOutput(item))));
}
/**
 * Parses the JSON input and returns an array of TraitRelationshipOutput objects.
 * @param json - The JSON input string.
 * @returns An array of TraitRelationshipOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseTraitRelationships(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let traitRelationships = data && data.TraitRelationship ? data.TraitRelationship : [];
    return buildTraitRelationshipsOutput(traitRelationships);
}
/**
 * Builds a ClinicalAsserTraitOutput object based on the provided ClinicalAsserTraitInput.
 * @param item - The ClinicalAsserTraitInput object.
 * @returns The corresponding ClinicalAsserTraitOutput object.
 */
function buildClinicalAsserTraitOutput(item) {
    return {
        name: item.Name ? buildSetElementsOutput(item.Name) : null,
        symbol: item.Symbol ? buildSetElementsOutput(item.Symbol) : null,
        attribute_set: item.AttributeSet ? buildAttributeSetsOutput(item.AttributeSet) : null,
        trait_relationship: item.TraitRelationship ? buildTraitRelationshipsOutput(item.TraitRelationship) : null,
        citation: item.Citation ? buildCitationsOutput(item.Citation) : null,
        xref: item.XRef ? buildXRefsOutput(item.XRef) : null,
        comment: item.Comment ? buildCommentsOutput(item.Comment) : null,
        type: item['@Type'] ? item['@Type'] : null,
        clinical_features_affected_status: item['@ClinicalFeaturesAffectedStatus'] ? item['@ClinicalFeaturesAffectedStatus'] : null,
        id: item['@ID'] ? item['@ID'] : null
    };
}
/**
 * Builds an array of ClinicalAsserTraitOutput objects based on the provided ClinicalAsserTraitInput.
 * @param items - The ClinicalAsserTraitInput object or an array of ClinicalAsserTraitInput objects.
 * @returns An array of ClinicalAsserTraitOutput objects.
 */
function buildClinicalAsserTraitsOutput(items) {
    if (!Array.isArray(items)) {
        items = [items];
    }
    return items.map((item) => (Object.assign({}, buildClinicalAsserTraitOutput(item))));
}
/**
 * Parses the JSON input and returns an array of ClinicalAsserTraitOutput objects.
 * @param json - The JSON input string.
 * @returns An array of ClinicalAsserTraitOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseClinicalAsserTraits(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let clinicalAsserTraits = data && data.Trait ? data.Trait : [];
    return buildClinicalAsserTraitsOutput(clinicalAsserTraits);
}
/**
 * Builds an IndicationOutput object based on the provided IndicationInput.
 * @param item - The IndicationInput object.
 * @returns The corresponding IndicationOutput object.
 */
function buildIndicationOutput(item) {
    return {
        trait: item.Trait ? buildClinicalAsserTraitsOutput(item.Trait) : null,
        name: item.Name ? buildSetElementsOutput(item.Name) : null,
        symbol: item.Symbol ? buildSetElementsOutput(item.Symbol) : null,
        attribute_set: item.AttributeSet ? buildAttributeSetOutput(item.AttributeSet) : null,
        citation: item.Citation ? buildCitationsOutput(item.Citation) : null,
        xref: item.XRef ? buildXRefsOutput(item.XRef) : null,
        comment: item.Comment ? buildCommentOutput(item.Comment) : null,
        type: item['@Type'] ? item['@Type'] : null,
        id: item['@ID'] ? item['@ID'] : null
    };
}
/**
 * Builds an array of IndicationOutput objects based on the provided IndicationInput.
 * @param items - The IndicationInput object or an array of IndicationInput objects.
 * @returns An array of IndicationOutput objects.
 */
function buildIndicationsOutput(items) {
    if (!Array.isArray(items)) {
        items = [items];
    }
    return items.map((item) => (Object.assign({}, buildIndicationOutput(item))));
}
/**
 * Parses the JSON input and returns an array of IndicationOutput objects.
 * @param json - The JSON input string.
 * @returns An array of IndicationOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseIndications(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let indications = data && data.Indication ? data.Indication : [];
    return buildIndicationsOutput(indications);
}
/**
 * Builds an AgeOutput object based on the provided AgeInput.
 * @param item - The AgeInput object.
 * @returns The corresponding AgeOutput object.
 */
function buildAgeOutput(item) {
    return {
        value: item.$ ? parseInt(item.$, 10) : null,
        type: item['@Type'] ? item['@Type'] : null,
        age_unit: item['@age_unit'] ? item['@age_unit'] : null
    };
}
/**
 * Builds an array of AgeOutput objects based on the provided AgeInput.
 * If an exact age is provided, the function will return an array with a single AgeOutput object.
 * @param items - The AgeInput object or an array of AgeInput objects.
 * @returns An array of AgeOutput objects.
 */
function buildAgeRangeOutput(items) {
    if (!Array.isArray(items)) {
        items = [items];
    }
    return items.map((item) => (Object.assign({}, buildAgeOutput(item))));
}
/**
 * Parses the JSON input and returns an array of AgeOutput objects.
 * @param json - The JSON input string.
 * @returns An array of AgeOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseAges(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let ages = data && data.Age ? data.Age : [];
    return buildAgeRangeOutput(ages);
}
/**
 * Builds a SampleOutput object based on the provided SampleInput.
 * @param item - The SampleInput object.
 * @returns The corresponding SampleOutput object.
 */
function buildSampleOutput(item) {
    return {
        sample_description: {
            description: item.SampleDescription && item.SampleDescription.Description ? buildSetElementOutput(item.SampleDescription.Description) : null,
            citation: item.SampleDescription && item.SampleDescription.Citation ? buildCitationOutput(item.SampleDescription.Citation) : null
        },
        origin: item.Origin && item.Origin.$ ? item.Origin.$ : null,
        ethnicity: item.Ethnicity && item.Ethnicity.$ ? item.Ethnicity.$ : null,
        geographic_origin: item.GeographicOrigin && item.GeographicOrigin.$ ? item.GeographicOrigin.$ : null,
        tissue: item.Tissue && item.Tissue.$ ? item.Tissue.$ : null,
        cell_line: item.CellLine && item.CellLine.$ ? item.CellLine.$ : null,
        species: item.Species && item.Species.$ ? item.Species.$ : null,
        taxonomy_id: item.Species && item.Species['@TaxonomyId'] ? item.Species['@TaxonomyId'] : null,
        age: item.Age ? buildAgeRangeOutput(item.Age) : null,
        strain: item.Strain && item.Strain.$ ? item.Strain.$ : null,
        affected_status: item.AffectedStatus && item.AffectedStatus.$ ? item.AffectedStatus.$ : null,
        number_tested: item.NumberTested && item.NumberTested.$ ? parseInt(item.NumberTested.$, 10) : null,
        number_males: item.NumberMales && item.NumberMales.$ ? parseInt(item.NumberMales.$, 10) : null,
        number_females: item.NumberFemales && item.NumberFemales.$ ? parseInt(item.NumberFemales.$, 10) : null,
        number_chr_tested: item.NumberChrTested && item.NumberChrTested.$ ? parseInt(item.NumberChrTested.$, 10) : null,
        gender: item.Gender && item.Gender.$ ? item.Gender.$ : null,
        family_data: item.FamilyData ? buildFamilyInfoOutput(item.FamilyData) : null,
        proband: item.Proband && item.Proband.$ ? item.Proband.$ : null,
        indication: item.Indication ? buildIndicationOutput(item.Indication) : null,
        citation: item.Citation ? buildCitationsOutput(item.Citation) : null,
        xref: item.XRef ? buildXRefsOutput(item.XRef) : null,
        comment: item.Comment ? buildCommentsOutput(item.Comment) : null,
        source_type: item.SourceType && item.SourceType.$ ? item.SourceType.$ : null
    };
}
/**
 * Parses the JSON input and returns a SampleOutput object.
 * @param json - The JSON input string.
 * @returns A SampleOutput object.
 * @throws {Error} If the JSON input is invalid.
 */
function parseSample(json) {
    let data;
    try {
        data = JSON.parse(json);
    }
    catch (e) {
        throw new Error('Invalid JSON input');
    }
    let sample = data && data.Sample ? data.Sample : {};
    return buildSampleOutput(sample);
}
/**
 * Derives the HGVS (Human Genome Variation Society) notation for a given variation.
 * @param seqLoc - The sequence location output from the clinvar variation object.
 * @returns The HGVS notation for the variation, or null if it cannot be derived.
 */
function deriveHGVS(variation_type, seqLoc) {
    let hgvs = null;
    // cannot proceed without an accession.
    if (seqLoc.accession == null) {
        return hgvs;
    }
    // process SNVs
    if (variation_type == "single nucleotide variant" &&
        seqLoc.position_vcf != null && seqLoc.reference_allele_vcf != null && seqLoc.alternate_allele_vcf != null) {
        hgvs = `${seqLoc.accession}:${seqLoc.accession == 'NC_012920.1' ? "m" : "g"}.${seqLoc.position_vcf}${seqLoc.reference_allele_vcf}>${seqLoc.alternate_allele_vcf}`;
        return hgvs;
    }
    // eliminate anything remaining that is not a deletion or duplication
    const delDupTypes = ["Deletion", "copy number loss", "Duplication", "copy number gain"];
    if (!delDupTypes.includes(variation_type) ||
        (seqLoc.start != null && (seqLoc.inner_start != null || seqLoc.outer_start != null)) ||
        (seqLoc.stop != null && (seqLoc.inner_stop != null || seqLoc.outer_stop != null)) ||
        (seqLoc.start == null && seqLoc.inner_start == null && seqLoc.outer_start == null)) {
        return hgvs;
    }
    // process deletions and duplications only
    const delDupType = (delDupTypes.indexOf(variation_type) < 2 ? "del" : "dup");
    const rangeStart = `(${seqLoc.outer_start != null ? seqLoc.outer_start : "?"}_${seqLoc.inner_start != null ? seqLoc.inner_start : "?"})`;
    const rangeStop = `(${seqLoc.inner_stop != null ? seqLoc.inner_stop : "?"}_${seqLoc.outer_stop != null ? seqLoc.outer_stop : "?"})`;
    const finalStart = `${seqLoc.start != null ? seqLoc.start : rangeStart}`;
    const finalStop = `${seqLoc.stop != null ? seqLoc.stop : rangeStop}`;
    if (finalStart == finalStop) {
        hgvs = `${seqLoc.accession}:${seqLoc.accession == 'NC_012920.1' ? "m" : "g"}.${finalStart}${delDupType}`;
    }
    else {
        hgvs = `${seqLoc.accession}:${seqLoc.accession == 'NC_012920.1' ? "m" : "g"}.${finalStart}${finalStop != "" ? "_" + finalStop : finalStop}${delDupType}`;
    }
    return hgvs;
}
