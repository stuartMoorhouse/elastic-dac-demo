# Product Requirement Prompts

This file contains the requirements for your project. Fill out each section with relevant details before running `/init` in Claude Code. Claude will use this information to generate your initial project structure and implementation.

## Objective

```
Create a demo environment for testing Elastic Security's Detection as Code functionality.


```

## What

```
Deploy the following resources using Terraform:

- One 8 GB RAM Elastic Cloud instance on GCP, Finland, with the name "elastic-cloud-production"
- One 8 GB RAM Elastic Cloud instance on GCP, Finland, with the name "elastic-cloud-development"
- One fork of the Elastic Cloud DAC repo https://github.com/elastic/detection-rules on the user's own GitHub 
- A clone of the DAC repo fork on the local machine 
- An Elastic GitHub integration on elastic-cloud-production that monitors the detection-rules fork


```

## Why

```
To test and demontrate a DAC workflow with Elastic's detection-rules

```

## Success criteria

```
The detection-rules CI can interact with both elastic-cloud-development and elastic-cloud-production
The local clone of the GitHub repository can interact with GitHub
The elastic-cloud-production instance is receiving logs from the users' GitHub


```

## Documentation and references (Optional)

```
https://github.com/elastic/detection-rules
https://registry.terraform.io/providers/elastic/ec/latest/docs

The secrets for Elastic Cloud and GitHub are in /.env



```
