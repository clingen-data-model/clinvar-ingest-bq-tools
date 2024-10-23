/**
 * This module provides utility functions for parsing the `content` JSON objects
 * in the clinvar bigquery schema. 
 * The module exports functions for parsing the following content types:
 * - AttributeSet, Citation, Comment, XRef, Attribute, HGVS, SequenceLocation, Software,
 * - NucleotideExpression, ProteinExpression, Method, Sample, and FamilyInfo,
 * - ObservedData, SetElement, TraitRelationship, and ClinicalAssertionTrait.
 */


// -- GeneList interfaces and functions --

// below is an example of a JSON object that represents a clinical assertion variant object
// {
//   "GeneList": {
//     "Gene": {
//       "@Symbol":"ZMPSTE24"
//       "@RelationshipType":"asserted, but not computed"
//       "Name":{"$":"name of gene"}
//     }
//   }
// }

/**
 * Represents the input structure for a gene list.
 */
interface GeneListInput {
  Gene?: {
    '@Symbol': string;
    '@RelationshipType': string;
    Name: {
      $: string;
    };
  };
} 

/**
 * Represents the output structure for a gene list.
 */
interface GeneListOutput {
  symbol: string | null;
  relationship_type: string | null;
  name: string | null;
}


interface GeneListData {
  GeneList?: GeneListInput | GeneListInput[];
}

/**
 * Builds a GeneListOutput object based on the provided GeneListInput.
 * @param item - The GeneListInput object.
 * @returns The corresponding GeneListOutput object.
 */
function buildGeneListOutput(item: GeneListInput): GeneListOutput {
  return {
    symbol: item.Gene ? item.Gene['@Symbol'] : null,
    relationship_type: item.Gene ? item.Gene['@RelationshipType'] : null,
    name: item.Gene && item.Gene.Name ? item.Gene.Name.$ : null
  };
}

/**
 * Builds an array of GeneListOutput objects based on the provided GeneListInput argument.
 * @param items - The array of GeneListInput objects or a single GeneListInput object
 * @returns An array of GeneListOutput objects.
 */
function buildGeneListsOutput(items: GeneListInput | GeneListInput[]): GeneListOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): GeneListOutput => ({
    ...buildGeneListOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an array of GeneListOutput objects.
 * @param json - The JSON input string.
 * @returns An array of GeneListOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseGeneLists(json: string): GeneListOutput[] {
  let data: GeneListData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let geneLists = data && data.GeneList ? data.GeneList : [];

  return buildGeneListsOutput(geneLists);
}

// -- Comment interfaces and functions --

// below is an example of a JSON object that represents a comment object
// "Comment":[{
//   "$": "This is a comment.",
//   "@Type": "General",
//   "@DataSource": "ClinVar"
// }]

/**
 * Represents the input structure for a gene list.
 */
interface CommentInput {
  $?: string;
  '@Type'?: string;
  '@DataSource'?: string;
}

/**
 * Represents the output structure for a comment.
 */
interface CommentOutput {
  text: string | null;
  type: string | null;
  source: string | null;
}

interface CommentData {
  Comment?: CommentInput | CommentInput[];
}

/**
 * Builds a CommentOutput object based on the provided CommentInput.
 * @param item - The CommentInput object.
 * @returns The corresponding CommentOutput object.
 */
function buildCommentOutput(item: CommentInput): CommentOutput {
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
function buildCommentsOutput(items: CommentInput | CommentInput[]): CommentOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): CommentOutput => ({
    ...buildCommentOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an array of CommentOutput objects.
 * @param json - The JSON input string.
 * @returns An array of CommentOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */ 
function parseComments(json: string): CommentOutput[] {
  let data: CommentData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let comments = data && data.Comment ? data.Comment : [];

  return buildCommentsOutput(comments);
}

// -- Citation interfaces and functions --

//below is an example of a JSON object that represents a citation object
// "Citation": {
//   "@Type": "review",
//   "@Abbrev": "GeneReviews",
//   "ID": [
//     {
//       "@Source": "PubMed",
//       "$": "20301418"
//     },
//     {
//       "@Source": "BookShelf",
//       "$": "NBK1240"
//     }
//   ],
//   "URL": {"$": "https://pubmed/entry/20301418"},
//   "CitationText": { "$": "This is a citation." },
// } 
// a second example
// "Citation": {
//   "@Type": "review",
//   "@Abbrev": "GeneReviews",
//   "ID": { "@Source": "PubMed", "$": "20301418" },
//   "URL": {"$": "https://pubmed/entry/20301418"},
//   "CitationText": { "$": "This is a citation." },
// }

/**
 * Represents the input structure for a citation.
 */
interface CitationInput {
  '@Type'?: string;
  '@Abbrev'?: string;
  ID?: { '@Source': string; $: string } | { '@Source': string; $: string }[];
  URL?: { $: string };
  CitationText?: { $: string };
}

/**
 * Represents the output structure for a citation.
 */
interface CitationOutput {
  type: string | null;
  abbrev: string | null;
  id: { source: string; id: string, curie: string }[] | null;
  url: string | null;
  text: string | null;
}

interface CitationData {
  Citation?: CitationInput | CitationInput[];
}

/**
 * Builds a CitationOutput object based on the provided CitationInput.
 * @param item - The CitationInput object.
 * @returns The corresponding CitationOutput object.
 */
function buildCitationOutput(item: CitationInput): CitationOutput {
  return {
    type: item['@Type'] ? item['@Type'] : null,
    abbrev: item['@Abbrev'] ? item['@Abbrev'] : null,
    id: item.ID ? (Array.isArray(item.ID) ? item.ID.map((id) => ({ source: id['@Source'], id: id.$, curie: `${id['@Source']}:${id.$}`})) : [{ source: item.ID['@Source'], id: item.ID.$, curie: `${item.ID['@Source']}:${item.ID.$}` }]) : null,
    url: item.URL ? item.URL.$ : null,
    text: item.CitationText ? item.CitationText.$ : null
  };  
}

/**
 * Builds an array of CitationOutput objects based on the provided CitationInput argument.
 * @param items - The array of CitationInput objects or a single CitationInput object
 * @returns An array of CitationOutput objects.
 */
function buildCitationsOutput(items: CitationInput | CitationInput[]): CitationOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): CitationOutput => ({
    ...buildCitationOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an array of CitationOutput objects.
 * @param json - The JSON input string.
 * @returns An array of CitationOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseCitations(json: string): CitationOutput[] {
  let data: CitationData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let citations = data && data.Citation ? data.Citation : [];

  return buildCitationsOutput(citations);
}


// -- XRef interfaces and functions --

// below is an example of a JSON object that represents a xref object
// "XRef": [{
//   "@DB": "OMIM",
//   "@ID": "123456",
//   "@Type": "MIM number",
//   "@URL": "https://omim.org/entry/123456",
//   "@Status": "current"
// }] 

/**
 * Represents the input structure for a xref.
 */
interface XRefInput {
  '@DB'?: string;
  '@ID'?: string;
  '@Type'?: string;
  '@URL'?: string;
  '@Status'?: string; 
}

/**
 * Represents the output structure for a xref.
 */
interface XRefOutput {
  db: string | null;
  id: string | null;
  url: string | null;
  type: string | null;
  status: string | null;
}

interface XRefData {
  XRef?: XRefInput | XRefInput[];
}

/**
 * Builds a XRefOutput object based on the provided XRefInput.
 * @param item - The XRefInput object.
 * @returns The corresponding XRefOutput object.
 */
function buildXRefOutput(item: XRefInput): XRefOutput {
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
function buildXRefsOutput(items: XRefInput | XRefInput[]): XRefOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): XRefOutput => ({
    ...buildXRefOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an array of XRefOutput objects.
 * @param json - The JSON input string.
 * @returns An array of XRefOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseXRefs(json: string): XRefOutput[] {
  let data: XRefData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let xrefs = data && data.XRef ? data.XRef : [];

  return buildXRefsOutput(xrefs);
}

// -- XRefItem interfaces and functions for direct XRef items not in `content` fields.

// below is an example of a JSON object that represents a xref item outside of the 'content' field
// {
//   "db": "OMIM",
//   "id": "123456",
//   "type": "MIM number",
//   "url": "https://omim.org/entry/123456",
//   "status": "current"
// }

interface XRefItemInput {
  db?: string;
  id?: string;
  type?: string;
  url?: string;
  status?: string;
  ref_field?: string;
}

interface XRefItemOutput {
  db: string | null;
  id: string | null;
  type: string | null;
  url: string | null;
  status: string | null;
  ref_field: string | null;
}

/**
 * Builds a XRefItemOutput object based on the provided XRefItemInput.
 * @param item - The XRefItemInput object.
 * @returns The corresponding XRefItemOutput object.
 */
function buildXRefItemOutput(item: XRefItemInput): XRefItemOutput {
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
function parseXRefItems(json_array: Array<string>): XRefItemOutput[] {
  return json_array.map((json) => {
    let data: XRefItemInput;
    try {
      data = JSON.parse(json);
    } catch (e) {
      throw new Error('Invalid JSON input');
    }
    return buildXRefItemOutput(data);
  });
}

// -- Attribute interfaces and functions --

// below is an example of a JSON object that represents a attribute object
// "Attribute": {
//   "$": "attirbute type or name",
//   "@integerValue": "1",
//   "@dateValue": "2021-01-01"
// }

/**
 * Represents the input structure for a attribute.
 */
interface AttributeInput {
  $?: string;
  '@Type'?: string;
  '@integerValue'?: string;
  '@dateValue'?: string;
}

/**
 * Represents the output structure for a attribute.
 */
interface AttributeOutput {
  type: string | null;
  value: string | null;
  integer_value: number | null;
  date_value: Date | null;
}

/**
 * Builds a AttributeOutput object based on the provided AttributeInput.
 * @param item - The AttributeInput object.
 * @returns The corresponding AttributeOutput object.
 */
function buildAttributeOutput(item: AttributeInput): AttributeOutput {
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
function parseAttribute(json: string): AttributeOutput {
  let data: AttributeInput;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  return buildAttributeOutput(data);
}

// -- AttributeSet interfaces and functions --

// "AttrCitXRefCmnt": [{
//   "Attribute":
//   {
//     "$": "ACMG Guidelines, 2015",
//     "@Type": "AssertionMethod"
//   },
//   "Citation": [{
//     "ID": {
//       "$": "25741868"
//     }
//   }],
//   "XRef": [{
//     "@DB": "PubMed",
//     "@ID": "25741868",
//     "@Type": "PMID"
//   }],
//   "Comment": [{
//     "$": "This is a comment."
//   }]
// }]

/**
 * Represents the input structure for an attribute set.
 */
interface AttributeSetInput {
  Attribute?: AttributeInput;
  Citation?: CitationInput[];
  XRef?: XRefInput[];
  Comment?: CommentInput[];
}

/**
 * Represents the output structure for an attribute set.
 */
interface AttributeSetOutput {
  attribute: AttributeOutput | null;
  citation: Array<CitationOutput> | null;
  xref: Array<XRefOutput> | null;
  comment: Array<CommentOutput> | null;
}

/**
 * Builds a AttributeSetOutput object based on the provided AttributeSetInput.
 * @param item - The AttributeSetInput object.
 * @returns The corresponding AttributeSetOutput object.
 */
function buildAttributeSetOutput(item: AttributeSetInput): AttributeSetOutput {
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
function buildAttributeSetsOutput(items: AttributeSetInput | AttributeSetInput[]): AttributeSetOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): AttributeSetOutput => ({
    ...buildAttributeSetOutput(item)
  }));
}

interface AttributeSetData {
  AttributeSet?: AttributeSetInput | AttributeSetInput[];
} 

/**
 * Parses the JSON input and returns an array of AttrCitXRefCmntOutput objects.
 * @param json - The JSON input string.
 * @returns An array of AttrCitXRefCmntOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseAttributeSet(json: string): AttributeSetOutput[] {
  let data: AttributeSetData; // Declare the variable 'data'
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let attributeSets = data && data.AttributeSet ? data.AttributeSet : [];

  return buildAttributeSetsOutput(attributeSets);
} 

/* 
 * Below are the HGVS structure parsers that parse out HGVS lists
 * from the clinvar variation and clinical_assertion_variation 
 * content fields 
 */

// -- Nucleotide Expression interfaces and functions --

// {
//   "Expression" : {"$":"NM_000059.3:c.1234A>G"},
//   "@sequenceType" : "DNA",
//   "@sequenceAccessionVersion" : "NM_000059.3",
//   "@sequenceAccession" : "NM_000059",
//   "@sequenceVersion" : "3",
//   "@change" : "1234A>G",
//   "@Assembly" : "GRCh38",
//   "@Submitted" : "2019-12-01",
//   "@MANESelect" : false,
//   "@MANEPlusClinical" : false
// }

/**
 * Represents the input structure for a nucleotide expression.
 */
interface NucleotideExpressionInput {
  Expression?: {
    $: string;
  };
  '@sequenceType'?: string;
  '@sequenceAccessionVersion'?: string;
  '@sequenceAccession'?: string;
  '@sequenceVersion'?: string;
  '@change'?: string;
  '@Assembly'?: string;
  '@Submitted'?: string;
  '@MANESelect'?: string;
  '@MANEPlusClinical'?: string;
}

/**
 * Represents the output structure for a nucleotide.
 */
interface NucleotideExpressionOutput {
  expression: string | null;
  sequence_type: string | null;
  sequence_accession_version: string | null;
  sequence_accession: string | null;
  sequence_version: string | null;
  change: string | null;
  assembly: string | null;
  submitted: string | null;
  mane_select: boolean | null;
  mane_plus_clinical: boolean | null;
}

interface NucleotideExpressionData {
  NucleotideExpression?: NucleotideExpressionInput;
}

/**
 * Builds a NucleotideExpressionOutput object based on the provided NucleotideExpressionInput.
 * @param item - The NucleotideExpressionInput object.
 * @returns The corresponding NucleotideExpressionOutput object.
 */
function buildNucleotideExpressionOutput(item: NucleotideExpressionInput): NucleotideExpressionOutput {
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
function parseNucleotideExpression(json: string): NucleotideExpressionOutput {
  let data: NucleotideExpressionData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let nucleotideExpression = data && data.NucleotideExpression ? data.NucleotideExpression : {};

  return buildNucleotideExpressionOutput(nucleotideExpression);
}

// -- Protein Expressioninterfaces and functions --

// {
//   "Expression" : {"$":"NM_000059.3:c.1234A>G"},
//   "@sequenceAccessionVersion" : "NM_000059.3",
//   "@sequenceAccession" : "NM_000059",
//   "@sequenceVersion" : "3",
//   "@change" : "1234A>G"
// }

/**
 * Represents the input structure for a protein expression.
 */
interface ProteinExpressionInput {
  Expression?: {
    $: string;
  };
  '@sequenceAccessionVersion'?: string;
  '@sequenceAccession'?: string;
  '@sequenceVersion'?: string;
  '@change'?: string;
}

/**
 * Represents the output structure for a protein expression.
 */
interface ProteinExpressionOutput {
  expression: string | null;
  sequence_accession_version: string | null;
  sequence_accession: string | null;
  sequence_version: string | null;
  change: string | null;
}

interface ProteinExpressionData {
  ProteinExpression?: ProteinExpressionInput;
}

/**
 * Builds a ProteinExpressionOutput object based on the provided ProteinExpressionInput.
 * @param item - The ProteinExpressionInput object.
 * @returns The corresponding ProteinExpressionOutput object.
 */ 
function buildProteinExpressionOutput(item: ProteinExpressionInput): ProteinExpressionOutput {
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
function parseProteinExpression(json: string): ProteinExpressionOutput {
  let data: ProteinExpressionData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let proteinExpression = data && data.ProteinExpression ? data.ProteinExpression : {};

  return buildProteinExpressionOutput(proteinExpression);
}

// -- HGVS interfaces and functions --

// "HGVS": [{
//   "NucleotideExpression" : NucleotideOutput,
//   "ProteinExpression" : ProteinOutput,
//   "MolecularConsequence" : [XRefOutput],
//   "@Type" : "coding",
//   "@Assembly": "GRCh38"
// }]

/**
 * Represents the input structure for an HGVS item.
 */
interface HGVSInput {
  NucleotideExpression?: NucleotideExpressionInput;
  ProteinExpression?: ProteinExpressionInput;
  MolecularConsequence?: XRefInput[];
  '@Type'?: string;
  '@Assembly'?: string;
}

/**
 * Represents the output structure for an HGVS item.
 */
interface HGVSOutput {
  nucleotide_expression: NucleotideExpressionOutput | null;
  protein_expression: ProteinExpressionOutput | null;
  molecular_consequence: Array<XRefOutput> | null;
  type: string | null;
  assembly: string | null;
}

interface HGVSData {
  HGVS?: XRefInput | XRefInput[];
}

/**
 * Builds an HGVSOutput object based on the provided HGVSInput.
 * @param item - The HGVSInput object.
 * @returns The corresponding HGVSOutput object.
 */
function buildHGVSOutput(item: HGVSInput): HGVSOutput {
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
function buildHGVSArrayOutput(items: HGVSInput | HGVSInput[]): HGVSOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): HGVSOutput => ({
    ...buildHGVSOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an HGVSOutput array.
 * @param json - The JSON input string.
 * @returns An array of HGVSOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseHGVS(json: string): HGVSOutput[] {
  let data: HGVSData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let hgvs = data && data.HGVS ? data.HGVS : [];

  return buildHGVSArrayOutput(hgvs);
}
  
// -- Sequence Location interfaces and functions --

// below is an example of a JSON object that represents a sequence location object
// "SequenceLocation": [{
//   "@forDisplay": true,
//   "@Assembly": "GRCh38",
//   "@AssemblyAccessionVersion": "GCF_000001405.39",
//   "@AssemblyStatus": "latest",
//   "@Accession": "NC_012920.1",
//   "@Chr": "MT",
//   "@start": 12345,
//   "@stop": 12345,
//   "@innerStart": 12345,
//   "@innerStop": 12345,
//   "@outerStart": 12345,
//   "@outerStop": 12345,
//   "@variantLength": 1,
//   "@display_start": 12345,
//   "@display_stop": 12345,
//   "@positionVCF": 12345,
//   "@referenceAlleleVCF": "A",
//   "@alternateAlleleVCF": "G",
//   "@Strand": "+",
//   "@referenceAllele": "A",
//   "@alternateAllele": "G"
//   "@forDisplayLength": true
// }]

/**
 * Represents the input structure for a sequence location.
 */
interface SequenceLocationInput {
  '@forDisplay'?: boolean;
  '@Assembly'?: string;
  '@AssemblyAccessionVersion'?: string;
  '@AssemblyStatus'?: string;
  '@Accession'?: string;
  '@Chr'?: string;
  '@start'?: number;
  '@stop'?: number;
  '@innerStart'?: number;
  '@innerStop'?: number;
  '@outerStart'?: number;
  '@outerStop'?: number;
  '@variantLength'?: number;
  '@display_start'?: number;
  '@display_stop'?: number;
  '@positionVCF'?: number;
  '@referenceAlleleVCF'?: string;
  '@alternateAlleleVCF'?: string;
  '@Strand'?: string;
  '@referenceAllele'?: string;
  '@alternateAllele'?: string;
  '@forDisplayLength'?: boolean;
}

/**
 * Represents the output structure for a sequence location.
 */
interface SequenceLocationOutput {
  for_display: boolean | null;
  assembly: string | null;
  assembly_accession_version: string | null;
  assembly_status: string | null;
  accession: string | null;
  chr: string | null;
  start: number | null;
  stop: number | null;
  inner_start: number | null;
  inner_stop: number | null;
  outer_start: number | null;
  outer_stop: number | null;
  variant_length: number | null;
  display_start: number | null;
  display_stop: number | null;
  position_vcf: number | null;
  reference_allele_vcf: string | null;
  alternate_allele_vcf: string | null;
  strand: string | null;
  reference_allele: string | null;
  alternate_allele: string | null;
  for_display_length: boolean | null;
}

interface SequenceLocationData {
  SequenceLocation?: SequenceLocationInput | SequenceLocationInput[];
}

/**
 * Builds a SequenceLocationOutput object based on the provided SequenceLocationInput.
 * @param item - The SequenceLocationInput object.
 * @returns The corresponding SequenceLocationOutput object.
 */
function buildSequenceLocationOutput(item: SequenceLocationInput): SequenceLocationOutput {
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
function parseSequenceLocations(json: string): SequenceLocationOutput[] {
  let data: SequenceLocationData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let sequenceLocations = data && data.SequenceLocation ? data.SequenceLocation : [];

  if (!Array.isArray(sequenceLocations)) {
    sequenceLocations = [sequenceLocations];
  }

  return sequenceLocations.map((item): SequenceLocationOutput => ({
    ...buildSequenceLocationOutput(item),
  }));
}

// -- Software interfaces and functions --

//   "Software": [{
//     "@name": "GenomeStudio",
//     "@version": "2.0",
//     "@purpose": "genotyping"
//   }]

/**
 * Represents the input structure for a software.
 */
interface SoftwareInput {
  '@name'?: string;
  '@version'?: string;
  '@purpose'?: string;
}

/**
 * Represents the output structure for a software.
 */
interface SoftwareOutput {
  name: string | null;
  version: string | null;
  purpose: string | null;
}

interface SoftwareData {
  Software?: SoftwareInput | SoftwareInput[];
}

/**
 * Builds a SoftwareOutput object based on the provided SoftwareInput.
 * @param item - The SoftwareInput object.
 * @returns The corresponding SoftwareOutput object.
 */
function buildSoftwareOutput(item: SoftwareInput): SoftwareOutput {
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
function buildSoftwaresOutput(items: SoftwareInput | SoftwareInput[]): SoftwareOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): SoftwareOutput => ({
    ...buildSoftwareOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an array of SoftwareOutput objects.
 * @param json - The JSON input string.
 * @returns An array of SoftwareOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseSoftware(json: string): SoftwareOutput[] {
  let data: SoftwareData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let software = data && data.Software ? data.Software : [];

  return buildSoftwaresOutput(software);
}

// -- MethodAttribute interfaces and functions --

// "MethodAttribute": [
//   {
//     "Attribute": {
//       "$": "Oligo array",
//       "@Type": "TestName"
//     }
//   }
// ]

/**
 * Represents the input structure for a method attribute.
 */
interface MethodAttributeInput {
  Attribute?: AttributeInput;
}

/**
 * Represents the output structure for a method attribute.
 */
interface MethodAttributeOutput {
  attribute: AttributeOutput | null;
}

interface MethodAttributeData {
  MethodAttribute?: MethodAttributeInput | MethodAttributeInput[];
}

/**
 * Builds a MethodAttributeOutput object based on the provided MethodAttributeInput.
 * @param item - The MethodAttributeInput object.
 * @returns The corresponding MethodAttributeOutput object.
 */
function buildMethodAttributeOutput(item: MethodAttributeInput): MethodAttributeOutput {
  return {
    attribute: item.Attribute ? buildAttributeOutput(item.Attribute) : null
  };
}

function buildMethodAttributesOutput(items: MethodAttributeInput | MethodAttributeInput[]): MethodAttributeOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): MethodAttributeOutput => ({
    ...buildMethodAttributeOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an array of MethodAttributeOutput objects.
 * @param json - The JSON input string.
 * @returns An array of MethodAttributeOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseMethodAttributes(json: string): MethodAttributeOutput[] {
  let data: MethodAttributeData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let methodAttributes = data && data.MethodAttribute ? data.MethodAttribute : [];

  return buildMethodAttributesOutput(methodAttributes);
}

// -- ObsMethodAttribute interfaces and functions --

// "ObsMethodAttribute": [
//   {
//     "Attribute": {
//       "$": "Biosoluciones UDD",
//       "@Type": "TestingLaboratory"
//     },
//     "Comment": {
//       "$": "Likely pathogenic"
//     }
//   }
// ]

/**
 * Represents the input structure for a observed method attribute.
 */
interface ObsMethodAttributeInput {
  Attribute?: AttributeInput;
  Comment?: CommentInput;
}

/**
 * Represents the output structure for a observed method attribute.
 */
interface ObsMethodAttributeOutput {
  attribute: AttributeOutput | null;
  comment: CommentOutput | null;
}

interface ObsMethodAttributeData {
  ObsMethodAttribute?: ObsMethodAttributeInput | ObsMethodAttributeInput[];
}

/**
 * Builds a ObsMethodAttributeOutput object based on the provided ObsMethodAttributeInput.
 * @param item - The ObsMethodAttributeInput object.
 * @returns The corresponding ObsMethodAttributeOutput object.
 */
function buildObsMethodAttributeOutput(item: ObsMethodAttributeInput): ObsMethodAttributeOutput {
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
function buildObsMethodAttributesOutput(items: ObsMethodAttributeInput | ObsMethodAttributeInput[]): ObsMethodAttributeOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): ObsMethodAttributeOutput => ({
    ...buildObsMethodAttributeOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an array of ObsMethodAttributeOutput objects.
 * @param json - The JSON input string.
 * @returns An array of ObsMethodAttributeOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseObsMethodAttributes(json: string): ObsMethodAttributeOutput[] {
  let data: ObsMethodAttributeData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let obsMethodAttributes = data && data.ObsMethodAttribute ? data.ObsMethodAttribute : [];

  return buildObsMethodAttributesOutput(obsMethodAttributes);
}

// -- Method interfaces and functions --

// below is an example of a JSON object that represents a method object
// "Method": [{
//   "NamePlatform": {
//     "$": "Affymetrix CytoScan HD"
//   },
//   "TypePlatform": {
//     "$": "Microarray"
//   },
//   "Purpose": {
//     "$": "Diagnosis"
//   },
//   "ResultType": {
//     "$": "odds ratio"
//   },
//   "MinReported": {
//     "$": "1"
//   },
//   "MaxReported": {
//     "$": "1"
//   },
//   "ReferenceStandard": {
//     "$": "ACMG Guidelines, 2015"
//   },
//   "Description": {
//     "$": "This is a description."
//   },
//   "SourceType": {
//     "$": "literature only"
//   },
//   "MethodType": {
//     "$": "clinical testing"
//   },
//   "Citation": [{
//     "ID": {
//       "$": "25741868",
//       "@Source": "PubMed"
//     },
//     "URL": {
//       "$": "https://pubmed.ncbi.nlm.nih.gov/25741868"
//     },
//     "CitationText": {
//       "$": "This is a citation."
//     },
//     "@Type": "PMID",
//     "@Abbrev": "PubMed"
    
//   }],
//   "XRef": [{
//     "@DB": "OMIM",
//     "@ID": "123456",
//     "@Type": "MIM number",
//     "@URL": "https://omim.org/entry/123456",
//     "@Status": "current"    
//   }],
//   "Software": [{
//     "@name": "GenomeStudio",
//     "@version": "2.0",
//     "@purpose": "genotyping"
//   }],
//   "MethodAttribute": [{
//     "Attribute": {
//       "$": "Oligo array",
//       "@Type": "TestName"
//     }
//   }],
//   "ObsMethodAttribute": [{
//     "Attribute": {
//       "$": "Biosoluciones UDD",
//       "@Type": "TestingLaboratory"
//     },
//     "Comment": {
//       "$": "Likely pathogenic"
//     }
//   }]
// }]

/**
 * Represents the input structure for a method.
 */
interface MethodInput {
  NamePlatform?: {
    $?: string;
  };
  TypePlatform?: {
    $?: string;
  };
  Purpose?: {
    $?: string;
  };
  ResultType?: {
    $?: string;
  };
  MinReported?: {
    $?: string;
  };
  MaxReported?: {
    $?: string;
  };
  ReferenceStandard?: {
    $?: string;
  };
  Description?: {
    $?: string;
  };
  SourceType?: {
    $?: string;
  };
  MethodType?: {
    $?: string;
  };
  Citation?: CitationInput[];
  XRef?: XRefInput[];
  Software?: SoftwareInput[];
  MethodAttribute?: MethodAttributeInput[];
  ObsMethodAttribute?: ObsMethodAttributeInput[]; 
}

/**
 * Represents the output structure for a method.
 */
interface MethodOutput {
  name_platform: string | null;
  type_platform: string | null;
  purpose: string | null;
  result_type: string | null;
  min_reported: number | null;
  max_reported: number | null;
  reference_standard: string | null;
  description: string | null;
  source_type: string | null;
  method_type: string | null;
  citation: Array<CitationOutput> | null;
  xref: Array<XRefOutput> | null;
  software: Array<SoftwareOutput> | null;
  method_attribute: Array<MethodAttributeOutput> | null;
  obs_method_attribute: Array<ObsMethodAttributeOutput> | null;
}

interface MethodData {
  Method?: MethodInput | MethodInput[];
}

/**
 * Builds a MethodOutput object based on the provided MethodInput.
 * @param item - The MethodInput object.
 * @returns The corresponding MethodOutput object.
 */
function buildMethodOutput(item: MethodInput): MethodOutput {
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

function buildMethodsOutput(items: MethodInput | MethodInput[]): MethodOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): MethodOutput => ({
    ...buildMethodOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an array of MethodOutput objects.
 * @param json - The JSON input string.
 * @returns An array of MethodOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseMethods(json: string): MethodOutput[] {
  let data: MethodData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let methods = data && data.Method ? data.Method : [];

  return buildMethodsOutput(methods);
}

// -- ObservedData interfaces and functions --

// {
//   "ObservedData": [
//     "Attribute": {
//       "@Type": "VariantAlleles",
//       "@integerValue": "2"
//     },
//     "Severity": "mild",
//     "Citation": [{
//       "ID": {
//         "$": "25741868"
//       }
//     }],
//     "XRef": [{
//       "@DB": "PubMed",
//       "@ID": "25741868",
//       "@Type": "PMID"
//     }],
//     "Comment": [{
//       "$": "This is a comment."
//     }]
//   ]
// }

/**
 * Represents the input structure for a observed data.
 */ 
interface ObservedDataInput {
  Attribute?: AttributeInput;
  Severity?: string;
  Citation?: CitationInput[];
  XRef?: XRefInput[];
  Comment?: CommentInput[];
}

/**
 * Represents the output structure for a observed data.
 */
interface ObservedDataOutput {
  attribute: AttributeOutput | null;
  severity: string | null;
  citation: Array<CitationOutput> | null;
  xref: Array<XRefOutput> | null;
  comment: Array<CommentOutput> | null;
}

interface ObservedDataData {
  ObservedData?: ObservedDataInput | ObservedDataInput[];
}

/**
 * Builds a ObservedDataOutput object based on the provided ObservedDataInput.
 * @param item - The ObservedDataInput object.
 * @returns The corresponding ObservedDataOutput object.
 */
function buildObservedDataOutput(item: ObservedDataInput): ObservedDataOutput {
  return {
    attribute: item.Attribute ? buildAttributeOutput(item.Attribute) : null,
    severity: item.Severity ? item.Severity : null,
    citation: item.Citation ? buildCitationsOutput(item.Citation) : null,
    xref: item.XRef ? buildXRefsOutput(item.XRef) : null,
    comment: item.Comment ? buildCommentsOutput(item.Comment) : null
  };
}

function buildObservedDatasOutput(items: ObservedDataInput | ObservedDataInput[]): ObservedDataOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): ObservedDataOutput => ({
    ...buildObservedDataOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an array of ObservedDataOutput objects.
 * @param json - The JSON input string.
 * @returns An array of ObservedDataOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseObservedData(json: string): ObservedDataOutput[] {
  let data: ObservedDataData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let observedData = data && data.ObservedData ? data.ObservedData : [];

  return buildObservedDatasOutput(observedData);
}


// -- SetElementSet interfaces and functions --

// {
//   [{
//     "ElementValue": {
//       "$": "value",
//       "@Type": "type"
//     },
//     "Citation": [{
//       "ID": {
//         "$": "25741868"
//       }
//     }],
//     "XRef": [{
//       "@DB": "PubMed",
//       "@ID": "25741868",
//       "@Type": "PMID"
//     }], 
//     "Comment": [{
//       "$": "This is a comment."
//     }]  
//   }]
// }

/**
 * Represents the input structure for a set element.
 */
interface SetElementInput {
  ElementValue?: {
    $?: string;
    '@Type'?: string;
  };
  Citation?: CitationInput[];
  XRef?: XRefInput[];
  Comment?: CommentInput[];
}

/**
 * Represents the output structure for a set element.
 */
interface SetElementOutput {
  element_value: string | null;
  type: string | null;
  citation: Array<CitationOutput> | null;
  xref: Array<XRefOutput> | null;
  comment: Array<CommentOutput> | null;
}

interface SetElementData {
  SetElement?: SetElementInput | SetElementInput[];
} 

/**
 * Builds a SetElementOutput object based on the provided SetElementInput.
 * @param item - The SetElementInput object.
 * @returns The corresponding SetElementOutput object.
 */
function buildSetElementOutput(item: SetElementInput): SetElementOutput {
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
function buildSetElementsOutput(items: SetElementInput | SetElementInput[]): SetElementOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): SetElementOutput => ({
    ...buildSetElementOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an array of SetElementOutput objects.
 * @param json - The JSON input string.
 * @returns An array of SetElementOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */ 
function parseSetElement(json: string): SetElementOutput[] {
  let data: SetElementData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let setElements = data && data.SetElement ? data.SetElement : [];

  return buildSetElementsOutput(setElements);
}


// -- FamilyInfo interfaces and functions --

// {
//   "FamilyInfo": {
//     "FamilyHistory": "The type that is available",
//     "@NumFamilies": "1",
//     "@NumFamiliesWithVariant": "1",
//     "@NumFamiliesWithSegregationObserved": "1",
//     "@PedigreeID": "70e10a1a-f6fa-4abc-baf5-a6635f27c6ea",
//     "@SegregationObserved": "yes"
//   }
// }

/**
 * Represents the input structure for a family info.
 */
interface FamilyInfoInput {
  FamilyHistory?: string;
  '@NumFamilies'?: string;
  '@NumFamiliesWithVariant'?: string;
  '@NumFamiliesWithSegregationObserved'?: string;
  '@PedigreeID'?: string;
  '@SegregationObserved'?: string;
}

/**
 * Represents the output structure for a family info.
 */
interface FamilyInfoOutput {
  family_history: string | null;
  num_families: number | null;
  num_families_with_variant: number | null;
  num_families_with_segregation_observed: number | null;
  pedigree_id: string | null;
  segregation_observed: string | null;
}

interface FamilyInfoData {
  FamilyInfo?: FamilyInfoInput;
}

/**
 * Builds a FamilyInfoOutput object based on the provided FamilyInfoInput.
 * @param item - The FamilyInfoInput object.
 * @returns The corresponding FamilyInfoOutput object.
 */
function buildFamilyInfoOutput(item: FamilyInfoInput): FamilyInfoOutput {
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
function parseFamilyInfo(json: string): FamilyInfoOutput {
  let data: FamilyInfoData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let familyInfo = data && data.FamilyInfo ? data.FamilyInfo : {};

  return buildFamilyInfoOutput(familyInfo);
}


// -- TraitRelationship interfaces and functions --

// {
//   "TraitRelationship": [
//   {
//     "Name": [{
//       "ElementValue": {
//         "$": "value",
//         "@Type": "type"
//       },
//       "Citation": [{
//         "ID": {
//           "$": "25741868"
//         }
//       }],
//       "XRef": [{
//         "@DB": "PubMed",
//         "@ID": "25741868",
//         "@Type": "PMID"
//       }], 
//       "Comment": [{
//         "$": "This is a comment."
//       }]  
//     }],
//     "Symbol": [{
//       "ElementValue": {
//         "$": "value",
//         "@Type": "type"
//       },
//       "Citation": [{
//         "ID": {
//           "$": "25741868"
//         }
//       }],
//       "XRef": [{
//         "@DB": "PubMed",
//         "@ID": "25741868",
//         "@Type": "PMID"
//       }], 
//       "Comment": [{
//         "$": "This is a comment."
//       }]  
//     }],
//     "AttributeSet": [{
//       "Attribute": {
//         "$": "ACMG Guidelines, 2015",
//         "@Type": "AssertionMethod"
//       },
//       "Citation": [{
//         "ID": {
//           "$": "25741868"
//         }
//       }],
//       "XRef": [{
//         "@DB": "PubMed",
//         "@ID": "25741868",
//         "@Type": "PMID"
//       }],
//       "Comment": [{
//         "$": "This is a comment."
//       }]
//     }],
//     "Citation": [{
//       "ID": {
//         "$": "25741868"
//       }
//     }],
//     "XRef": [{
//       "@DB": "PubMed",
//       "@ID": "25741868",
//       "@Type": "PMID"
//     }],
//     "Source": ["value"],
//     "@Type": "phenocopy"
//   }
//   ]
// }

/**
 * Represents the input structure for a trait relationship.
 */
interface TraitRelationshipInput {
  Name?: SetElementInput[];
  Symbol?: SetElementInput[];
  AttributeSet?: AttributeSetInput[];
  Citation?: CitationInput[];
  XRef?: XRefInput[];
  Source?: string[];
  '@Type'?: string;
}

/**
 * Represents the output structure for a trait relationship.
 */
interface TraitRelationshipOutput {
  name: Array<SetElementOutput> | null;
  symbol: Array<SetElementOutput> | null;
  attribute_set: Array<AttributeSetOutput> | null;
  citation: Array<CitationOutput> | null;
  xref: Array<XRefOutput> | null;
  source: string[] | null;
  type: string | null;
}

interface TraitRelationshipData {
  TraitRelationship?: TraitRelationshipInput | TraitRelationshipInput[];
}

/**
 * Builds a TraitRelationshipOutput object based on the provided TraitRelationshipInput.
 * @param item - The TraitRelationshipInput object.
 * @returns The corresponding TraitRelationshipOutput object.
 */
function buildTraitRelationshipOutput(item: TraitRelationshipInput): TraitRelationshipOutput {
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
function buildTraitRelationshipsOutput(items: TraitRelationshipInput | TraitRelationshipInput[]): TraitRelationshipOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): TraitRelationshipOutput => ({
    ...buildTraitRelationshipOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an array of TraitRelationshipOutput objects.
 * @param json - The JSON input string.
 * @returns An array of TraitRelationshipOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */ 
function parseTraitRelationships(json: string): TraitRelationshipOutput[] {
  let data: TraitRelationshipData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let traitRelationships = data && data.TraitRelationship ? data.TraitRelationship : [];

  return buildTraitRelationshipsOutput(traitRelationships);
}



// -- ClinicalAsserTrait interfaces and functions --

// {
//   "Name": [{
//     "ElementValue": {
//       "$": "value",
//       "@Type": "type"
//     },
//     "Citation": [{
//       "ID": {
//         "$": "25741868"
//       }
//     }],
//     "XRef": [{
//       "@DB": "PubMed",
//       "@ID": "25741868",
//       "@Type": "PMID"
//     }], 
//     "Comment": [{
//       "$": "This is a comment."
//     }]  
//   }],
//   "Symbol": [{
//     "ElementValue": {
//       "$": "value",
//       "@Type": "type"
//     },
//     "Citation": [{
//       "ID": {
//         "$": "25741868"
//       }
//     }],
//     "XRef": [{
//       "@DB": "PubMed",
//       "@ID": "25741868",
//       "@Type": "PMID"
//     }], 
//     "Comment": [{
//       "$": "This is a comment."
//     }]  
//   }],
//   "AttributeSet": [{
//     "Attribute": {
//       "$": "ACMG Guidelines, 2015",
//       "@Type": "AssertionMethod"
//     },
//     "Citation": [{
//       "ID": {
//         "$": "25741868"
//       }
//     }],
//     "XRef": [{
//       "@DB": "PubMed",
//       "@ID": "25741868",
//       "@Type": "PMID"
//     }],
//     "Comment": [{
//       "$": "This is a comment."
//     }]
//   }],
//   "TraitRelationship": [
//   {
//     "Name": [{
//       "ElementValue": {
//         "$": "value",
//         "@Type": "type"
//       },
//       "Citation": [{
//         "ID": {
//           "$": "25741868"
//         }
//       }],
//       "XRef": [{
//         "@DB": "PubMed",
//         "@ID": "25741868",
//         "@Type": "PMID"
//       }], 
//       "Comment": [{
//         "$": "This is a comment."
//       }]  
//     }],
//     "Symbol": [{
//       "ElementValue": {
//         "$": "value",
//         "@Type": "type"
//       },
//       "Citation": [{
//         "ID": {
//           "$": "25741868"
//         }
//       }],
//       "XRef": [{
//         "@DB": "PubMed",
//         "@ID": "25741868",
//         "@Type": "PMID"
//       }], 
//       "Comment": [{
//         "$": "This is a comment."
//       }]  
//     }],
//     "AttributeSet": [{
//       "Attribute": {
//         "$": "ACMG Guidelines, 2015",
//         "@Type": "AssertionMethod"
//       },
//       "Citation": [{
//         "ID": {
//           "$": "25741868"
//         }
//       }],
//       "XRef": [{
//         "@DB": "PubMed",
//         "@ID": "25741868",
//         "@Type": "PMID"
//       }],
//       "Comment": [{
//         "$": "This is a comment."
//       }]
//     }],
//     "Citation": [{
//       "ID": {
//         "$": "25741868"
//       }
//     }],
//     "XRef": [{
//       "@DB": "PubMed",
//       "@ID": "25741868",
//       "@Type": "PMID"
//     }],
//     "Source": ["value"],
//     "@Type": "phenocopy"
//   }
//   ],
//   "Citation": [{
//     "ID": {
//       "$": "25741868"
//     }
//   }],
//   "XRef": [{
//     "@DB": "PubMed",
//     "@ID": "25741868",
//     "@Type": "PMID"
//   }], 
//   "Comment": [{
//     "$": "This is a comment."
//   }],
//   "Source": ["value"],
//   "@Type" : "Disease",
//   "@ClinicalFeaturesAffectedStatus": "present",
//   "@ID" : 1
// }

/**
 * Represents the input structure for a clinical assertion trait.
 */
interface ClinicalAsserTraitInput {
  Name?: SetElementInput[];
  Symbol?: SetElementInput[];
  AttributeSet?: AttributeSetInput[];
  TraitRelationship?: TraitRelationshipInput[];
  Citation?: CitationInput[];
  XRef?: XRefInput[];
  Comment?: CommentInput[];
  '@Type'?: string;
  '@ClinicalFeaturesAffectedStatus'?: string;
  '@ID'?: string;
}

/**
 * Represents the output structure for a clinical assertion trait.
 */
interface ClinicalAsserTraitOutput {
  name: Array<SetElementOutput> | null;
  symbol: Array<SetElementOutput> | null;
  attribute_set: Array<AttributeSetOutput> | null;
  trait_relationship: Array<TraitRelationshipOutput> | null;
  citation: Array<CitationOutput> | null;
  xref: Array<XRefOutput> | null;
  comment: Array<CommentOutput> | null;
  type: string | null;
  clinical_features_affected_status: string | null;
  id: string | null;
}

interface ClinicalAsserTraitData {
  Trait?: ClinicalAsserTraitInput | ClinicalAsserTraitInput[];
}

/**
 * Builds a ClinicalAsserTraitOutput object based on the provided ClinicalAsserTraitInput.
 * @param item - The ClinicalAsserTraitInput object.
 * @returns The corresponding ClinicalAsserTraitOutput object.
 */
function buildClinicalAsserTraitOutput(item: ClinicalAsserTraitInput): ClinicalAsserTraitOutput {
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
function buildClinicalAsserTraitsOutput(items: ClinicalAsserTraitInput | ClinicalAsserTraitInput[]): ClinicalAsserTraitOutput[] { 
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): ClinicalAsserTraitOutput => ({
    ...buildClinicalAsserTraitOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an array of ClinicalAsserTraitOutput objects.
 * @param json - The JSON input string.
 * @returns An array of ClinicalAsserTraitOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseClinicalAsserTraits(json: string): ClinicalAsserTraitOutput[] {
  let data: ClinicalAsserTraitData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let clinicalAsserTraits = data && data.Trait ? data.Trait : [];

  return buildClinicalAsserTraitsOutput(clinicalAsserTraits);
}


// -- Indication interfaces and functions --
// {
//   "Trait" : [ClinicalAsserTraitType],
//   "Name": [{
//     "ElementValue": {
//       "$": "value",
//       "@Type": "type"
//     },
//     "Citation": [{
//       "ID": {
//         "$": "25741868"
//       }
//     }],
//     "XRef": [{
//       "@DB": "PubMed",
//       "@ID": "25741868",
//       "@Type": "PMID"
//     }], 
//     "Comment": [{
//       "$": "This is a comment."
//     }]  
//   }],
//   "Symbol": [{
//     "ElementValue": {
//       "$": "value",
//       "@Type": "type"
//     },
//     "Citation": [{
//       "ID": {
//         "$": "25741868"
//       }
//     }],
//     "XRef": [{
//       "@DB": "PubMed",
//       "@ID": "25741868",
//       "@Type": "PMID"
//     }], 
//     "Comment": [{
//       "$": "This is a comment."
//     }]  
//   }],
//   "AttributeSet": {
//     "Attribute": {
//       "$": "ACMG Guidelines, 2015",
//       "@Type": "AssertionMethod"
//     },
//     "Citation": [{
//       "ID": {
//         "$": "25741868"
//       }
//     }],
//     "XRef": [{
//       "@DB": "PubMed",
//       "@ID": "25741868",
//       "@Type": "PMID"
//     }],
//     "Comment": [{
//       "$": "This is a comment."
//     }]
//   }],
//   "Citation": [{
//     "ID": {
//       "$": "25741868"
//     }
//   }],
//   "XRef": [{
//     "@DB": "PubMed",
//     "@ID": "25741868",
//     "@Type": "PMID"
//   }],
//   "Comment": {
//     "$": "This is a comment."
//   }
//   "@Type" : "Indication",
//   "@ID" : 1
// }

/**
 * Represents the input structure for an indication.
 */
interface IndicationInput {
  Trait?: ClinicalAsserTraitInput[];
  Name?: SetElementInput[];
  Symbol?: SetElementInput[];
  AttributeSet?: AttributeSetInput;
  Citation?: CitationInput[];
  XRef?: XRefInput[];
  Comment?: CommentInput;
  '@Type'?: string;
  '@ID'?: string;
}

/**
 * Represents the output structure for an indication.
 */
interface IndicationOutput {
  trait: Array<ClinicalAsserTraitOutput> | null;
  name: Array<SetElementOutput> | null;
  symbol: Array<SetElementOutput> | null;
  attribute_set: AttributeSetOutput | null;
  citation: Array<CitationOutput> | null;
  xref: Array<XRefOutput> | null;
  comment: CommentOutput | null;
  type: string | null;
  id: string | null;
}

interface IndicationData {
  Indication?: IndicationInput | IndicationInput[];
}

/**
 * Builds an IndicationOutput object based on the provided IndicationInput.
 * @param item - The IndicationInput object.
 * @returns The corresponding IndicationOutput object.
 */
function buildIndicationOutput(item: IndicationInput): IndicationOutput {
  return {
    trait: item.Trait ? buildClinicalAsserTraitsOutput(item.Trait) : null,
    name: item.Name ? buildSetElementsOutput(item.Name) : null,
    symbol: item.Symbol ? buildSetElementsOutput(item.Symbol) : null,
    attribute_set: item.AttributeSet ? buildAttributeSetOutput(item.AttributeSet) : null,
    citation: item.Citation ? buildCitationsOutput(item.Citation) : null,
    xref: item.XRef ? buildXRefsOutput(item.XRef) : null,
    comment: item.Comment ? buildCommentOutput(item.Comment ) : null,
    type: item['@Type'] ? item['@Type'] : null,
    id: item['@ID'] ? item['@ID'] : null
  };
}

/**
 * Builds an array of IndicationOutput objects based on the provided IndicationInput.
 * @param items - The IndicationInput object or an array of IndicationInput objects.
 * @returns An array of IndicationOutput objects.
 */
function buildIndicationsOutput(items: IndicationInput | IndicationInput[]): IndicationOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): IndicationOutput => ({
    ...buildIndicationOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an array of IndicationOutput objects.
 * @param json - The JSON input string.
 * @returns An array of IndicationOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseIndications(json: string): IndicationOutput[] {
  let data: IndicationData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let indications = data && data.Indication ? data.Indication : [];

  return buildIndicationsOutput(indications);
}

// -- Age interfaces and functions --

// {
//   "Age": [{
//     "$": "0",
//     "@Type": "minimum"
//     "@age_unit": "year"
//   },{
//     "$": "2",
//     "@Type": "maximum"
//     "@age_unit": "year"
//   }]
// }

/**
 * Represents the input structure for an age.
 */
interface AgeInput {
  $?: string;
  '@Type'?: string;
  '@age_unit'?: string;
}

/**
 * Represents the output structure for an age.
 */
interface AgeOutput {
  value: number | null;
  type: string | null;
  age_unit: string | null;
}

interface AgeData {
  Age?: AgeInput | AgeInput[];
}

/**
 * Builds an AgeOutput object based on the provided AgeInput.
 * @param item - The AgeInput object.
 * @returns The corresponding AgeOutput object.
 */
function buildAgeOutput(item: AgeInput): AgeOutput {
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
function buildAgeRangeOutput(items: AgeInput | AgeInput[]): AgeOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): AgeOutput => ({
    ...buildAgeOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an array of AgeOutput objects.
 * @param json - The JSON input string.
 * @returns An array of AgeOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseAges(json: string): AgeOutput[] {
  let data: AgeData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let ages = data && data.Age ? data.Age : [];

  return buildAgeRangeOutput(ages);
}

// -- Sample interfaces and functions --

// below is an example of a JSON object that represents a sample object
// {
//   "Sample": {
//     "SampleDescription": {
//       "Description": {
//         "$": "This is a sample description.",
//         "@Type": "General"
//       },
//       "Citation": {
//         "ID": {
//           "$": "32505691",
//           "@Source": "PubMed"
//         }
//       }
//     },
//     "Origin": {
//       "$": "germline"
//     },
//     "Ethnicity": {
//       "$": "Caucasian"
//     },
//     "GeographicOrigin": {
//       "$": "USA"
//     },
//     "Tissue": {
//       "$": "Blood"
//     },
//     "CellLine": {
//       "$": "GM12878"
//     },
//     "Species": {
//       "$": "human",
//       "@TaxonomyId": "9606"
//     },
//     "Age": [{
//       "$": "0",
//       "@Type": "minimum"
//       "@age_unit": "year"
//     },{
//       "$": "2",
//       "@Type": "maximum"
//       "@age_unit": "year"
//     }],
//     "Strain": {
//       "$": "C57BL/6"
//     },
//     "AffectedStatus": {
//       "$": "yes"
//     },
//     "NumberTested": {
//       "$": "1"
//     },
//     "NumberMales": {
//       "$": "1"
//     },
//     "NumberFemales": {
//       "$": "0"
//     },
//     "NumberChrTested": {
//       "$": "1"
//     },
//     "Gender": {
//       "$": "male"
//     },
//     "FamilyData": {
//       "FamilyHistory": "The type that is available",
//       "@NumFamilies": "1",
//       "@NumFamiliesWithVariant": "1",
//       "@NumFamiliesWithSegregationObserved": "1",
//       "@PedigreeID": "70e10a1a-f6fa-4abc-baf5-a6635f27c6ea",
//       "@SegregationObserved": "yes"
//     },
//     "Proband": {
//       "$": "yes"
//     },
//     "Indication": IndicationType,
//     "Citation": [{
//       "ID": {
//         "$": "32505691",
//         "@Source": "PubMed"
//       }
//     }],
//     "XRef": [{
//       "@DB": "PubMed",
//       "@ID": "32505691",
//       "@Type": "PMID"
//     }],
//     "Comment": [{
//       "$": "This is a comment."
//     }]  
//     "SourceType": {
//       "$": "submitter-generated"
//     }
//   }
//}

/**
 * Represents the input structure for a sample.
 */
interface SampleInput {
  SampleDescription?: {
    Description?: SetElementInput;
    Citation?: CitationInput;
  };
  Origin?: {
    $?: string;
  }; 
  Ethnicity?: {
    $?: string;
  };
  GeographicOrigin?: {
    $?: string;
  };
  Tissue?: {
    $?: string;
  };
  CellLine?: {
    $?: string;
  };
  Species?: {
    $?: string;
    '@TaxonomyId'?: string;
  };
  Age?: AgeInput[];
  Strain?: {
    $?: string;
  };
  AffectedStatus?: {
    $?: string;
  };
  NumberTested?: {
    $?: string;
  };
  NumberMales?: {
    $?: string;
  };
  NumberFemales?: {
    $?: string;
  };
  NumberChrTested?: {
    $?: string;
  };
  Gender?: {
    $?: string;
  };
  FamilyData?: FamilyInfoInput;
  Proband?: {
    $?: string;
  };
  Indication?: IndicationInput;
  Citation?: CitationInput[];
  XRef?: XRefInput[];
  Comment?: CommentInput[];
  SourceType?: {
    $?: string;
  };
}

/**
 * Represents the output structure for a sample.
 */
interface SampleOutput {
  sample_description: {
    description: SetElementOutput | null;
    citation: CitationOutput | null;
  };
  origin: string | null;
  ethnicity: string | null;
  geographic_origin: string | null;
  tissue: string | null;
  cell_line: string | null;
  species: string | null;
  taxonomy_id: string | null;
  age: Array<AgeOutput> | null;
  strain: string | null;
  affected_status: string | null;
  number_tested: number | null;
  number_males: number | null;
  number_females: number | null;
  number_chr_tested: number | null;
  gender: string | null;
  family_data: FamilyInfoOutput | null;
  proband: string | null;
  indication: IndicationOutput | null;
  citation: Array<CitationOutput> | null;
  xref: Array<XRefOutput> | null;
  comment: Array<CommentOutput> | null;
  source_type: string | null;
}

interface SampleData {
  Sample?: SampleInput;
}

/**
 * Builds a SampleOutput object based on the provided SampleInput.
 * @param item - The SampleInput object.
 * @returns The corresponding SampleOutput object.
 */
function buildSampleOutput(item: SampleInput): SampleOutput {
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
function parseSample(json: string): SampleOutput {
  let data: SampleData;
  try {
    data = JSON.parse(json);
  } catch (e) {
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
function deriveHGVS( variation_type: string, seqLoc: SequenceLocationOutput  ): string | null {
  let hgvs: string | null = null;

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
  const delDupTypes: string[] = ["Deletion", "copy number loss", "Duplication", "copy number gain"];
  if (!delDupTypes.includes(variation_type) ||
    (seqLoc.start != null && (seqLoc.inner_start != null || seqLoc.outer_start != null)) ||
    (seqLoc.stop != null && (seqLoc.inner_stop != null || seqLoc.outer_stop != null)) ||
    (seqLoc.start == null && seqLoc.inner_start == null && seqLoc.outer_start == null)) {
    return hgvs;
  }

  // process deletions and duplications only
  const delDupType: string = (delDupTypes.indexOf(variation_type) < 2 ? "del" : "dup");
  const rangeStart: string = `(${seqLoc.outer_start != null ? seqLoc.outer_start : "?"}_${seqLoc.inner_start != null ? seqLoc.inner_start : "?"})`;
  const rangeStop: string = `(${seqLoc.inner_stop != null ? seqLoc.inner_stop : "?"}_${seqLoc.outer_stop != null ? seqLoc.outer_stop : "?"})`;
  const finalStart: string = `${seqLoc.start != null ? seqLoc.start : rangeStart}`;
  const finalStop: string = `${seqLoc.stop != null ? seqLoc.stop : rangeStop}`;
  if (finalStart == finalStop) {
    hgvs = `${seqLoc.accession}:${seqLoc.accession == 'NC_012920.1' ? "m" : "g"}.${finalStart}${delDupType}`;
  } else {
    hgvs = `${seqLoc.accession}:${seqLoc.accession == 'NC_012920.1' ? "m" : "g"}.${finalStart}${finalStop != "" ? "_" + finalStop : finalStop}${delDupType}`;
  }

  return hgvs;
}


// -- Trait interfaces and functions --

// below is an example of a JSON object that represents a trait object
// {
//   "@ID": "5880",
//   "@Type": "Disease",
//   "Name": [
//     {
//       "ElementValue": {
//         "@Type": "Preferred",
//         "$": "Autosomal recessive Robinow syndrome"
//       },
//       "XRef": {
//         "@ID": "MONDO:0009999",
//         "@DB": "MONDO"
//       }
//     },
//     {
//       "ElementValue": {
//         "@Type": "Alternate",
//         "$": "COSTOVERTEBRAL SEGMENTATION DEFECT WITH MESOMELIA"
//       },
//       "XRef": {
//         "@Type": "MIM",
//         "@ID": "268310",
//         "@DB": "OMIM"
//       }
//     },
//     {
//       "ElementValue": {
//         "@Type": "Alternate",
//         "$": "COVESDEM SYNDROME"
//       },
//       "XRef": {
//         "@Type": "MIM",
//         "@ID": "268310",
//         "@DB": "OMIM"
//       }
//     },
//     {
//       "ElementValue": {
//         "@Type": "Alternate",
//         "$": "ROBINOW SYNDROME, AUTOSOMAL RECESSIVE 1"
//       },
//       "XRef": [
//         {
//           "@Type": "MIM",
//           "@ID": "268310",
//           "@DB": "OMIM"
//         },
//         {
//           "@Type": "Allelic variant",
//           "@ID": "602337.0010",
//           "@DB": "OMIM"
//         },
//         {
//           "@Type": "Allelic variant",
//           "@ID": "602337.0011",
//           "@DB": "OMIM"
//         },
//         {
//           "@Type": "Allelic variant",
//           "@ID": "602337.0012",
//           "@DB": "OMIM"
//         },
//         {
//           "@Type": "Allelic variant",
//           "@ID": "602337.0006",
//           "@DB": "OMIM"
//         },
//         {
//           "@Type": "Allelic variant",
//           "@ID": "602337.0004",
//           "@DB": "OMIM"
//         },
//         {
//           "@Type": "Allelic variant",
//           "@ID": "602337.0005",
//           "@DB": "OMIM"
//         },
//         {
//           "@Type": "Allelic variant",
//           "@ID": "602337.0007",
//           "@DB": "OMIM"
//         }
//       ]
//     }
//   ],
//   "Symbol": [
//     {
//       "ElementValue": {
//         "@Type": "Preferred",
//         "$": "RRS1"
//       },
//       "XRef": {
//         "@Type": "MIM",
//         "@ID": "268310",
//         "@DB": "OMIM"
//       }
//     },
//     {
//       "ElementValue": {
//         "@Type": "Alternate",
//         "$": "RRS"
//       }
//     }
//   ],
//   "AttributeSet": [
//     {
//       "Attribute": {
//         "@Type": "public definition",
//         "$": "ROR2-related Robinow syndrome is characterized by distinctive craniofacial features, skeletal abnormalities, and other anomalies. Craniofacial features include macrocephaly, broad prominent forehead, low-set ears, ocular hypertelorism, prominent eyes, midface hypoplasia, short upturned nose with depressed nasal bridge and flared nostrils, large and triangular mouth with exposed incisors and upper gums, gum hypertrophy, misaligned teeth, ankyloglossia, and micrognathia. Skeletal abnormalities include short stature, mesomelic or acromesomelic limb shortening, hemivertebrae with fusion of thoracic vertebrae, and brachydactyly. Other common features include micropenis with or without cryptorchidism in males and reduced clitoral size and hypoplasia of the labia majora in females, renal tract abnormalities, and nail hypoplasia or dystrophy. The disorder is recognizable at birth or in early childhood."
//       },
//       "XRef": {
//         "@ID": "NBK1240",
//         "@DB": "GeneReviews"
//       }
//     },
//     {
//       "Attribute": {
//         "@Type": "GARD id",
//         "@integerValue": "16568"
//       },
//       "XRef": {
//         "@ID": "16568",
//         "@DB": "Office of Rare Diseases"
//       }
//     }
//   ],
//   "TraitRelationship": {
//     "@Type": "co-occurring condition",
//     "@ID": "70"
//   },
//   "Citation": {
//     "@Type": "review",
//     "@Abbrev": "GeneReviews",
//     "ID": [
//       {
//         "@Source": "PubMed",
//         "$": "20301418"
//       },
//       {
//         "@Source": "BookShelf",
//         "$": "NBK1240"
//       }
//     ]
//   },
//   "XRef": [
//     {
//       "@ID": "MONDO:0009999",
//       "@DB": "MONDO"
//     },
//     {
//       "@ID": "C5399974",
//       "@DB": "MedGen"
//     },
//     {
//       "@ID": "1507",
//       "@DB": "Orphanet"
//     },
//     {
//       "@ID": "97360",
//       "@DB": "Orphanet"
//     },
//     {
//       "@Type": "MIM",
//       "@ID": "268310",
//       "@DB": "OMIM"
//     }
//   ]
// }
//
// a second example of a trait object
// {
//   "@ID": "9582",
//   "@Type": "Disease",
//   "Name": [
//     {
//       "ElementValue": {
//         "@Type": "Preferred",
//         "$": "Hemochromatosis type 1"
//       },
//       "XRef": {
//         "@ID": "MONDO:0021001",
//         "@DB": "MONDO"
//       }
//     },
//     {
//       "ElementValue": {
//         "@Type": "Alternate",
//         "$": "HFE-Associated Hereditary Hemochromatosis"
//       }
//     }
//   ],
//   "Symbol": [
//     {
//       "ElementValue": {
//         "@Type": "Preferred",
//         "$": "HFE1"
//       },
//       "XRef": {
//         "@Type": "MIM",
//         "@ID": "235200",
//         "@DB": "OMIM"
//       }
//     },
//     {
//       "ElementValue": {
//         "@Type": "Alternate",
//         "$": "HFE-HH"
//       }
//     }
//   ],
//   "AttributeSet": [
//     {
//       "Attribute": {
//         "@Type": "public definition",
//         "$": "HFE hemochromatosis is characterized by inappropriately high absorption of iron by the small intestinal mucosa. The phenotypic spectrum of HFE hemochromatosis includes: Persons with clinical HFE hemochromatosis, in whom manifestations of end-organ damage secondary to iron overload are present; Individuals with biochemical HFE hemochromatosis, in whom transferrin-iron saturation is increased and the only evidence of iron overload is increased serum ferritin concentration; and Non-expressing p.Cys282Tyr homozygotes, in whom neither clinical manifestations of HFE hemochromatosis nor iron overload are present. Clinical HFE hemochromatosis is characterized by excessive storage of iron in the liver, skin, pancreas, heart, joints, and anterior pituitary gland. In untreated individuals, early symptoms include: abdominal pain, weakness, lethargy, weight loss, arthralgias, diabetes mellitus; and increased risk of cirrhosis when the serum ferritin is higher than 1,000 ng/mL. Other findings may include progressive increase in skin pigmentation, congestive heart failure, and/or arrhythmias, arthritis, and hypogonadism. Clinical HFE hemochromatosis is more common in men than women."
//       },
//       "XRef": {
//         "@ID": "NBK1440",
//         "@DB": "GeneReviews"
//       }
//     },
//     {
//       "Attribute": {
//         "@Type": "disease mechanism",
//         "@integerValue": "273",
//         "$": "loss of function"
//       },
//       "XRef": [
//         {
//           "@ID": "GTR000260619",
//           "@DB": "Genetic Testing Registry (GTR)"
//         },
//         {
//           "@ID": "GTR000560323",
//           "@DB": "Genetic Testing Registry (GTR)"
//         },
//         {
//           "@ID": "GTR000508786",
//           "@DB": "Genetic Testing Registry (GTR)"
//         },
//         {
//           "@ID": "GTR000264968",
//           "@DB": "Genetic Testing Registry (GTR)"
//         },
//         {
//           "@ID": "GTR000271417",
//           "@DB": "Genetic Testing Registry (GTR)"
//         },
//         {
//           "@ID": "GTR000560567",
//           "@DB": "Genetic Testing Registry (GTR)"
//         },
//         {
//           "@ID": "GTR000500300",
//           "@DB": "Genetic Testing Registry (GTR)"
//         },
//         {
//           "@ID": "GTR000558915",
//           "@DB": "Genetic Testing Registry (GTR)"
//         },
//         {
//           "@ID": "GTR000028914",
//           "@DB": "Genetic Testing Registry (GTR)"
//         },
//         {
//           "@ID": "GTR000558542",
//           "@DB": "Genetic Testing Registry (GTR)"
//         },
//         {
//           "@ID": "GTR000521586",
//           "@DB": "Genetic Testing Registry (GTR)"
//         },
//         {
//           "@ID": "GTR000508970",
//           "@DB": "Genetic Testing Registry (GTR)"
//         }
//       ]
//     },
//     {
//       "Attribute": {
//         "@Type": "GARD id",
//         "@integerValue": "10417"
//       },
//       "XRef": {
//         "@ID": "10417",
//         "@DB": "Office of Rare Diseases"
//       }
//     }
//   ],
//   "Citation": [
//     {
//       "@Type": "review",
//       "@Abbrev": "GeneReviews",
//       "ID": [
//         {
//           "@Source": "PubMed",
//           "$": "20301613"
//         },
//         {
//           "@Source": "BookShelf",
//           "$": "NBK1440"
//         }
//       ]
//     },
//     {
//       "@Type": "Translational/Evidence-based",
//       "@Abbrev": "EuroGenetest, 2010",
//       "ID": {
//         "@Source": "pmc",
//         "$": "2987432"
//       }
//     },
//     {
//       "@Type": "general",
//       "@Abbrev": "USPSTF, 2006",
//       "ID": {
//         "@Source": "PubMed",
//         "$": "16880462"
//       }
//     },
//     {
//       "@Type": "general",
//       "@Abbrev": "AASLD, 2011",
//       "ID": {
//         "@Source": "pmc",
//         "$": "3149125"
//       }
//     },
//     {
//       "@Type": "general",
//       "@Abbrev": "ACMG SF v3.0, 2021",
//       "ID": [
//         {
//           "@Source": "PubMed",
//           "$": "34012068"
//         },
//         {
//           "@Source": "DOI",
//           "$": "10.1038/s41436-021-01172-3"
//         }
//       ]
//     },
//     {
//       "@Type": "general",
//       "@Abbrev": "ACMG SF v3.1, 2022",
//       "ID": [
//         {
//           "@Source": "PubMed",
//           "$": "35802134"
//         },
//         {
//           "@Source": "DOI",
//           "$": "10.1016/j.gim.2022.04.006"
//         }
//       ]
//     }
//   ],
//   "XRef": [
//     {
//       "@ID": "MONDO:0021001",
//       "@DB": "MONDO"
//     },
//     {
//       "@ID": "C3469186",
//       "@DB": "MedGen"
//     },
//     {
//       "@Type": "MIM",
//       "@ID": "235200",
//       "@DB": "OMIM"
//     }
//   ]
// }

/**
 * Represents the input structure for a trait.
 */
interface TraitInput {
  '@ID'?: string;
  '@Type'?: string;
  Name?: SetElementInput | SetElementInput[];
  Symbol?: SetElementInput | SetElementInput[];
  AttributeSet?: AttributeSetInput | AttributeSetInput[];
  TraitRelationship?: {
    '@Type'?: string;
    '@ID'?: string;
  };
  Citation?: CitationInput | CitationInput[];
  XRef?: XRefInput | XRefInput[];
  Comment?: CommentInput | CommentInput[];
}

/**
 * Represents the output structure for a trait.
 */
interface TraitOutput {
  id: string | null;
  type: string | null;
  name: Array<SetElementOutput> | null;
  symbol: Array<SetElementOutput> | null;
  attribute_set: Array<AttributeSetOutput> | null;
  trait_relationship: {
    type: string | null;
    id: string | null;
  };
  citation: Array<CitationOutput> | null;
  xref: Array<XRefOutput> | null;
  comment: Array<CommentOutput> | null;
}

interface TraitData {
  Trait?: TraitInput | TraitInput[];
}

/**
 * Builds a TraitOutput object based on the provided TraitInput.
 * @param item - The TraitInput object.
 * @returns The corresponding TraitOutput object.
 */
function buildTraitOutput(item: TraitInput): TraitOutput {
  return {
    id: item['@ID'] ? item['@ID'] : null,
    type: item['@Type'] ? item['@Type'] : null,
    name: item.Name ? buildSetElementsOutput(item.Name) : null,
    symbol: item.Symbol ? buildSetElementsOutput(item.Symbol) : null,
    attribute_set: item.AttributeSet ? buildAttributeSetsOutput(item.AttributeSet) : null,
    trait_relationship: {
      type: item.TraitRelationship && item.TraitRelationship['@Type'] ? item.TraitRelationship['@Type'] : null,
      id: item.TraitRelationship && item.TraitRelationship['@ID'] ? item.TraitRelationship['@ID'] : null
    },
    citation: item.Citation ? buildCitationsOutput(item.Citation) : null,
    xref: item.XRef ? buildXRefsOutput(item.XRef) : null,
    comment: item.Comment ? buildCommentsOutput(item.Comment) : null
  };
}

/**
 * Builds an array of TraitOutput objects based on the provided TraitInput.
 * If a single trait object is provided, the function will return an array with a single TraitOutput object.
 * @param items - The TraitInput object or an array of TraitInput objects.
 * @returns An array of TraitOutput objects.
 */
function buildTraitsOutput(items: TraitInput | TraitInput[]): TraitOutput[] {
  if (!Array.isArray(items)) {
    items = [items];
  }

  return items.map((item): TraitOutput => ({
    ...buildTraitOutput(item)
  }));
}

/**
 * Parses the JSON input and returns an array of TraitOutput objects.
 * @param json - The JSON input string.
 * @returns An array of TraitOutput objects.
 * @throws {Error} If the JSON input is invalid.
 */
function parseTraits(json: string): TraitOutput[] {
  let data: TraitData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let traits = data && data.Trait ? data.Trait : [];

  return buildTraitsOutput(traits);
}

// -- TraitSet interfaces and functions --

// below is an example of a JSON object that represents a trait set object
// {
//   "@Type": "Disease",
//   "@ID": "8827",
//   "Trait": [
//     {
//       "@ID": "1053",
//       "@Type": "Disease",
//       "Name": {
//         "ElementValue": {
//           "@Type": "Preferred",
//           "$": "Brachydactyly type B1"
//         },
//         "XRef": [
//           {
//             "@ID": "Brachydactyly+type+B1/7857",
//             "@DB": "Genetic Alliance"
//           },
//           {
//             "@ID": "MONDO:0007220",
//             "@DB": "MONDO"
//           }
//         ]
//       },
//       "Symbol": [
//         {
//           "ElementValue": {
//             "@Type": "Preferred",
//             "$": "BDB1"
//           },
//           "XRef": {
//             "@Type": "MIM",
//             "@ID": "113000",
//             "@DB": "OMIM"
//           }
//         },
//         {
//           "ElementValue": {
//             "@Type": "Alternate",
//             "$": "BDB"
//           },
//           "XRef": {
//             "@Type": "MIM",
//             "@ID": "113000",
//             "@DB": "OMIM"
//           }
//         }
//       ],
//       "AttributeSet": [
//         {
//           "Attribute": {
//             "@Type": "keyword",
//             "$": "ROR2-Related Disorders"
//           }
//         },
//         {
//           "Attribute": {
//             "@Type": "GARD id",
//             "@integerValue": "18009"
//           },
//           "XRef": {
//             "@ID": "18009",
//             "@DB": "Office of Rare Diseases"
//           }
//         }
//       ],
//       "TraitRelationship": {
//         "@Type": "co-occurring condition",
//         "@ID": "70"
//       },
//       "XRef": [
//         {
//           "@ID": "MONDO:0007220",
//           "@DB": "MONDO"
//         },
//         {
//           "@ID": "C1862112",
//           "@DB": "MedGen"
//         },
//         {
//           "@ID": "93383",
//           "@DB": "Orphanet"
//         },
//         {
//           "@Type": "MIM",
//           "@ID": "113000",
//           "@DB": "OMIM"
//         }
//       ]
//     },
//     {
//       "@ID": "5880",
//       "@Type": "Disease",
//       "Name": [
//         {
//           "ElementValue": {
//             "@Type": "Preferred",
//             "$": "Autosomal recessive Robinow syndrome"
//           },
//           "XRef": {
//             "@ID": "MONDO:0009999",
//             "@DB": "MONDO"
//           }
//         },
//         {
//           "ElementValue": {
//             "@Type": "Alternate",
//             "$": "COSTOVERTEBRAL SEGMENTATION DEFECT WITH MESOMELIA"
//           },
//           "XRef": {
//             "@Type": "MIM",
//             "@ID": "268310",
//             "@DB": "OMIM"
//           }
//         },
//         {
//           "ElementValue": {
//             "@Type": "Alternate",
//             "$": "COVESDEM SYNDROME"
//           },
//           "XRef": {
//             "@Type": "MIM",
//             "@ID": "268310",
//             "@DB": "OMIM"
//           }
//         },
//         {
//           "ElementValue": {
//             "@Type": "Alternate",
//             "$": "ROBINOW SYNDROME, AUTOSOMAL RECESSIVE 1"
//           },
//           "XRef": [
//             {
//               "@Type": "MIM",
//               "@ID": "268310",
//               "@DB": "OMIM"
//             },
//             {
//               "@Type": "Allelic variant",
//               "@ID": "602337.0010",
//               "@DB": "OMIM"
//             },
//             {
//               "@Type": "Allelic variant",
//               "@ID": "602337.0011",
//               "@DB": "OMIM"
//             },
//             {
//               "@Type": "Allelic variant",
//               "@ID": "602337.0012",
//               "@DB": "OMIM"
//             },
//             {
//               "@Type": "Allelic variant",
//               "@ID": "602337.0006",
//               "@DB": "OMIM"
//             },
//             {
//               "@Type": "Allelic variant",
//               "@ID": "602337.0004",
//               "@DB": "OMIM"
//             },
//             {
//               "@Type": "Allelic variant",
//               "@ID": "602337.0005",
//               "@DB": "OMIM"
//             },
//             {
//               "@Type": "Allelic variant",
//               "@ID": "602337.0007",
//               "@DB": "OMIM"
//             }
//           ]
//         }
//       ],
//       "Symbol": [
//         {
//           "ElementValue": {
//             "@Type": "Preferred",
//             "$": "RRS1"
//           },
//           "XRef": {
//             "@Type": "MIM",
//             "@ID": "268310",
//             "@DB": "OMIM"
//           }
//         },
//         {
//           "ElementValue": {
//             "@Type": "Alternate",
//             "$": "RRS"
//           }
//         }
//       ],
//       "AttributeSet": [
//         {
//           "Attribute": {
//             "@Type": "public definition",
//             "$": "ROR2-related Robinow syndrome is characterized by distinctive craniofacial features, skeletal abnormalities, and other anomalies. Craniofacial features include macrocephaly, broad prominent forehead, low-set ears, ocular hypertelorism, prominent eyes, midface hypoplasia, short upturned nose with depressed nasal bridge and flared nostrils, large and triangular mouth with exposed incisors and upper gums, gum hypertrophy, misaligned teeth, ankyloglossia, and micrognathia. Skeletal abnormalities include short stature, mesomelic or acromesomelic limb shortening, hemivertebrae with fusion of thoracic vertebrae, and brachydactyly. Other common features include micropenis with or without cryptorchidism in males and reduced clitoral size and hypoplasia of the labia majora in females, renal tract abnormalities, and nail hypoplasia or dystrophy. The disorder is recognizable at birth or in early childhood."
//           },
//           "XRef": {
//             "@ID": "NBK1240",
//             "@DB": "GeneReviews"
//           }
//         },
//         {
//           "Attribute": {
//             "@Type": "GARD id",
//             "@integerValue": "16568"
//           },
//           "XRef": {
//             "@ID": "16568",
//             "@DB": "Office of Rare Diseases"
//           }
//         }
//       ],
//       "TraitRelationship": {
//         "@Type": "co-occurring condition",
//         "@ID": "70"
//       },
//       "Citation": {
//         "@Type": "review",
//         "@Abbrev": "GeneReviews",
//         "ID": [
//           {
//             "@Source": "PubMed",
//             "$": "20301418"
//           },
//           {
//             "@Source": "BookShelf",
//             "$": "NBK1240"
//           }
//         ]
//       },
//       "XRef": [
//         {
//           "@ID": "MONDO:0009999",
//           "@DB": "MONDO"
//         },
//         {
//           "@ID": "C5399974",
//           "@DB": "MedGen"
//         },
//         {
//           "@ID": "1507",
//           "@DB": "Orphanet"
//         },
//         {
//           "@ID": "97360",
//           "@DB": "Orphanet"
//         },
//         {
//           "@Type": "MIM",
//           "@ID": "268310",
//           "@DB": "OMIM"
//         }
//       ]
//     }
//   ]
// }


/**
 * Represents the input structure for a trait set.
 */ 
interface TraitSetInput {
  '@Type'?: string;
  '@ID'?: string;
  Trait?: TraitInput | TraitInput[]; 
}

/**
 * Represents the output structure for a trait set.
 */
interface TraitSetOutput {
  type: string | null;
  id: string | null;
  trait: Array<TraitOutput> | null; 
}

interface TraitSetData {
  TraitSet?: TraitSetInput;
}

/**
 * Builds a TraitSetOutput object based on the provided TraitSetInput.
 * @param item - The TraitSetInput object.
 * @returns The corresponding TraitSetOutput object.
 */
function buildTraitSetOutput(item: TraitSetInput): TraitSetOutput {
  return {
    type: item['@Type'] ? item['@Type'] : null,
    id: item['@ID'] ? item['@ID'] : null,
    trait: item.Trait ? buildTraitsOutput(item.Trait) : null
  };
}

/**
 * Parses the JSON input and returns a TraitSetOutput object.
 * @param json - The JSON input string.
 * @returns A TraitSetOutput object.
 * @throws {Error} If the JSON input is invalid.
 */
function parseTraitSet(json: string): TraitSetOutput {
  let data: TraitSetData;
  try {
    data = JSON.parse(json);
  } catch (e) {
    throw new Error('Invalid JSON input');
  }

  let traitSet = data && data.TraitSet ? data.TraitSet : {};

  return buildTraitSetOutput(traitSet); 
}
