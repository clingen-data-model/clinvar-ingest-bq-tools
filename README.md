# ClinVar Ingest BiqQuery tools

[![Node.js CI](https://github.com/clingen-data-model/clinvar-ingest-bq-tools/actions/workflows/node.js.yml/badge.svg)](https://github.com/clingen-data-model/clinvar-ingest-bq-tools/actions/workflows/node.js.yml)


## Table of Contents

- [ClinVar Ingest BiqQuery tools](#clinVar-ingest-biqquery-tools)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Building the Project](#building-the-project)
  - [Running Tests](#running-tests)
  - [Continuous Integration](#continuous-integration)
  - [Contributing](#contributing)
  - [License](#license)

## Introduction

This project contains the Typescript tools that are transformed into javascript and
used by BigQuery routines to transform the ClinVar Ingest fields that have not
been completely parsed from their json form.  Additionally, it provides tools that
derive HGVS from ClinVar fields, format dates and calculate nearest months for
aggregating data around ClinVar releases.

## Prerequisites

Before you begin, ensure you have met the following requirements:

- You have installed Node.js (>=14.x).
- You have a basic understanding of TypeScript and Node.js.
- You have a GitHub account.

## Installation

To set up the project locally, follow these steps:

1. **Clone the repository**:
    ```sh
    git clone https://github.com/clingen-data-model/clinvar-ingest-bq-tools.git
    cd your-repo-name
    ```

2. **Install dependencies**:
    ```sh
    npm install
    ```

## Building the Project

To compile the TypeScript code to JavaScript, run:

```sh
npx tsc
```

The compiled files will be output to the `dist` directory.

## Running Tests

This project uses Jest for testing. To run the tests, use the following command:

```sh
npm test
```

## Continuous Integration

This project uses GitHub Actions for continuous integration. The workflow is defined in
`.github/workflows/node.js.yml` and runs on every pull request to the `main` branch.
It includes the following steps:

- Checkout the repository
- Setup Node.js
- Install dependencies
- Compile TypeScript
- Run tests

You can view the status of the workflow [here](https://github.com/clingen-data-model/clinvar-ingest-bq-tools/actions).

## Contributing

To contribute to this project, follow these steps:

1. Fork the repository.
2. Create a new branch (`git checkout -b feature/YourFeature`).
3. Make your changes and commit them (`git commit -m 'Add some feature'`).
4. Push to the branch (`git push origin feature/YourFeature`).
5. Create a new Pull Request.

Please ensure your changes pass all tests and follow the project's coding standards.

## License
This project is licensed under the CC0 1.0 Universal License. See the [LICENSE](./LICENSE) file for details.
