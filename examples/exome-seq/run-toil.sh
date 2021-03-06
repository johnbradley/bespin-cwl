#!/bin/bash

# usage: ./run.sh exomeseq-01-preprocessing
#   expects exomeseq-01-preprocessing.json and exomeseq-01-preprocessing.cwl

WORKFLOW_NAME="$1"

SCRIPT_DIR=$(dirname "$0")
ROOT_DIR=$(readlink -f "${SCRIPT_DIR}/../..")
RUN_DATE=$(date +"%Y%m%d-%k%M%S")

WORKFLOWS_DIR=${ROOT_DIR}/workflows
DATA_ROOT=${ROOT_DIR}/data
LOG_ROOT=${ROOT_DIR}/log
JOBSTORE_ROOT=${DATA_ROOT}/jobstores

mkdir -p $JOBSTORE_ROOT

JOB_NAME="${WORKFLOW_NAME}-toil-${RUN_DATE}"
echo $JOB_NAME

OUT_DIR=${DATA_ROOT}/${JOB_NAME}/
LOG_DIR=${LOG_ROOT}/${JOB_NAME}/
JOBSTORE_DIR=$(mktemp -u -p ${JOBSTORE_ROOT}/)
WORK_DIR=$(mktemp -u -p ${DATA_ROOT}/work/)

mkdir -p $OUT_DIR
mkdir -p $LOG_DIR
mkdir -p $WORK_DIR

. /home/ubuntu/bespin-cwl/env-toil/bin/activate

echo "Starting toil on $(date)..." >(tee ${LOG_DIR}/${WORKFLOW_NAME}-err.log)
cwltoil \
  --writeLogs \
  --logFile ${LOG_DIR}/${WORKFLOW_NAME}-toil.log \
  --realTimeLogging \
  --logDebug \
  --outdir ${OUT_DIR} \
  --jobStore ${JOBSTORE_DIR} \
  --workDir ${WORK_DIR} \
  ${WORKFLOWS_DIR}/${WORKFLOW_NAME}.cwl \
  ${WORKFLOW_NAME}.json \
  > >(tee ${LOG_DIR}/${WORKFLOW_NAME}-out.log) \
  2> >(tee -a ${LOG_DIR}/${WORKFLOW_NAME}-err.log >&2)
echo "Finished toil on $(date)..." >(tee -a ${LOG_DIR}/${WORKFLOW_NAME}-err.log)
