#!/bin/bash
#
# Define reusable functions for CI

start_instance()
{
  local instance_id="$1"
  echo "Starting instance ${instance_id}"
  corellium instance start "${instance_id}" --wait || true
}

wait_until_agent_ready()
{
  local instance_id="$1"
  local AGENT_READY_SLEEP_TIME='10'
  local project_id
  project_id="$(corellium instance get --instance "${instance_id}" | jq -r '.project')"
  local ready_status
  ready_status="$(corellium ready --instance "${instance_id}" --project "${project_id}" 2> /dev/null | jq -r '.ready')"

  while [ "${ready_status}" != 'true' ]; do
    echo "Agent is not ready yet. Checking again in ${AGENT_READY_SLEEP_TIME} seconds."
    sleep "${AGENT_READY_SLEEP_TIME}"
    ready_status="$(corellium ready --instance "${instance_id}" --project "${project_id}" | jq -r '.ready')"
  done
}

install_corellium_cafe()
{
  local instance_id="$1"
  local project_id
  project_id="$(corellium instance get --instance "${instance_id}" | jq -r '.project')"
  local ipa_url="https://www.corellium.com/hubfs/Corellium_Cafe.ipa"
  local ipa_filename
  ipa_filename="$(basename "${ipa_url}")"

  echo "Downloading ${ipa_filename}"
  wget --no-verbose "${ipa_url}"
  echo "Installing ${ipa_filename}"
  if ! corellium apps install --instance "${instance_id}" --project "${project_id}" --app "${ipa_filename}"; then
    echo "Error installing app" >&2
    exit 1
  fi
  echo "Successfully installed ${ipa_filename}"
}

run_matrix_cafe_checks()
{
  local instance_id="$1"

  echo "Creating MATRIX assessment"
  local assessment_id
  assessment_id="$(corellium matrix create-assessment --instance "${instance_id}" --bundle com.corellium.Cafe | jq -r '.id')"

  if [ -z "${assessment_id}" ]; then
    echo "Failed to create assessment" >&2
    exit 1
  fi
  echo "Created MATRIX assessment ${assessment_id}"

  echo "Starting MATRIX monitoring"
  corellium matrix start-monitor --instance "${instance_id}" --assessment "${assessment_id}"
  wait_for_assessment_status 'monitoring'

  echo "Stopping MATRIX monitoring"
  corellium matrix stop-monitor --instance "${instance_id}" --assessment "${assessment_id}"

  wait_for_assessment_status 'readyForTesting'

  echo "Running MATRIX test"
  corellium matrix test --instance "${instance_id}" --assessment "${assessment_id}"
  wait_for_assessment_status 'complete'

  local report_id
  report_id="$(corellium matrix get-assessment --instance "${instance_id}" --assessment "${assessment_id}" | jq -r '.reportId')"

  echo "Downloading MATRIX report ${report_id} as HTML"
  corellium matrix download-report --instance "${instance_id}" --assessment "${assessment_id}" > "matrix_report_${report_id}.html"

  echo "Downloading MATRIX report ${report_id} as JSON"
  corellium matrix download-report --instance "${instance_id}" --assessment "${assessment_id}" --format json > "matrix_report_${report_id}.json"

  echo "Finished MATRIX assessment ${assessmentid} with report ${report_id}."
}

delete_unauthorized_devices()
{
  local authorized_instances=()
  while IFS= read -r line; do
    authorized_instances+=("$(echo "${line}" | tr -d '\r\n')")
  done <<< "${AUTHORIZED_INSTANCES}"

  local corellium_devices
  # disable lint check since all values are assumed to be UUIDs
  #shellcheck disable=SC2207
  corellium_devices=($(corellium list | jq -r '.[].id'))

  for device in "${corellium_devices[@]}"; do
    local is_authorized='false'
    for authorized_device in "${authorized_instances[@]}"; do
      if [ "${device}" = "${authorized_device}" ]; then
        is_authorized='true'
        break
      fi
    done
    if [ "${is_authorized}" = 'false' ]; then
      echo "Deleting unauthorized instance ${device}"
      corellium instance delete "${device}" --wait
    fi
  done
}

start_demo_instances()
{
  local start_instances=()
  while IFS= read -r line; do
    start_instances+=("$(echo "${line}" | tr -d '\r\n')")
  done <<< "${START_INSTANCES}"

  for instance in "${start_instances[@]}"; do
    echo "Starting instance ${instance}"
    corellium instance start "${instance}" --wait || true
  done
}

stop_demo_instances()
{
  local stop_instances=()
  while IFS= read -r line; do
    stop_instances+=("$(echo "${line}" | tr -d '\r\n')")
  done <<< "${STOP_INSTANCES}"

  for instance in "${stop_instances[@]}"; do
    echo "Stopping instance ${instance}"
    corellium instance stop "${instance}" --wait || true
  done
}

kill_cafe_app_process()
{
  local instance_id="$1"
  local BUNDLE_ID='com.corellium.Cafe'
  curl -X POST "${CORELLIUM_API_ENDPOINT}/v1/instances/${instance_id}/agent/v1/app/apps/${BUNDLE_ID}/kill" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${CORELLIUM_API_TOKEN}"
}

get_assessment_status()
{
  local instance_id="$1"
  local assessment_id="$2"

  corellium matrix get-assessment --instance "${instance_id}" --assessment "${assessment_id}" | jq -r '.status'
}

wait_for_assessment_status()
{
  # declare parameters
  local INSTANCE_ID="$1"
  local ASSESSMENT_ID="$2"
  local TARGET_ASSESSMENT_STATUS="$3"

  # declare constants
  local SLEEP_TIME_DEFAULT='5'
  local SLEEP_TIME_FOR_TESTING='60'

  # validate parameter
  case "${TARGET_ASSESSMENT_STATUS}" in
    'complete' | 'failed' | 'monitoring' | 'readyForTesting' | 'startMonitoring' | 'stopMonitoring' | 'testing') ;;
    *)
      echo "Unsupported target status: '${TARGET_ASSESSMENT_STATUS}'. Exiting." >&2
      exit 1
      ;;
  esac

  echo "Waiting for assessment status of ${TARGET_ASSESSMENT_STATUS}"

  local current_assessment_status
  current_assessment_status="$(get_assessment_status "${INSTANCE_ID}" "${ASSESSMENT_ID}")"

  while [ "${current_assessment_status}" != "${TARGET_ASSESSMENT_STATUS}" ]; do
    case "${current_assessment_status}" in
      'failed')
        echo 'Detected a failed run. Exiting.' >&2
        exit 1
        ;;
      'monitoring')
        echo 'Cannot wait when status is monitoring.' >&2
        exit 1
        ;;
      'testing')
        sleep_time="${SLEEP_TIME_FOR_TESTING}"
        ;;
      *)
        sleep_time="${SLEEP_TIME_DEFAULT}"
        ;;
    esac

    printf 'Current status is %s and waiting for %s. Sleeping for %d seconds.' \
      "${current_assessment_status}" \
      "${TARGET_ASSESSMENT_STATUS}" \
      "${sleep_time}"
    sleep "${sleep_time}"
  done
}
