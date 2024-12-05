const { type } = require('os');
const rewire = require('rewire');
const { text } = require('stream/consumers');
const parseUtils = rewire('../dist/parse-utils.js');

// Get the functions to test
const buildGeneListOutput = parseUtils.__get__('buildGeneListOutput');  
const buildGeneListsOutput = parseUtils.__get__('buildGeneListsOutput');
const parseGeneLists = parseUtils.__get__('parseGeneLists');
const buildCommentOutput = parseUtils.__get__('buildCommentOutput');
const buildCommentsOutput = parseUtils.__get__('buildCommentsOutput');
const parseComments = parseUtils.__get__('parseComments');
const buildCitationOutput = parseUtils.__get__('buildCitationOutput');
const buildCitationsOutput = parseUtils.__get__('buildCitationsOutput');
const parseCitations = parseUtils.__get__('parseCitations');
const buildXRefOutput = parseUtils.__get__('buildXRefOutput');
const buildXRefsOutput = parseUtils.__get__('buildXRefsOutput');
const parseXRefs = parseUtils.__get__('parseXRefs');
const buildXRefItemOutput = parseUtils.__get__('buildXRefItemOutput');
const parseXRefItems = parseUtils.__get__('parseXRefItems');
const buildAttributeOutput = parseUtils.__get__('buildAttributeOutput');
const parseAttribute = parseUtils.__get__('parseAttribute');
const buildAttributeSetOutput = parseUtils.__get__('buildAttributeSetOutput');
const buildAttributeSetsOutput = parseUtils.__get__('buildAttributeSetsOutput');
const parseAttributeSet = parseUtils.__get__('parseAttributeSet');
const buildNucleotideExpressionOutput = parseUtils.__get__('buildNucleotideExpressionOutput');
const parseNucleotideExpression = parseUtils.__get__('parseNucleotideExpression');
const buildProteinExpressionOutput = parseUtils.__get__('buildProteinExpressionOutput');
const parseProteinExpression = parseUtils.__get__('parseProteinExpression');
const buildHGVSOutput = parseUtils.__get__('buildHGVSOutput');
const buildHGVSArrayOutput = parseUtils.__get__('buildHGVSArrayOutput');
const parseHGVS = parseUtils.__get__('parseHGVS');
const buildTraitOutput = parseUtils.__get__('buildTraitOutput');
const buildTraitsOutput = parseUtils.__get__('buildTraitsOutput');
const parseTraits = parseUtils.__get__('parseTraits');
const buildTraitSetOutput = parseUtils.__get__('buildTraitSetOutput');
const parseTraitSet = parseUtils.__get__('parseTraitSet');
const buildDescriptionItemsOutput = parseUtils.__get__('buildDescriptionItemsOutput');
const buildAggDescriptionOutput = parseUtils.__get__('buildAggDescriptionOutput');
const parseAggDescription = parseUtils.__get__('parseAggDescription');


test('buildGeneListOutput should build GeneListOutput correctly', () => {
  const input = { Gene: { '@Symbol': 'Symbol1', 'Name': {'$':'HGNC1'},'@RelationshipType': 'asserted, not computed' } };
  const expectedOutput = { symbol: 'Symbol1', name: 'HGNC1', relationship_type: 'asserted, not computed'};
  expect(buildGeneListOutput(input)).toEqual(expectedOutput);
});

test('buildGeneListsOutput should build an array of GeneListOutput correctly', () => {
  const input = [
    { Gene: { '@Symbol': 'Symbol1', 'Name': {'$':'HGNC1'},'@RelationshipType': 'asserted, not computed' } },
    { Gene: { '@Symbol': 'Symbol2', 'Name': {'$':'HGNC2'},'@RelationshipType': 'asserted, not computed' } }
  ];
  const expectedOutput = [
    { symbol: 'Symbol1', name: 'HGNC1', relationship_type: 'asserted, not computed' },
    { symbol: 'Symbol2', name: 'HGNC2', relationship_type: 'asserted, not computed' }
  ];
  expect(buildGeneListsOutput(input)).toEqual(expectedOutput);
});

test('parseGeneLists should parse JSON input correctly', () => {
  const json = '{"GeneList":[{"Gene":{"@Symbol":"Symbol1","Name":{"$":"HGNC1"},"@RelationshipType":"asserted, not computed"}}]}';
  const expectedOutput = [{ symbol: 'Symbol1', name: 'HGNC1', relationship_type: 'asserted, not computed' }];
  expect(parseGeneLists(json)).toEqual(expectedOutput);
});

test('buildCommentOutput should build CommentOutput correctly', () => {
  const input = { $: 'This is a comment', '@Type': 'Type1', '@DataSource': 'Source1' };
  const expectedOutput = { text: 'This is a comment', type: 'Type1', source: 'Source1' };
  expect(buildCommentOutput(input)).toEqual(expectedOutput);
});

test('buildCommentsOutput should build an array of CommentOutput correctly', () => {
  const input = [
    { $: 'This is a comment', '@Type': 'Type1', '@DataSource': 'Source1' },
    { $: 'Another comment', '@Type': 'Type2', '@DataSource': 'Source2' }
  ];
  const expectedOutput = [
    { text: 'This is a comment', type: 'Type1', source: 'Source1' },
    { text: 'Another comment', type: 'Type2', source: 'Source2' }
  ];
  expect(buildCommentsOutput(input)).toEqual(expectedOutput);
});

test('parseComments should parse JSON input correctly', () => {
  const json = '{"Comment":[{"$":"This is a comment","@Type":"Type1","@DataSource":"Source1"}]}';
  const expectedOutput = [{ text: 'This is a comment', type: 'Type1', source: 'Source1' }];
  expect(parseComments(json)).toEqual(expectedOutput);
});

test('buildCitationOutput should build CitationOutput correctly', () => {
  const input = { ID: { $: '123', '@Source': 'Source1' }, URL: { $: 'http://example.com' }, CitationText: { $: 'Citation text' }, '@Type': 'Type1', '@Abbrev': 'Abbrev1' };
  const expectedOutput = {
    id: [{id:'123', source: 'Source1', curie: 'Source1:123'}],
    url: 'http://example.com',
    text: 'Citation text',
    type: 'Type1',
    abbrev: 'Abbrev1'
  };
  expect(buildCitationOutput(input)).toEqual(expectedOutput);
});

test('buildCitationsOutput should build an array of CitationOutput correctly', () => {
  const input = [
    { ID: { $: '123', '@Source': 'Source1' }, URL: { $: 'http://example.com' }, CitationText: { $: 'Citation text' }, '@Type': 'Type1', '@Abbrev': 'Abbrev1' }
  ];
  const expectedOutput = [
    {
      id: [{id: '123', source: 'Source1', curie: 'Source1:123'}],
      url: 'http://example.com',
      text: 'Citation text',
      type: 'Type1',
      abbrev: 'Abbrev1'
    }
  ];
  expect(buildCitationsOutput(input)).toEqual(expectedOutput);
});

test('parseCitations should parse JSON input correctly', () => {
  const json = '{"Citation":[{"ID":{"$":"123","@Source":"Source1"},"URL":{"$":"http://example.com"},"CitationText":{"$":"Citation text"},"@Type":"Type1","@Abbrev":"Abbrev1"}]}';
  const expectedOutput = [
    {
      id: [{id: '123', source: 'Source1', curie: 'Source1:123'}],
      url: 'http://example.com',
      text: 'Citation text',
      type: 'Type1',
      abbrev: 'Abbrev1'
    }
  ];
  expect(parseCitations(json)).toEqual(expectedOutput);
});

test('buildXRefOutput should build XRefOutput correctly', () => {
  const input = { '@DB': 'DB1', '@ID': 'ID1', '@URL': 'http://example.com', '@Type': 'Type1', '@Status': 'Status1' };
  const expectedOutput = { db: 'DB1', id: 'ID1', url: 'http://example.com', type: 'Type1', status: 'Status1' };
  expect(buildXRefOutput(input)).toEqual(expectedOutput);
});

test('buildXRefsOutput should build an array of XRefOutput correctly', () => {
  const input = [
    { '@DB': 'DB1', '@ID': 'ID1', '@URL': 'http://example.com', '@Type': 'Type1', '@Status': 'Status1' }
  ];
  const expectedOutput = [
    { db: 'DB1', id: 'ID1', url: 'http://example.com', type: 'Type1', status: 'Status1' }
  ];
  expect(buildXRefsOutput(input)).toEqual(expectedOutput);
});

test('parseXRefs should parse JSON input correctly', () => {
  const json = '{"XRef":[{"@DB":"DB1","@ID":"ID1","@URL":"http://example.com","@Type":"Type1","@Status":"Status1"}]}';
  const expectedOutput = [
    { db: 'DB1', id: 'ID1', url: 'http://example.com', type: 'Type1', status: 'Status1' }
  ];
  expect(parseXRefs(json)).toEqual(expectedOutput);
});

// Tests for buildXRefItemOutput
test('buildXRefItemOutput should build XRefItemOutput correctly', () => {
  const input = { db: 'db1', id: 'id1', type: 'type1', url: 'http://example.com', status: 'status1', ref_field: 'name' };
  const expectedOutput = { db: 'db1', id: 'id1', type: 'type1', url: 'http://example.com', status: 'status1', ref_field: 'name' };
  expect(buildXRefItemOutput(input)).toEqual(expectedOutput);
});

// Tests for parseXRefItems
test('parseXRefItems should parse JSON input correctly', () => {
  const jsonArray = ['{"db":"db1","id":"id1","type":"type1","url":"http://example.com","status":"status1", "ref_field": "name"}'];
  const expectedOutput = [{ db: 'db1', id: 'id1', type: 'type1', url: 'http://example.com', status: 'status1', ref_field: 'name' }];
  expect(parseXRefItems(jsonArray)).toEqual(expectedOutput);
});

test('parseXRefItems should throw error for invalid JSON input', () => {
  const jsonArray = ['invalid json'];
  expect(() => parseXRefItems(jsonArray)).toThrow('Invalid JSON input');
});

// Tests for buildAttributeOutput
test('buildAttributeOutput should build AttributeOutput correctly', () => {
  const input = { '@Type': 'type1', $: 'value1', '@integerValue': '123', '@dateValue': '2023-01-01T00:00:00Z' };
  const expectedOutput = {
    type: 'type1',
    value: 'value1',
    integer_value: 123,
    date_value: new Date('2023-01-01T00:00:00Z')
  };
  expect(buildAttributeOutput(input)).toEqual(expectedOutput);
});

// Tests for parseAttribute
test('parseAttribute should parse JSON input correctly', () => {
  const json = '{"@Type":"type1","$":"value1","@integerValue":"123","@dateValue":"2023-01-01T00:00:00Z"}';
  const expectedOutput = {
    type: 'type1',
    value: 'value1',
    integer_value: 123,
    date_value: new Date('2023-01-01T00:00:00Z')
  };
  expect(parseAttribute(json)).toEqual(expectedOutput);
});

test('parseAttribute should throw error for invalid JSON input', () => {
  const json = 'invalid json';
  expect(() => parseAttribute(json)).toThrow('Invalid JSON input');
});

// Tests for buildAttributeSetOutput
test('buildAttributeSetOutput should build AttributeSetOutput correctly', () => {
  const input = {
    Attribute: { '@Type': 'type1', $: 'value1', '@integerValue': '123', '@dateValue': '2023-01-01T00:00:00Z' },
    Citation: [{ ID: { $: '123', '@Source': 'Source1' }, URL: { $: 'http://example.com' }, CitationText: { $: 'Citation text' }, '@Type': 'Type1', '@Abbrev': 'Abbrev1' }],
    XRef: [{ '@DB': 'DB1', '@ID': 'ID1', '@URL': 'http://example.com', '@Type': 'Type1', '@Status': 'Status1' }],
    Comment: [{ $: 'This is a comment', '@Type': 'Type1', '@DataSource': 'Source1' }]
  };
  const expectedOutput = {
    attribute: { type: 'type1', value: 'value1', integer_value: 123, date_value: new Date('2023-01-01T00:00:00Z') },
    citation: [{
      id: [{id: '123', source: 'Source1', curie: 'Source1:123'}], 
      url: 'http://example.com',
      text: 'Citation text',
      type: 'Type1',
      abbrev: 'Abbrev1'
    }],
    xref: [{ db: 'DB1', id: 'ID1', url: 'http://example.com', type: 'Type1', status: 'Status1' }],
    comment: [{ text: 'This is a comment', type: 'Type1', source: 'Source1' }]
  };
  expect(buildAttributeSetOutput(input)).toEqual(expectedOutput);
});

// Tests for buildAttributeSetsOutput
test('buildAttributeSetsOutput should build an array of AttributeSetOutput correctly', () => {
  const input = [{
    Attribute: { '@Type': 'type1', $: 'value1', '@integerValue': '123', '@dateValue': '2023-01-01T00:00:00Z' },
    Citation: [{ ID: { $: '123', '@Source': 'Source1' }, URL: { $: 'http://example.com' }, CitationText: { $: 'Citation text' }, '@Type': 'Type1', '@Abbrev': 'Abbrev1' }],
    XRef: [{ '@DB': 'DB1', '@ID': 'ID1', '@URL': 'http://example.com', '@Type': 'Type1', '@Status': 'Status1' }],
    Comment: [{ $: 'This is a comment', '@Type': 'Type1', '@DataSource': 'Source1' }]
  }];
  const expectedOutput = [{
    attribute: { type: 'type1', value: 'value1', integer_value: 123, date_value: new Date('2023-01-01T00:00:00Z') },
    citation: [{
      id: [{id: '123', source: 'Source1', curie: 'Source1:123'}],
      url: 'http://example.com',
      text: 'Citation text',
      type: 'Type1',
      abbrev: 'Abbrev1'
    }],
    xref: [{ db: 'DB1', id: 'ID1', url: 'http://example.com', type: 'Type1', status: 'Status1' }],
    comment: [{ text: 'This is a comment', type: 'Type1', source: 'Source1' }]
  }];
  expect(buildAttributeSetsOutput(input)).toEqual(expectedOutput);
});

// Tests for parseAttributeSet
test('parseAttributeSet should parse JSON input correctly', () => {
  const json = '{"AttributeSet":[{"Attribute":{"@Type":"type1","$":"value1","@integerValue":"123","@dateValue":"2023-01-01T00:00:00Z"}, "Citation":[{"ID":{"$":"123","@Source":"Source1"},"URL":{"$":"http://example.com"},"CitationText":{"$":"Citation text"},"@Type":"Type1","@Abbrev":"Abbrev1"}],"XRef":[{"@DB":"DB1","@ID":"ID1","@URL":"http://example.com","@Type":"Type1","@Status":"Status1"}],"Comment":[{"$":"This is a comment","@Type":"Type1","@DataSource":"Source1"}]}]}';
  const expectedOutput = [{
    attribute: { type: 'type1', value: 'value1', integer_value: 123, date_value: new Date('2023-01-01T00:00:00Z') },
    citation: [{
      id: [{id: '123', source: 'Source1', curie: 'Source1:123'}],
      url: 'http://example.com',
      text: 'Citation text',
      type: 'Type1',
      abbrev: 'Abbrev1'
    }],
    xref: [{ db: 'DB1', id: 'ID1', url: 'http://example.com', type: 'Type1', status: 'Status1' }],
    comment: [{ text: 'This is a comment', type: 'Type1', source: 'Source1' }]
  }];
  expect(parseAttributeSet(json)).toEqual(expectedOutput);
});

test('parseAttributeSet should throw error for invalid JSON input', () => {
  const json = 'invalid json';
  expect(() => parseAttributeSet(json)).toThrow('Invalid JSON input');
});

// Tests for buildNucleotideExpressionOutput
test('buildNucleotideExpressionOutput should build NucleotideExpressionOutput correctly', () => {
  const input = { Expression: { $: 'expression1' }, '@sequenceType': 'type1', '@sequenceAccessionVersion': 'version1', '@sequenceAccession': 'accession1', '@sequenceVersion': 'version2', '@change': 'change1', '@Assembly': 'assembly1', '@Submitted': 'submitted1', '@MANESelect': 'true', '@MANEPlusClinical': 'false' };
  const expectedOutput = {
    expression: 'expression1',
    sequence_type: 'type1',
    sequence_accession_version: 'version1',
    sequence_accession: 'accession1',
    sequence_version: 'version2',
    change: 'change1',
    assembly: 'assembly1',
    submitted: 'submitted1',
    mane_select: true,
    mane_plus_clinical: false
  };
  expect(buildNucleotideExpressionOutput(input)).toEqual(expectedOutput);
});

// Tests for parseNucleotideExpression
test('parseNucleotideExpression should parse JSON input correctly', () => {
  const json = '{"NucleotideExpression":{"Expression":{"$":"expression1"},"@sequenceType":"type1","@sequenceAccessionVersion":"version1","@sequenceAccession":"accession1","@sequenceVersion":"version2","@change":"change1","@Assembly":"assembly1","@Submitted":"submitted1","@MANESelect":"true","@MANEPlusClinical":"false"}}';
  const expectedOutput = {
    expression: 'expression1',
    sequence_type: 'type1',
    sequence_accession_version: 'version1',
    sequence_accession: 'accession1',
    sequence_version: 'version2',
    change: 'change1',
    assembly: 'assembly1',
    submitted: 'submitted1',
    mane_select: true,
    mane_plus_clinical: false
  };
  expect(parseNucleotideExpression(json)).toEqual(expectedOutput);
});

test('parseNucleotideExpression should throw error for invalid JSON input', () => {
  const json = 'invalid json';
  expect(() => parseNucleotideExpression(json)).toThrow('Invalid JSON input');
});

// Tests for buildProteinExpressionOutput
test('buildProteinExpressionOutput should build ProteinExpressionOutput correctly', () => {
  const input = { Expression: { $: 'expression1' }, '@sequenceAccessionVersion': 'version1', '@sequenceAccession': 'accession1', '@sequenceVersion': 'version2', '@change': 'change1' };
  const expectedOutput = {
    expression: 'expression1',
    sequence_accession_version: 'version1',
    sequence_accession: 'accession1',
    sequence_version: 'version2',
    change: 'change1'
  };
  expect(buildProteinExpressionOutput(input)).toEqual(expectedOutput);
});

// Tests for parseProteinExpression
test('parseProteinExpression should parse JSON input correctly', () => {
  const json = '{"ProteinExpression":{"Expression":{"$":"expression1"},"@sequenceAccessionVersion":"version1","@sequenceAccession":"accession1","@sequenceVersion":"version2","@change":"change1"}}';
  const expectedOutput = {
    expression: 'expression1',
    sequence_accession_version: 'version1',
    sequence_accession: 'accession1',
    sequence_version: 'version2',
    change: 'change1'
  };
  expect(parseProteinExpression(json)).toEqual(expectedOutput);
});

test('parseProteinExpression should throw error for invalid JSON input', () => {
  const json = 'invalid json';
  expect(() => parseProteinExpression(json)).toThrow('Invalid JSON input');
});

// Tests for buildHGVSOutput
test('buildHGVSOutput should build HGVSOutput correctly', () => {
  const input = {
    NucleotideExpression: { Expression: { $: 'expression1' }, '@sequenceType': 'type1', '@sequenceAccessionVersion': 'version1', '@sequenceAccession': 'accession1', '@sequenceVersion': 'version2', '@change': 'change1', '@Assembly': 'assembly1', '@Submitted': 'submitted1', '@MANESelect': 'true', '@MANEPlusClinical': 'false' },
    ProteinExpression: { Expression: { $: 'expression1' }, '@sequenceAccessionVersion': 'version1', '@sequenceAccession': 'accession1', '@sequenceVersion': 'version2', '@change': 'change1' },
    MolecularConsequence: [{ '@DB': 'DB1', '@ID': 'ID1', '@URL': 'http://example.com', '@Type': 'Type1', '@Status': 'Status1' }],
    '@Type': 'type1',
    '@Assembly': 'assembly1'
  };
  const expectedOutput = {
    nucleotide_expression: {
      expression: 'expression1',
      sequence_type: 'type1',
      sequence_accession_version: 'version1',
      sequence_accession: 'accession1',
      sequence_version: 'version2',
      change: 'change1',
      assembly: 'assembly1',
      submitted: 'submitted1',
      mane_select: true,
      mane_plus_clinical: false
    },
    protein_expression: {
      expression: 'expression1',
      sequence_accession_version: 'version1',
      sequence_accession: 'accession1',
      sequence_version: 'version2',
      change: 'change1'
    },
    molecular_consequence: [{ db: 'DB1', id: 'ID1', url: 'http://example.com', type: 'Type1', status: 'Status1' }],
    type: 'type1',
    assembly: 'assembly1'
  };
  expect(buildHGVSOutput(input)).toEqual(expectedOutput);
});


// Tests for buildHGVSArrayOutput
test('buildHGVSArrayOutput should build an array of HGVSOutput correctly', () => {
  const input = [{
    NucleotideExpression: { Expression: { $: 'expression1' }, '@sequenceType': 'type1', '@sequenceAccessionVersion': 'version1', '@sequenceAccession': 'accession1', '@sequenceVersion': 'version2', '@change': 'change1', '@Assembly': 'assembly1', '@Submitted': 'submitted1', '@MANESelect': 'true', '@MANEPlusClinical': 'false' },
    ProteinExpression: { Expression: { $: 'expression1' }, '@sequenceAccessionVersion': 'version1', '@sequenceAccession': 'accession1', '@sequenceVersion': 'version2', '@change': 'change1' },
    MolecularConsequence: [{ '@DB': 'DB1', '@ID': 'ID1', '@URL': 'http://example.com', '@Type': 'Type1', '@Status': 'Status1' }],
    '@Type': 'type1',
    '@Assembly': 'assembly1'
  }];
  const expectedOutput = [{
    nucleotide_expression: {
      expression: 'expression1',
      sequence_type: 'type1',
      sequence_accession_version: 'version1',
      sequence_accession: 'accession1',
      sequence_version: 'version2',
      change: 'change1',
      assembly: 'assembly1',
      submitted: 'submitted1',
      mane_select: true,
      mane_plus_clinical: false
    },
    protein_expression: {
      expression: 'expression1',
      sequence_accession_version: 'version1',
      sequence_accession: 'accession1',
      sequence_version: 'version2',
      change: 'change1'
    },
    molecular_consequence: [{ db: 'DB1', id: 'ID1', url: 'http://example.com', type: 'Type1', status: 'Status1' }],
    type: 'type1',
    assembly: 'assembly1'
  }];
  expect(buildHGVSArrayOutput(input)).toEqual(expectedOutput);
});

// Tests for parseHGVS
test('parseHGVS should parse JSON input correctly', () => {
  const json = '{"HGVS":[{"NucleotideExpression":{"Expression":{"$":"expression1"},"@sequenceType":"type1","@sequenceAccessionVersion":"version1","@sequenceAccession":"accession1","@sequenceVersion":"version2","@change":"change1","@Assembly":"assembly1","@Submitted":"submitted1","@MANESelect":"true","@MANEPlusClinical":"false"},"ProteinExpression":{"Expression":{"$":"expression1"},"@sequenceAccessionVersion":"version1","@sequenceAccession":"accession1","@sequenceVersion":"version2","@change":"change1"},"MolecularConsequence":[{"@DB":"DB1","@ID":"ID1","@URL":"http://example.com","@Type":"Type1","@Status":"Status1"}],"@Type":"type1","@Assembly":"assembly1"}]}';
  const expectedOutput = [{
    nucleotide_expression: {
      expression: 'expression1',
      sequence_type: 'type1',
      sequence_accession_version: 'version1',
      sequence_accession: 'accession1',
      sequence_version: 'version2',
      change: 'change1',
      assembly: 'assembly1',
      submitted: 'submitted1',
      mane_select: true,
      mane_plus_clinical: false
    },
    protein_expression: {
      expression: 'expression1',
      sequence_accession_version: 'version1',
      sequence_accession: 'accession1',
      sequence_version: 'version2',
      change: 'change1'
    },
    molecular_consequence: [{ db: 'DB1', id: 'ID1', url: 'http://example.com', type: 'Type1', status: 'Status1' }],
    type: 'type1',
    assembly: 'assembly1'
  }];
  expect(parseHGVS(json)).toEqual(expectedOutput);
});

test('parseHGVS should throw error for invalid JSON input', () => {
  const json = 'invalid json';
  expect(() => parseHGVS(json)).toThrow('Invalid JSON input');
});

// Example Trait json

// Tests for buildTraitOutput
test('buildTraitOutput should build TraitOutput correctly', () => {
  const input = {
    '@ID': '1053',
    '@Type': 'Disease',
    Name: {
      ElementValue: {
        '@Type': 'Preferred',
        '$': 'Brachydactyly type B1'
      },
      XRef: [
        {
          '@ID': 'Brachydactyly+type+B1/7857',
          '@DB': 'Genetic Alliance'
        },
        {
          '@ID': 'MONDO:0007220',
          '@DB': 'MONDO'
        }
      ]
    },
    Symbol: [
      {
        ElementValue: {
          '@Type': 'Preferred',
          '$': 'BDB1'
        },
        XRef: {
          '@Type': 'MIM',
          '@ID': '113000',
          '@DB': 'OMIM'
        }
      },
      {
        ElementValue: {
          '@Type': 'Alternate',
          '$': 'BDB'
        },
        XRef: {
          '@Type': 'MIM',
          '@ID': '113000',
          '@DB': 'OMIM'
        }
      }
    ],
    AttributeSet: [
      {
        Attribute: {
          '@Type': 'keyword',
          '$': 'ROR2-Related Disorders'
        }
      },
      {
        Attribute: {
          '@Type': 'GARD id',
          '@integerValue': '18009'
        },
        XRef: {
          '@ID': '18009',
          '@DB': 'Office of Rare Diseases'
        }
      }
    ],
    TraitRelationship: {
      '@Type': 'co-occurring condition',
      '@ID': '70'
    },
    XRef: [
      {
        '@ID': 'MONDO:0007220',
        '@DB': 'MONDO'
      },
      {
        '@ID': 'C1862112',
        '@DB': 'MedGen'
      },
      {
        '@ID': '93383',
        '@DB': 'Orphanet'
      },
      {
        '@Type': 'MIM',
        '@ID': '113000',
        '@DB': 'OMIM'
      }
    ]
  };
  const expectedOutput = {
    id: '1053',
    type: 'Disease',
    name: [{
      element_value: 'Brachydactyly type B1',
      type: 'Preferred',
      citation: null,
      comment: null,
      xref: [
        { id: 'Brachydactyly+type+B1/7857', db: 'Genetic Alliance', status: null, type: null, url: null },
        { id: 'MONDO:0007220', db: 'MONDO', status: null, type: null, url: null }
      ],
    }],
    symbol: [
      { element_value: 'BDB1', type: 'Preferred', citation: null, comment: null, xref:[{ type: 'MIM', id: '113000', db: 'OMIM', status: null, url: null }] },
      { element_value: 'BDB', type: 'Alternate', citation: null, comment: null, xref: [{ type: 'MIM', id: '113000', db: 'OMIM', status: null, url: null }] }
    ],
    attribute_set: [
      {attribute:{ type: 'keyword', value: 'ROR2-Related Disorders', date_value: null, integer_value: null }, citation: null, comment: null, xref: null},
      {attribute: { type: 'GARD id', integer_value: 18009, date_value: null, value: null}, citation: null, comment: null, xref: [{ id: '18009', db: 'Office of Rare Diseases', status: null, type: null, url: null }] }
    ],
    citation: null,
    comment: null,
    trait_relationship: { type: 'co-occurring condition', id: '70' },
    xref: [
      { id: 'MONDO:0007220', db: 'MONDO', status: null, type: null, url: null},
      { id: 'C1862112', db: 'MedGen', status: null, type: null, url: null },
      { id: '93383', db: 'Orphanet', status: null, type: null, url: null },
      { type: 'MIM', id: '113000', db: 'OMIM', status: null, url: null }
    ]
  };
  expect(buildTraitOutput(input)).toEqual(expectedOutput);
});

// Tests for buildTraitsOutput
test('buildTraitsOutput should build an array of TraitOutput correctly', () => {
  const input = [
    {
      '@ID': '1053',
      '@Type': 'Disease',
      Name: {
        ElementValue: {
          '@Type': 'Preferred',
          '$': 'Brachydactyly type B1'
        },
        XRef: [
          {
            '@ID': 'Brachydactyly+type+B1/7857',
            '@DB': 'Genetic Alliance'
          },
          {
            '@ID': 'MONDO:0007220',
            '@DB': 'MONDO'
          }
        ]
      },
      Symbol: [
        {
          ElementValue: {
            '@Type': 'Preferred',
            '$': 'BDB1'
          },
          XRef: {
            '@Type': 'MIM',
            '@ID': '113000',
            '@DB': 'OMIM'
          }
        },
        {
          ElementValue: {
            '@Type': 'Alternate',
            '$': 'BDB'
          },
          XRef: {
            '@Type': 'MIM',
            '@ID': '113000',
            '@DB': 'OMIM'
          }
        }
      ],
      AttributeSet: [
        {
          Attribute: {
            '@Type': 'keyword',
            '$': 'ROR2-Related Disorders'
          }
        },
        {
          Attribute: {
            '@Type': 'GARD id',
            '@integerValue': '18009'
          },
          XRef: {
            '@ID': '18009',
            '@DB': 'Office of Rare Diseases'
          }
        }
      ],
      TraitRelationship: {
        '@Type': 'co-occurring condition',
        '@ID': '70'
      },
      XRef: [
        {
          '@ID': 'MONDO:0007220',
          '@DB': 'MONDO'
        },
        {
          '@ID': 'C1862112',
          '@DB': 'MedGen'
        },
        {
          '@ID': '93383',
          '@DB': 'Orphanet'
        },
        {
          '@Type': 'MIM',
          '@ID': '113000',
          '@DB': 'OMIM'
        }
      ]
    },
    {
      '@ID': '5880',
      '@Type': 'Disease',
      Name: [
        {
          ElementValue
          : {
            '@Type': 'Preferred',
            '$': 'Autosomal recessive Robinow syndrome'
          },
          XRef: {
            '@ID': 'MONDO:0009999',
            '@DB': 'MONDO'
          }
        },
        {
          ElementValue: {
            '@Type': 'Alternate',
            '$': 'COSTOVERTEBRAL SEGMENTATION DEFECT WITH MESOMELIA'
          },
          XRef: {
            '@Type': 'MIM',
            '@ID': '268310',
            '@DB': 'OMIM'
          }
        },
        {
          ElementValue: {
            '@Type': 'Alternate',
            '$': 'COVESDEM SYNDROME'
          },
          XRef: {
            '@Type': 'MIM',
            '@ID': '268310',
            '@DB': 'OMIM'
          }
        },
        {
          ElementValue: {
            '@Type': 'Alternate',
            '$': 'ROBINOW SYNDROME, AUTOSOMAL RECESSIVE 1'
          },
          XRef: [
            {
              '@Type': 'MIM',
              '@ID': '268310',
              '@DB': 'OMIM'
            },
            {
              '@Type': 'Allelic variant',
              '@ID': '602337.0010',
              '@DB': 'OMIM'
            },
            {
              '@Type': 'Allelic variant',
              '@ID': '602337.0011',
              '@DB': 'OMIM'
            },
            {
              '@Type': 'Allelic variant',
              '@ID': '602337.0012',
              '@DB': 'OMIM'
            },
            {
              '@Type': 'Allelic variant',
              '@ID': '602337.0006',
              '@DB': 'OMIM'
            },
            {
              '@Type': 'Allelic variant',
              '@ID': '602337.0004',
              '@DB': 'OMIM'
            },
            {
              '@Type': 'Allelic variant',
              '@ID': '602337.0005',
              '@DB': 'OMIM'
            },
            {
              '@Type': 'Allelic variant',
              '@ID': '602337.0007',
              '@DB': 'OMIM'
            }
          ]
        }
      ],
      Symbol: [
        {
          ElementValue: {
            '@Type': 'Preferred',
            '$': 'RRS1'
          },
          XRef: {
            '@Type': 'MIM',
            '@ID': '268310',
            '@DB': 'OMIM'
          }
        },
        {
          ElementValue: {
            '@Type': 'Alternate',
            '$': 'RRS'
          }
        }
      ],
      AttributeSet: [
        {
          Attribute: {
            '@Type': 'public definition',
            '$': 'ROR2-related Robinow syndrome is characterized by distinctive craniofacial features, skeletal abnormalities, and other anomalies. Craniofacial features include macrocephaly, broad prominent forehead, low-set ears, ocular hypertelorism, prominent eyes, midface hypoplasia, short upturned nose with depressed nasal bridge and flared nostrils, large and triangular mouth with exposed incisors and upper gums, gum hypertrophy, misaligned teeth, ankyloglossia, and micrognathia. Skeletal abnormalities include short stature, mesomelic or acromesomelic limb shortening, hemivertebrae with fusion of thoracic vertebrae, and brachydactyly. Other common features include micropenis with or without cryptorchidism in males and reduced clitoral size and hypoplasia of the labia majora in females, renal tract abnormalities, and nail hypoplasia or dystrophy. The disorder is recognizable at birth or in early childhood.'
          },
          XRef: {
            '@ID': 'NBK1240',
            '@DB': 'GeneReviews'
          }
        },
        {
          Attribute: {
            '@Type': 'GARD id',
            '@integerValue': '16568'
          },
          XRef: {
            '@ID': '16568',
            '@DB': 'Office of Rare Diseases'
          }
        }
      ],
      TraitRelationship: {
        '@Type': 'co-occurring condition',
        '@ID': '70'
      },
      Citation: {
        '@Type': 'review',
        '@Abbrev': 'GeneReviews',
        ID: [
          {
            '@Source': 'PubMed',
            '$': '20301418'
          },
          {
            '@Source': 'BookShelf',
            '$': 'NBK1240'
          }
        ]
      },
      XRef: [
        {
          '@ID': 'MONDO:0009999',
          '@DB': 'MONDO'
        },
        {
          '@ID': 'C5399974',
          '@DB': 'MedGen'
        },
        {
          '@ID': '1507',
          '@DB': 'Orphanet'
        },
        {
          '@ID': '97360',
          '@DB': 'Orphanet'
        },
        {
          '@Type': 'MIM',
          '@ID': '268310',
          '@DB': 'OMIM'
        }
      ]
    }
  ];
  const expectedOutput = [
    {
      id: '1053',
      type: 'Disease',
      name: [{
        element_value: 'Brachydactyly type B1',
        type: 'Preferred',
        citation: null,
        comment: null,
        xref: [
          { id: 'Brachydactyly+type+B1/7857', db: 'Genetic Alliance', status: null, type: null, url: null },
          { id: 'MONDO:0007220', db: 'MONDO', status: null, type: null, url: null } 
        ]
      }],
      symbol: [
        { element_value: 'BDB1', type: 'Preferred', citation: null, comment: null,  xref: [{ type: 'MIM', id: '113000', db: 'OMIM', status: null, url: null }] },
        { element_value: 'BDB', type: 'Alternate', citation: null, comment: null,xref: [{ type: 'MIM', id: '113000', db: 'OMIM', status: null, url: null }] }
      ],
      attribute_set: [
        {
          attribute: { type: 'keyword', value: 'ROR2-Related Disorders',date_value: null, integer_value: null },
          citation: null,
          comment: null,
          xref: null
        },
        {
          attribute: { type: 'GARD id', integer_value: 18009, date_value: null, value: null },
          citation: null,
          comment: null,
          xref: [{ id: '18009', db: 'Office of Rare Diseases', url: null, type: null, status: null }]
        }
      ],
      citation: null,
      comment: null,
      trait_relationship: { type: 'co-occurring condition', id: '70' },
      xref: [
        { id: 'MONDO:0007220', db: 'MONDO', status: null, type: null, url: null },
        { id: 'C1862112', db: 'MedGen', status: null, type: null, url: null },
        { id: '93383', db: 'Orphanet', status: null, type: null, url: null },
        { type: 'MIM', id: '113000', db: 'OMIM', status: null, url: null }
      ]
    },
    {
      id: '5880',
      type: 'Disease',
      name: [
        {
          element_value: 'Autosomal recessive Robinow syndrome',
          type: 'Preferred',
          citation: null,
          comment: null,          
          xref: [{ id: 'MONDO:0009999', db: 'MONDO', status: null, type: null, url: null }]
        },
        {
          element_value: 'COSTOVERTEBRAL SEGMENTATION DEFECT WITH MESOMELIA',
          type: 'Alternate',
          citation: null,
          comment: null,
          xref: [{ type: 'MIM', id: '268310', db: 'OMIM', status: null, url: null }]
        },
        {
          element_value: 'COVESDEM SYNDROME',
          type: 'Alternate',
          citation: null,
          comment: null,
          xref: [{ type: 'MIM', id: '268310', db: 'OMIM', status: null, url: null }]
        },
        {
          element_value: 'ROBINOW SYNDROME, AUTOSOMAL RECESSIVE 1',
          type: 'Alternate',
          citation: null,
          comment: null,
          xref: [
            { type: 'MIM', id: '268310', db: 'OMIM', status: null, url: null },
            { type: 'Allelic variant', id: '602337.0010', db: 'OMIM', status: null, url: null },
            { type: 'Allelic variant', id: '602337.0011', db: 'OMIM', status: null, url: null },
            { type: 'Allelic variant', id: '602337.0012', db: 'OMIM', status: null, url: null },
            { type: 'Allelic variant', id: '602337.0006', db: 'OMIM', status: null, url: null },
            { type: 'Allelic variant', id: '602337.0004', db: 'OMIM', status: null, url: null },
            { type: 'Allelic variant', id: '602337.0005', db: 'OMIM', status: null, url: null },
            { type: 'Allelic variant', id: '602337.0007', db: 'OMIM', status: null, url: null }
          ]
        }
      ],
      symbol: [
        { element_value: 'RRS1', type: 'Preferred', citation: null, comment: null, xref: [{ type: 'MIM', id: '268310', db: 'OMIM', status: null, url: null }]},
        { element_value: 'RRS', type: 'Alternate', citation: null, comment: null, xref: null }
      ],
      attribute_set: [
        {
          attribute: {
            type: 'public definition',
            value: 'ROR2-related Robinow syndrome is characterized by distinctive craniofacial features, skeletal abnormalities, and other anomalies. Craniofacial features include macrocephaly, broad prominent forehead, low-set ears, ocular hypertelorism, prominent eyes, midface hypoplasia, short upturned nose with depressed nasal bridge and flared nostrils, large and triangular mouth with exposed incisors and upper gums, gum hypertrophy, misaligned teeth, ankyloglossia, and micrognathia. Skeletal abnormalities include short stature, mesomelic or acromesomelic limb shortening, hemivertebrae with fusion of thoracic vertebrae, and brachydactyly. Other common features include micropenis with or without cryptorchidism in males and reduced clitoral size and hypoplasia of the labia majora in females, renal tract abnormalities, and nail hypoplasia or dystrophy. The disorder is recognizable at birth or in early childhood.',
            date_value: null,
            integer_value: null
          },
          citation: null,
          comment: null,
          xref: [{ id: 'NBK1240', db: 'GeneReviews', status: null, type: null, url: null }]
        },
        {
          attribute: { type: 'GARD id', integer_value: 16568, date_value: null, value: null },
          citation: null,
          comment: null,
          xref: [{id: '16568', db: 'Office of Rare Diseases', status: null, type: null, url: null}]
        }
      ],
      trait_relationship: { type: 'co-occurring condition', id: '70' },
      citation: [{
        type: 'review',
        abbrev: 'GeneReviews',
        id: [
          { source: 'PubMed', id: '20301418', curie: 'PubMed:20301418' },
          { source: 'BookShelf', id: 'NBK1240', curie: 'BookShelf:NBK1240' }
        ],
        url: null,
        text: null
      }],
      comment: null,
      xref: [
        { id: 'MONDO:0009999', db: 'MONDO', status: null, type: null, url: null},
        { id: 'C5399974', db: 'MedGen', status: null, type: null, url: null },
        { id: '1507', db: 'Orphanet', status: null, type: null, url: null },
        { id: '97360', db: 'Orphanet', status: null, type: null, url: null },
        { type: 'MIM', id: '268310', db: 'OMIM', status: null, url: null }
      ]
    }
  ];
  expect(buildTraitsOutput(input)).toEqual(expectedOutput);
});

// // Tests for parseTrait
test('parseTraits should parse JSON input correctly', () => {
  const json = '{"Trait":[{"@ID":"1053","@Type":"Disease","Name":{"ElementValue":{"@Type":"Preferred","$":"Brachydactyly type B1"},"XRef":[{"@ID":"Brachydactyly+type+B1/7857","@DB":"Genetic Alliance"},{"@ID":"MONDO:0007220","@DB":"MONDO"}]},"Symbol":[{"ElementValue":{"@Type":"Preferred","$":"BDB1"},"XRef":{"@Type":"MIM","@ID":"113000","@DB":"OMIM"}},{"ElementValue":{"@Type":"Alternate","$":"BDB"},"XRef":{"@Type":"MIM","@ID":"113000","@DB":"OMIM"}}],"AttributeSet":[{"Attribute":{"@Type":"keyword","$":"ROR2-Related Disorders"}},{"Attribute":{"@Type":"GARD id","@integerValue":"18009"},"XRef":{"@ID":"18009","@DB":"Office of Rare Diseases"}}],"TraitRelationship":{"@Type":"co-occurring condition","@ID":"70"},"XRef":[{"@ID":"MONDO:0007220","@DB":"MONDO"},{"@ID":"C1862112","@DB":"MedGen"},{"@ID":"93383","@DB":"Orphanet"},{"@Type":"MIM","@ID":"113000","@DB":"OMIM"}]}]}';
  const expectedOutput = [
    {
      id: '1053',
      type: 'Disease',
      name: [{
        element_value: 'Brachydactyly type B1',
        type: 'Preferred',
        citation: null,
        comment: null,
        xref: [
          { id: 'Brachydactyly+type+B1/7857', db: 'Genetic Alliance', status: null, type: null, url: null },
          { id: 'MONDO:0007220', db: 'MONDO', status: null, type: null, url: null }
        ]
      }],
      symbol: [
        { element_value: 'BDB1', type: 'Preferred', citation: null, comment: null, xref: [{ type: 'MIM', id: '113000', db: 'OMIM', status: null, url: null }] },
        { element_value: 'BDB', type: 'Alternate', citation: null, comment: null, xref: [{ type: 'MIM', id: '113000', db: 'OMIM', status: null, url: null }] }
      ],
      attribute_set: [
        {attribute: { type: 'keyword', value: 'ROR2-Related Disorders', date_value: null, integer_value: null }, citation: null, comment: null, xref: null},
        {attribute: { type: 'GARD id', integer_value: 18009, date_value: null, value: null}, citation: null, comment: null, xref: [{ id: '18009', db: 'Office of Rare Diseases', status: null, type: null, url: null }]}
      ],
      citation: null,
      comment: null,
      trait_relationship: { type: 'co-occurring condition', id: '70' },  
      xref: [
        { id: 'MONDO:0007220', db: 'MONDO', status: null, type: null, url: null },
        { id: 'C1862112', db: 'MedGen', status: null, type: null, url: null },
        { id: '93383', db: 'Orphanet', status: null, type: null, url: null },
        { type: 'MIM', id: '113000', db: 'OMIM', status: null, url: null }
      ]
    }
  ];
  expect(parseTraits(json)).toEqual(expectedOutput);
});

test('parseTraits should throw error for invalid JSON input', () => {
  const json = 'invalid json';
  expect(() => parseTraits(json)).toThrow('Invalid JSON input');
});

// // Test for buildTraitSetOutput
test('buildTraitSetOutput should build TraitSetOutput correctly', () => {
  const input = {
    '@Type': 'Disease',
    '@ID': '8827',
    Trait: [
      {
        '@ID': '1053',
        '@Type': 'Disease',
        Name: {
          ElementValue: {
            '@Type': 'Preferred',
            '$': 'Brachydactyly type B1'
          },
          XRef: [
            {
              '@ID': 'Brachydactyly+type+B1/7857',
              '@DB': 'Genetic Alliance'
            },
            {
              '@ID': 'MONDO:0007220',
              '@DB': 'MONDO'
            }
          ]
        },
        Symbol: [
          {
            ElementValue: {
              '@Type': 'Preferred',
              '$': 'BDB1'
            },
            XRef: {
              '@Type': 'MIM',
              '@ID': '113000',
              '@DB': 'OMIM'
            }
          },
          {
            ElementValue: {
              '@Type': 'Alternate',
              '$': 'BDB'
            },
            XRef: {
              '@Type': 'MIM',
              '@ID': '113000',
              '@DB': 'OMIM'
            }
          }
        ],
        AttributeSet: [
          {
            Attribute: {
              '@Type': 'keyword',
              '$': 'ROR2-Related Disorders'
            }
          },
          {
            Attribute: {
              '@Type': 'GARD id',
              '@integerValue': '18009'
            },
            XRef: {
              '@ID': '18009',
              '@DB': 'Office of Rare Diseases'
            }
          }
        ],
        TraitRelationship: {
          '@Type': 'co-occurring condition',
          '@ID': '70'
        },
        XRef: [
          {
            '@ID': 'MONDO:0007220',
            '@DB': 'MONDO'
          },
          {
            '@ID': 'C1862112',
            '@DB': 'MedGen'
          },
          {
            '@ID': '93383',
            '@DB': 'Orphanet'
          },
          {
            '@Type': 'MIM',
            '@ID': '113000',
            '@DB': 'OMIM'
          }
        ]
      }
    ]
  };
  const expectedOutput = {
    type: 'Disease',
    id: '8827',
    trait: [
      {
        id: '1053',
        type: 'Disease',
        name: [{
          element_value: 'Brachydactyly type B1',
          type: 'Preferred',
          citation: null,
          comment: null,
          xref: [
            { id: 'Brachydactyly+type+B1/7857', db: 'Genetic Alliance', status: null, type: null, url: null },
            { id: 'MONDO:0007220', db: 'MONDO', status: null, type: null, url: null }
          ]
        }],
        symbol: [
          { element_value: 'BDB1', type: 'Preferred', citation: null, comment: null, xref: [{ type: 'MIM', id: '113000', db: 'OMIM', status: null, url: null }] },
          { element_value: 'BDB', type: 'Alternate', citation: null, comment: null, xref: [{ type: 'MIM', id: '113000', db: 'OMIM', status: null, url: null }] }  
        ],
        attribute_set: [
          {attribute: { type: 'keyword', value: 'ROR2-Related Disorders', date_value: null, integer_value: null }, citation: null, comment: null, xref: null},  
          {attribute: { type: 'GARD id', integer_value: 18009, date_value: null, value: null }, citation: null, comment: null, xref: [{ id: '18009', db: 'Office of Rare Diseases', status: null, type: null, url: null }]} 
        ],
        trait_relationship: { type: 'co-occurring condition', id: '70' },  
        citation: null,
        comment: null,
        xref: [
          { id: 'MONDO:0007220', db: 'MONDO', status: null, type: null, url: null },
          { id: 'C1862112', db: 'MedGen', status: null, type: null, url: null },
          { id: '93383', db: 'Orphanet', status: null, type: null, url: null },
          { type: 'MIM', id: '113000', db: 'OMIM', status: null, url: null }
        ]
      }
    ]
  };
  expect(buildTraitSetOutput(input)).toEqual(expectedOutput);
});

// Test for parseTraitSet
test('parseTraitSet should parse JSON input correctly', () => {
  const json = `{"TraitSet": {
    "@Type":"Disease",
    "@ID":"8827",
    "Trait":[{
      "@ID":"1053",
      "@Type":"Disease",
      "Name":{
        "ElementValue":{
          "@Type":"Preferred",
          "$":"Brachydactyly type B1"
        },
        "XRef":[{
          "@ID":"Brachydactyly+type+B1/7857","@DB":"Genetic Alliance"
        },{
          "@ID":"MONDO:0007220","@DB":"MONDO"
        }]
      },
      "Symbol":[{
        "ElementValue":{
          "@Type":"Preferred","$":"BDB1"
        },
        "XRef":{
          "@Type":"MIM","@ID":"113000","@DB":"OMIM"
        }
      },{
        "ElementValue":{
          "@Type":"Alternate","$":"BDB"
        },
        "XRef":{
          "@Type":"MIM","@ID":"113000","@DB":"OMIM"
        }
      }],
      "AttributeSet":[{
        "Attribute":{
          "@Type":"keyword","$":"ROR2-Related Disorders"
        }
      },{
        "Attribute":{
          "@Type":"GARD id","@integerValue":"18009"
        },
        "XRef":{"@ID":"18009","@DB":"Office of Rare Diseases"

        }
      }],
      "TraitRelationship":{
        "@Type":"co-occurring condition","@ID":"70"
      },
      "XRef":[{
        "@ID":"MONDO:0007220","@DB":"MONDO"
      },{
        "@ID":"C1862112","@DB":"MedGen"
      },{
        "@ID":"93383","@DB":"Orphanet"
      },{
        "@Type":"MIM","@ID":"113000","@DB":"OMIM"
      }]
    }]
  }}`;
  const expectedOutput = {
    type: 'Disease',
    id: '8827',
    trait: [
      {
        id: '1053',
        type: 'Disease',
        name: [{
          element_value: 'Brachydactyly type B1',
          type: 'Preferred',
          citation: null,
          comment: null,
          xref: [
            { id: 'Brachydactyly+type+B1/7857', db: 'Genetic Alliance', status: null, type: null, url: null},
            { id: 'MONDO:0007220', db: 'MONDO', status: null, type: null, url: null }
          ]
        }],
        symbol: [
          {element_value: 'BDB1', type: 'Preferred', xref: [{ type: 'MIM', id: '113000', db: 'OMIM', status: null, url: null }], citation: null, comment: null },
          {element_value: 'BDB', type: 'Alternate', xref: [{ type: 'MIM', id: '113000', db: 'OMIM', status: null, url: null }], citation: null, comment: null }
        ],
        attribute_set: [
          {attribute: { type: 'keyword', value: 'ROR2-Related Disorders', date_value: null, integer_value: null}, xref: null, citation: null, comment: null },
          {attribute: { type: 'GARD id', integer_value: 18009, date_value: null, value:null }, xref: [{ id: '18009', db: 'Office of Rare Diseases', status: null, type: null, url: null }], citation: null, comment: null } 
        ],
        citation: null,
        comment: null,
        trait_relationship: { type: 'co-occurring condition', id: '70' },
        xref: [
          { id: 'MONDO:0007220', db: 'MONDO', status: null, type: null, url: null },
          { id: 'C1862112', db: 'MedGen', status: null, type: null, url: null },
          { id: '93383', db: 'Orphanet', status: null, type: null, url: null },
          { type: 'MIM', id: '113000', db: 'OMIM', status: null, url: null }
        ]
      }
    ]
  };
  
  expect(parseTraitSet(json)).toEqual(expectedOutput);
});

test('parseTraitSet should throw error for invalid JSON input', () => {
  const json = 'invalid json';
  expect(() => parseTraitSet(json)).toThrow('Invalid JSON input');
});


//    {
//       "@ClinicalImpactAssertionType": "diagnostic", 
//       "@ClinicalImpactClinicalSignificance": "supports diagnosis", 
//       "@DateLastEvaluated": "2024-01-24", 
//       "@SubmissionCount": "1", 
//       "$": "Tier I - Strong"
//     }
test('buildDescriptionItemsOutput should build DescriptionItemsOutput correctly', () => {
  const json = {
    '@ClinicalImpactAssertionType': 'diagnostic', 
    '@ClinicalImpactClinicalSignificance': 'supports diagnosis', 
    '@DateLastEvaluated': '2024-01-24', 
    '@SubmissionCount': '1', 
    '$': 'Tier I - Strong'
  };
  const expectedOutput = [{
    clinical_impact_assertion_type: 'diagnostic',
    clinical_impact_clinical_significance: 'supports diagnosis',
    date_last_evaluated: new Date('2024-01-24T00:00:00.000Z'),
    num_submissions: 1,
    interp_description: 'Tier I - Strong'
  }];
  expect(buildDescriptionItemsOutput(json)).toEqual(expectedOutput);
});


test('buildAggDescriptionOutput should build AggDescriptionOutput correctly', () => {
  const json = {
    "Description": [
    {
      "@ClinicalImpactAssertionType": "diagnostic", 
      "@ClinicalImpactClinicalSignificance": "supports diagnosis", 
      "@DateLastEvaluated": "2024-01-24", 
      "@SubmissionCount": "1", 
      "$": "Tier I - Strong"
    }, 
    {
      "@ClinicalImpactAssertionType": "prognostic", 
      "@ClinicalImpactClinicalSignificance": "better outcome", 
      "@DateLastEvaluated": "2024-01-23", 
      "@SubmissionCount": "1", 
      "$": "Tier I - Strong"
    }
  ]};
  const expectedOutput = {
    description: [
      {
        clinical_impact_assertion_type: 'diagnostic',
        clinical_impact_clinical_significance: 'supports diagnosis',
        date_last_evaluated: new Date('2024-01-24T00:00:00.000Z'),
        num_submissions: 1,
        interp_description: 'Tier I - Strong'
      },
      {
        clinical_impact_assertion_type: 'prognostic',
        clinical_impact_clinical_significance: 'better outcome',
        date_last_evaluated: new Date('2024-01-23T00:00:00.000Z'),
        num_submissions: 1,
        interp_description: 'Tier I - Strong'
      }
    ]
  };
  expect(buildAggDescriptionOutput(json)).toEqual(expectedOutput);
});

