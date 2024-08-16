const rewire = require('rewire');
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
    id: '123',
    source: 'Source1',
    url: 'http://example.com',
    text: 'Citation text',
    type: 'Type1',
    abbrev: 'Abbrev1',
    curie: 'Source1:123'
  };
  expect(buildCitationOutput(input)).toEqual(expectedOutput);
});

test('buildCitationsOutput should build an array of CitationOutput correctly', () => {
  const input = [
    { ID: { $: '123', '@Source': 'Source1' }, URL: { $: 'http://example.com' }, CitationText: { $: 'Citation text' }, '@Type': 'Type1', '@Abbrev': 'Abbrev1' }
  ];
  const expectedOutput = [
    {
      id: '123',
      source: 'Source1',
      url: 'http://example.com',
      text: 'Citation text',
      type: 'Type1',
      abbrev: 'Abbrev1',
      curie: 'Source1:123'
    }
  ];
  expect(buildCitationsOutput(input)).toEqual(expectedOutput);
});

test('parseCitations should parse JSON input correctly', () => {
  const json = '{"Citation":[{"ID":{"$":"123","@Source":"Source1"},"URL":{"$":"http://example.com"},"CitationText":{"$":"Citation text"},"@Type":"Type1","@Abbrev":"Abbrev1"}]}';
  const expectedOutput = [
    {
      id: '123',
      source: 'Source1',
      url: 'http://example.com',
      text: 'Citation text',
      type: 'Type1',
      abbrev: 'Abbrev1',
      curie: 'Source1:123'
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
      id: '123',
      source: 'Source1',
      url: 'http://example.com',
      text: 'Citation text',
      type: 'Type1',
      abbrev: 'Abbrev1',
      curie: 'Source1:123'
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
      id: '123',
      source: 'Source1',
      url: 'http://example.com',
      text: 'Citation text',
      type: 'Type1',
      abbrev: 'Abbrev1',
      curie: 'Source1:123'
    }],
    xref: [{ db: 'DB1', id: 'ID1', url: 'http://example.com', type: 'Type1', status: 'Status1' }],
    comment: [{ text: 'This is a comment', type: 'Type1', source: 'Source1' }]
  }];
  expect(buildAttributeSetsOutput(input)).toEqual(expectedOutput);
});

// Tests for parseAttributeSet
test('parseAttributeSet should parse JSON input correctly', () => {
  const json = '{"AttributeSet":[{"Attribute":{"@Type":"type1","$":"value1","@integerValue":"123","@dateValue":"2023-01-01T00:00:00Z"},"Citation":[{"ID":{"$":"123","@Source":"Source1"},"URL":{"$":"http://example.com"},"CitationText":{"$":"Citation text"},"@Type":"Type1","@Abbrev":"Abbrev1"}],"XRef":[{"@DB":"DB1","@ID":"ID1","@URL":"http://example.com","@Type":"Type1","@Status":"Status1"}],"Comment":[{"$":"This is a comment","@Type":"Type1","@DataSource":"Source1"}]}]}';
  const expectedOutput = [{
    attribute: { type: 'type1', value: 'value1', integer_value: 123, date_value: new Date('2023-01-01T00:00:00Z') },
    citation: [{
      id: '123',
      source: 'Source1',
      url: 'http://example.com',
      text: 'Citation text',
      type: 'Type1',
      abbrev: 'Abbrev1',
      curie: 'Source1:123'
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