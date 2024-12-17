VRS identifiers

Made up of a ga4gh namespace, a type prefix and an associated digest concatenated together to mke the vrs identifer.
The ga4gh centralized namespace was established for dealing with all ids and products across GA4GH.
Within the GKS working group products like VRS we decided that we needed to carve out our own sub-namespace like ga4gh.vrs.2 followed by the type prefix and ending with the digest.
adding the product specification and version, vrs.2, directly in the identifier was considered to be helpful in supporting both old and new instances, classes, schemas, docs, etc..


Impact on digest and identifiers from changing to a new identifier schema with versioning embedded.

- either change the type prefix with version
- or change the namespace and have that be versioned

both allow us to differntiate between versions of major version changes.

This is only for the overall identifier not for the schema namespaces which will include precise versioning information in its url

if some objects don't change digests between major releases then the identifer and digest wouldn't change. 

