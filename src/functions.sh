#!/bin/bash
#
# Define reusable functions for CI

start_instance() {
  local instance_id="$1"
  echo "Starting instance ${instance_id}"
  corellium instance start "${instance_id}" --wait || true
}

wait_until_agent_ready() {
  local instance_id="$1"
  local sleep_time=10
  local project_id
  project_id=$(corellium instance get --instance "${instance_id}" | jq -r '.project')
  local ready_status
  ready_status=$(corellium ready --instance "${instance_id}" --project "${project_id}" 2>/dev/null | jq -r '.ready')

  while [ "${ready_status}" != 'true' ]; do
    echo "Agent is not ready yet. Checking again in ${sleep_time} seconds."
    sleep "${sleep_time}"
    ready_status=$(corellium ready --instance "${instance_id}" --project "${project_id}" | jq -r '.ready')
  done
}

install_corellium_cafe() {
  local instance_id="$1"
  local project_id
  project_id=$(corellium instance get --instance "${instance_id}" | jq -r '.project')
  local ipa_url="https://www.corellium.com/hubfs/Corellium_Cafe.ipa"
  local ipa_filename
  ipa_filename=$(basename "${ipa_url}")

  echo "Downloading ${ipa_filename}"
  wget --no-verbose "${ipa_url}"
  echo "Installing ${ipa_filename}"
  corellium apps install --instance "${instance_id}" --project "${project_id}" --app "${ipa_filename}"

  if [ "$?" -gt 0 ]; then
    echo "Error installing app" >&2
    exit 1
  fi
  echo "Successfully installed ${ipa_filename}"
}

run_matrix_cafe_checks() {
  local instance_id="$1"
  echo "Creating MATRIX assessment"
  local assessment_id
  assessment_id=$(corellium matrix create-assessment --instance "${instance_id}" --bundle com.corellium.Cafe | jq -r '.id')

  if [ -z "${assessment_id}" ]; then
    echo "Failed to create assessment" >&2
    exit 1
  fi
  echo "Created MATRIX assessment ${assessment_id}"

  echo "Starting MATRIX monitoring"
  corellium matrix start-monitor --instance "${instance_id}" --assessment "${assessment_id}"

  echo "Waiting for monitoring to start"
  local assessment_status
  assessment_status=$(corellium matrix get-assessment --instance "${instance_id}" --assessment "${assessment_id}" | jq -r '.status')

  while [ "${assessment_status}" != 'monitoring' ]; do
    echo "Current assessment status is ${assessment_status}"
    sleep 5
    assessment_status=$(corellium matrix get-assessment --instance "${instance_id}" --assessment "${assessment_id}" | jq -r '.status')
  done

  echo "Stopping MATRIX monitoring"
  corellium matrix stop-monitor --instance "${instance_id}" --assessment "${assessment_id}"

  echo "Waiting for monitoring to stop"
  assessment_status=$(corellium matrix get-assessment --instance "${instance_id}" --assessment "${assessment_id}" | jq -r '.status')

  while [ "${assessment_status}" != 'readyForTesting' ]; do
    echo "Current assessment status is ${assessment_status}"
    sleep 5
    assessment_status=$(corellium matrix get-assessment --instance "${instance_id}" --assessment "${assessment_id}" | jq -r '.status')
  done

  echo "Running MATRIX test"
  corellium matrix test --instance "${instance_id}" --assessment "${assessment_id}"

  echo "Waiting for test to complete"
  assessment_status=$(corellium matrix get-assessment --instance "${instance_id}" --assessment "${assessment_id}" | jq -r '.status')

  while [ "${assessment_status}" != 'complete' ]; do
    echo "Current assessment status is ${assessment_status}"
    sleep 60
    assessment_status=$(corellium matrix get-assessment --instance "${instance_id}" --assessment "${assessment_id}" | jq -r '.status')
  done

  local report_id
  report_id=$(corellium matrix get-assessment --instance "${instance_id}" --assessment "${assessment_id}" | jq -r '.reportId')

  echo "Downloading MATRIX report ${report_id} as HTML"
  corellium matrix download-report --instance "${instance_id}" --assessment "${assessment_id}" > "matrix_report_${report_id}.html"

  echo "Downloading MATRIX report ${report_id} as JSON"
  corellium matrix download-report --instance "${instance_id}" --assessment "${assessment_id}" --format json > "matrix_report_${report_id}.json"
}

delete_unauthorized_devices() {
  local authorized_instances=()
  while IFS= read -r line; do
    authorized_instances+=("$(echo "${line}" | tr -d '\r\n')")
  done <<< "${AUTHORIZED_INSTANCES}"

  local corellium_devices
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

start_demo_instances() {
  local start_instances=()
  while IFS= read -r line; do
    start_instances+=("$(echo "${line}" | tr -d '\r\n')")
  done <<< "${START_INSTANCES}"

  for instance in "${start_instances[@]}"; do
    echo "Starting instance ${instance}"
    corellium instance start "${instance}" --wait || true
  done
}

stop_demo_instances() {
  local stop_instances=()
  while IFS= read -r line; do
    stop_instances+=("$(echo "${line}" | tr -d '\r\n')")
  done <<< "${STOP_INSTANCES}"

  for instance in "${stop_instances[@]}"; do
    echo "Stopping instance ${instance}"
    corellium instance stop "${instance}" --wait || true
  done
}

kill_app_process() {
  local instance_id="$1"
  local app_bundle_id="$2"
  curl -X POST "https://corelliumsales.enterprise.corellium.com/api/v1/instances/$1/agent/v1/app/apps/$2/kill" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${KEY_GOES_HERE}" 
}
