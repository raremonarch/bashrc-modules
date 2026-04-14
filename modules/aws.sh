#!/bin/bash
# Module: aws
# Version: 0.1.0
# Description: AWS CLI helper functions for SSO login and CodeArtifact auth
# BashMod Dependencies: none
# ~/.bashrc.d/aws.sh

aws-sso-login()
{
    if [ -z "$1" ]; then
        echo "Usage: aws-sso-login <profile>"
        return 1
    fi
    aws sso login --no-browser --profile "$1"
    export AWS_PROFILE="$1"
}

ca-login()
{
    export CODE_ARTIFACT_TOKEN=$(aws codeartifact get-authorization-token \
        --domain data-engineering \
        --domain-owner 323366779563 \
        --query authorizationToken \
        --output text)
    export PIP_EXTRA_INDEX_URL=https://aws:$CODE_ARTIFACT_TOKEN@data-engineering-323366779563.d.codeartifact.us-east-1.amazonaws.com/pypi/all-packages/simple/
    unset CODE_ARTIFACT_TOKEN
}
