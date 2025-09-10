#!/bin/bash

set -euo pipefail

INPUTS="environment=performance,image_tag=master,TEST=TEST"
BRANCH_NAME="master"

if [[ ! -z $INPUTS ]]; then
    FORMAT_INPUTS=$(echo ${INPUTS//,/'"', '"'})
    FORMAT_INPUTS=$(echo { '"'${FORMAT_INPUTS//=/'"': '"'}'"' })
fi

if [[ -z $FORMAT_INPUTS ]]; then
    echo 'exec_workflow_params='"'ref'"': '"'${BRANCH_NAME}'"''
else
    echo 'exec_workflow_params='"'ref'"': '"'${BRANCH_NAME}'"', '"'inputs'"': '"'${FORMAT_INPUTS}'"''
fi
