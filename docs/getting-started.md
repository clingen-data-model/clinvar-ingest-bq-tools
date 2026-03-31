# Getting Started

This guide walks you through setting up the project locally, building the
TypeScript utilities, running the test suite, and previewing the documentation
site.

---

## Prerequisites

!!! note "Required tooling"
    - **Node.js** >= 14.x (includes `npm`)
    - **Git**
    - A basic understanding of TypeScript and Node.js

!!! tip "For deployment"
    If you plan to deploy SQL procedures or the Cloud Function you will also
    need:

    - A Google Cloud Platform project with BigQuery enabled
    - The `gcloud` CLI, authenticated against your project
    - Appropriate IAM permissions for BigQuery and Cloud Functions

---

## Clone the Repository

```sh
git clone https://github.com/clingen-data-model/clinvar-ingest-bq-tools.git
cd clinvar-ingest-bq-tools
```

---

## Install Dependencies

```sh
npm install
```

This installs the TypeScript compiler, Jest test framework, and all other
project dependencies declared in `package.json`.

---

## Build

Compile TypeScript source files to JavaScript:

```sh
npm run build
```

Alternatively, you can invoke the TypeScript compiler directly:

```sh
npx tsc
```

Compiled output is written to the `dist/` directory. These JavaScript files are
what BigQuery routines consume as UDFs.

---

## Run Tests

The project uses [Jest](https://jestjs.io/) for unit testing. Test files live
under the `test/` directory and include sample ClinVar XML data for
integration-style checks.

```sh
npm test
```

All tests must pass before a pull request can be merged (enforced by CI).

---

## Local Documentation Development

The documentation site is built with [MkDocs Material](https://squidfunch.github.io/mkdocs-material/).
To preview it locally:

1. Install MkDocs Material (a Python package):

    ```sh
    pip install mkdocs-material
    ```

2. Start the local development server:

    ```sh
    mkdocs serve
    ```

3. Open [http://127.0.0.1:8000](http://127.0.0.1:8000) in your browser. The
   site reloads automatically when you save changes to any file under `docs/`.

---

## What's Next?

- Read the [Architecture](architecture.md) overview to understand the repository
  layout and data flow.
- Browse the [SQL Scripts](sql-scripts.md) catalog if you need to work with
  BigQuery procedures.
- See [Contributing](contributing.md) for the development workflow and PR
  guidelines.
