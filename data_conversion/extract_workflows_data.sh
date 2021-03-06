#!/bin/bash
# set -ex

WORKFLOW_FILE=$1
WORKFLOW_CONTENTS_FILE=$2

if [ -z "$WORKFLOW_FILE" ] || [ -z "$WORKFLOW_CONTENTS_FILE" ]; then
  echo "Please supply a workflow and contents file"
  exit -1
fi
# get the workflow ids as an array
workflow_ids=($(tail -n +2 ${WORKFLOW_FILE} | cut -d',' -f1 | uniq))

CONFIG_DIR="${DATA_OUT_DIR}/configs"
mkdir -p $CONFIG_DIR
# store the configs in outputs
for workflow_id in "${workflow_ids[@]}"
do
  printf "\n###############-START WORKFLOW_ID:${workflow_id}-###############\n"

  # https://aggregation-caesar.zooniverse.org/Scripts.html#configure-the-extractors-and-reducers
  # we can add workflow major / minor version numbers here if needed
  # NOTE if you don't supply a version number it defaults to the max version
  # found in the supplied workflows.csv, we may have to change this behaviour
  panoptes_aggregation config $WORKFLOW_FILE $workflow_id -c $WORKFLOW_CONTENTS_FILE -d $CONFIG_DIR

  # get the extractor config we made above for use in data extraction
  extractor_configs=($(ls "${CONFIG_DIR}/Extractor_config_workflow_${workflow_id}_"*".yaml"))
  extractor_config=${extractor_configs[0]}

  # https://aggregation-caesar.zooniverse.org/Scripts.html#extracting-data
  classification_csv_file="${DATA_IN_DIR}/classifications.csv"
  export_suffix="workflow_${workflow_id}_classifications"
  printf "\n\n"
  printf "Exporting data for workflow: $workflow_id using extractor config: $extractor_config\n"
  panoptes_aggregation extract -d $DATA_OUT_DIR -O -o $export_suffix $classification_csv_file $extractor_config

  # only attempt convert the data if we've extracted some
  if [ $? -eq 0 ]; then
    # TODO: now convert each marking task has to have the point data converted to lat / lon
    # https://github.com/AroneyS/prn_data_extract
    printf "\n\n"
    printf "Converting the extract data to downstream IBCC format: $workflow_id\n"
    # TODO reflect on the exit code here and crazy warn if it doesn't process properly
    task_label_configs=($(ls "${CONFIG_DIR}/Task_labels_workflow_${workflow_id}_"*".yaml"))
    task_label_config=${task_label_configs[0]}
    python convert_to_ibcc.py \
      --points "outputs/point_extractor_by_frame_workflow_$workflow_id.csv" \
      --questions "outputs/question_extractor_workflow_$workflow_id.csv" \
      --subjects "inputs/subjects.csv" \
      --task-labels $task_label_config
    if [ $? -ne 0 ]; then
      printf "\nWARNING: Failed to convert the data for $workflow_id\n\n" >&2
    fi
  fi

  printf "###############-END WORKFLOW_ID:${workflow_id}-###############\n"
done
