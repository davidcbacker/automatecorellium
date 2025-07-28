#!/bin/bash
#
# Define reusable functions for CI

check_env_vars()
{
  if [ -z "${CORELLIUM_API_ENDPOINT}" ]; then
    echo "CORELLIUM_API_ENDPOINT not set." >&2
    exit 1
  elif [ -z "${CORELLIUM_API_TOKEN}" ]; then
    echo "CORELLIUM_API_TOKEN not set." >&2
    exit 1
  fi
}

log_stdout()
{
  local friendly_date
  friendly_date="$(date +'%Y-%m-%dT%H:%M:%S')"
  if [ "$#" -eq 0 ]; then
    printf '[!] %s ERROR: No argument supplied to log_info.\n' \
      "${friendly_date}" \
      >&2
    exit 1
  fi
  for arg in "$@"; do
    printf '[+] %s  INFO: %s\n' \
      "${friendly_date}" \
      "${arg}"
  done
}

start_instance()
{
  local instance_id="$1"
  case "$(get_instance_status "${instance_id}")" in
    'on')
      log_stdout "Instance ${instance_id} is already on."
      ;;
    *)
      log_stdout "Starting instance ${instance_id}"
      corellium instance start "${instance_id}" --wait > /dev/null || true
      log_stdout "Started instance ${instance_id}"
      ;;
  esac
}

stop_instance()
{
  check_env_vars
  local instance_id="$1"
  case "$(get_instance_status "${instance_id}")" in
    'off')
      log_stdout "Instance ${instance_id} is already off."
      ;;
    *)
      log_stdout "Stopping instance ${instance_id}"
      # Fix if this causes nonzero exit status or stderr messages
      curl -X POST "${CORELLIUM_API_ENDPOINT}/api/v1/instances/${instance_id}/stop" \
        -H "Accept: application/json" \
        -H "Authorization: Bearer ${CORELLIUM_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"soft":true}'
      ;;
  esac
}

get_instance_status()
{
  local instance_id="$1"
  corellium instance get --instance "${instance_id}" | jq -r '.state'
}

get_instance_services_ip()
{
  local instance_id="$1"
  corellium instance get --instance "${instance_id}" | jq -r '.serviceIp'
}

wait_until_agent_ready()
{
  local instance_id="$1"
  local AGENT_READY_SLEEP_TIME='20'
  local INSTANCE_STATUS_ON='on'
  local PROJECT_ID
  PROJECT_ID="$(get_project_from_instance_id "${instance_id}")"

  local instance_status
  instance_status="$(get_instance_status "${instance_id}")"
  local ready_status
  ready_status="$(corellium ready --instance "${instance_id}" --project "${PROJECT_ID}" 2> /dev/null | jq -r '.ready')"

  while [ "${ready_status}" != 'true' ]; do
    if [ "${instance_status}" != "${INSTANCE_STATUS_ON}" ]; then
      log_stdout "Instance is ${instance_status} not ${INSTANCE_STATUS_ON}. Exiting" >&2
      exit 1
    fi
    log_stdout "Agent is not ready yet. Checking again in ${AGENT_READY_SLEEP_TIME} seconds."
    sleep "${AGENT_READY_SLEEP_TIME}"
    instance_status="$(get_instance_status "${instance_id}")"
    ready_status="$(corellium ready --instance "${instance_id}" --project "${PROJECT_ID}" 2> /dev/null | jq -r '.ready')"
  done
  log_stdout 'Virtual device agent is ready.'
}

kill_app()
{
  check_env_vars
  local instance_id="$1"
  local app_bundle_id="$2"
  if [ "$(is_app_running "${instance_id}" "${app_bundle_id}")" = 'true' ]; then
    curl -sX POST "${CORELLIUM_API_ENDPOINT}/api/v1/instances/${instance_id}/agent/v1/app/apps/${app_bundle_id}/kill" \
      -H "Accept: application/json" \
      -H "Authorization: Bearer ${CORELLIUM_API_TOKEN}"
  fi
}

kill_corellium_cafe_ios()
{
  local instance_id="$1"
  local app_bundle_id='com.corellium.Cafe'
  kill_app "${instance_id}" "${app_bundle_id}"
}

get_project_from_instance_id()
{
  local instance_id="$1"
  corellium instance get --instance "${instance_id}" | jq -r '.project'
}

install_app_from_url()
{
  local instance_id="$1"
  local app_url="$2"

  local PROJECT_ID
  PROJECT_ID="$(get_project_from_instance_id "${instance_id}")"
  local app_filename
  app_filename="$(basename "${app_url}")"

  log_stdout "Downloading ${app_filename}"
  wget --quiet "${app_url}"
  log_stdout "Installing ${app_filename}"
  if ! corellium apps install \
    --instance "${instance_id}" \
    --project "${PROJECT_ID}" \
    --app "${app_filename}" > /dev/null; then
    echo "Error installing app. Exiting." >&2
    exit 1
  fi
}

install_corellium_cafe_ios()
{
  local instance_id="$1"
  local app_url="https://www.corellium.com/hubfs/Corellium_Cafe.ipa"
  local cafe_ios_bundle_id='com.corellium.Cafe'

  kill_app "${instance_id}" "${cafe_ios_bundle_id}"
  install_app_from_url "${instance_id}" "${app_url}"
  echo "Successfully installed ${app_filename}"
}

is_app_running()
{
  local instance_id="$1"
  local app_bundle_id="$2"
  local PROJECT_ID
  PROJECT_ID="$(get_project_from_instance_id "${instance_id}")"

  corellium apps --project "${PROJECT_ID}" --instance "${instance_id}" |
    jq -r --arg id "${app_bundle_id}" '.[] | select(.bundleID == $id) | .running'
}

run_matrix_cafe_checks()
{
  local instance_id="$1"
  local MATRIX_STATUS_MONITORING='monitoring'
  local MATRIX_STATUS_READY_FOR_TESTING='readyForTesting'
  local MATRIX_STATUS_COMPLETED_TESTING='complete'

  log_stdout "Creating new MATRIX assessment"
  local assessment_id
  assessment_id="$(corellium matrix create-assessment --instance "${instance_id}" --bundle com.corellium.Cafe | jq -r '.id')"
  if [ -z "${assessment_id}" ]; then
    echo "Failed to create assessment" >&2
    return 1
  fi
  log_stdout "Created MATRIX assessment ${assessment_id}."

  log_stdout "Starting monitoring for MATRIX assessment ${assessment_id}."
  corellium matrix start-monitor \
    --instance "${instance_id}" \
    --assessment "${assessment_id}" \
    > /dev/null
  wait_for_assessment_status \
    "${instance_id}" \
    "${assessment_id}" \
    "${MATRIX_STATUS_MONITORING}" ||
    return 1
  log_stdout "MATRIX assessment ${assessment_id} is ${MATRIX_STATUS_MONITORING}."

  sleep 60

  log_stdout "Stopping monitoring for MATRIX assessment ${assessment_id}."
  corellium matrix stop-monitor \
    --instance "${instance_id}" \
    --assessment "${assessment_id}" \
    > /dev/null
  wait_for_assessment_status \
    "${instance_id}" \
    "${assessment_id}" \
    "${MATRIX_STATUS_READY_FOR_TESTING}" ||
    return 1
  log_stdout "MATRIX assessment ${assessment_id} is ${MATRIX_STATUS_READY_FOR_TESTING}."

  log_stdout "Running test for MATRIX assessment ${assessment_id}."
  corellium matrix test \
    --instance "${instance_id}" \
    --assessment "${assessment_id}" \
    > /dev/null
  wait_for_assessment_status \
    "${instance_id}" \
    "${assessment_id}" \
    "${MATRIX_STATUS_COMPLETED_TESTING}" ||
    return 1
  log_stdout "MATRIX assessment ${assessment_id} is ${MATRIX_STATUS_COMPLETED_TESTING}."

  kill_corellium_cafe_ios "${instance_id}"

  local report_id
  report_id="$(corellium matrix get-assessment --instance "${instance_id}" --assessment "${assessment_id}" | jq -r '.reportId')"
  log_stdout "Downloading MATRIX report ${report_id} as HTML"
  corellium matrix download-report --instance "${instance_id}" --assessment "${assessment_id}" > "matrix_report_${report_id}.html"
  log_stdout "Downloading MATRIX report ${report_id} as JSON"
  corellium matrix download-report --instance "${instance_id}" --assessment "${assessment_id}" --format json > "matrix_report_${report_id}.json"

  log_stdout "Finished report ${report_id} for MATRIX assessment ${assessment_id}."
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
      log_stdout "Deleting unauthorized instance ${device}"
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
    log_stdout "Stopping instance ${instance}"
    corellium instance stop "${instance}" --wait || true
  done
}

get_assessment_status()
{
  local instance_id="$1"
  local assessment_id="$2"
  corellium matrix get-assessment --instance "${instance_id}" --assessment "${assessment_id}" | jq -r '.status'
}

download_file_to_local_path()
{
  local INSTANCE_ID="$1"
  local DOWNLOAD_PATH="$2"
  local LOCAL_SAVE_PATH="$3"
  # replace '/' with '%2F' using parameter expansion
  local encoded_download_path="${DOWNLOAD_PATH//\//%2F}"

  curl -X GET "${CORELLIUM_API_ENDPOINT}/api/v1/instances/${INSTANCE_ID}/agent/v1/file/device/${encoded_download_path}" \
    -H "Accept: application/octet-stream" \
    -H "Authorization: Bearer ${CORELLIUM_API_TOKEN}" \
    -o "${LOCAL_SAVE_PATH}"
}

save_vpn_config_to_local_path()
{
  local INSTANCE_ID="$1"
  local LOCAL_SAVE_PATH="$2"
  local PROJECT_ID
  PROJECT_ID="$(get_project_from_instance_id "${INSTANCE_ID}")"
  corellium project vpnConfig --project "${PROJECT_ID}" --path "${LOCAL_SAVE_PATH}"
}

wait_for_assessment_status()
{
  local INSTANCE_ID="$1"
  local ASSESSMENT_ID="$2"
  local TARGET_ASSESSMENT_STATUS="$3"
  local SLEEP_TIME_DEFAULT='2'
  local SLEEP_TIME_FOR_TESTING='60'

  case "${TARGET_ASSESSMENT_STATUS}" in
    'complete' | 'failed' | 'monitoring' | 'readyForTesting' | 'startMonitoring' | 'stopMonitoring' | 'testing') ;;
    *)
      echo "Unsupported target status: '${TARGET_ASSESSMENT_STATUS}'. Exiting." >&2
      exit 1
      ;;
  esac

  local current_assessment_status
  current_assessment_status="$(get_assessment_status "${INSTANCE_ID}" "${ASSESSMENT_ID}")"
  local last_assessment_status=''

  while [ "${current_assessment_status}" != "${TARGET_ASSESSMENT_STATUS}" ]; do
    case "${current_assessment_status}" in
      'failed')
        echo "Detected a failed run. Last state was '${last_assessment_status}'. Exiting." >&2
        return 1
        ;;
      'monitoring')
        echo 'Cannot wait when status is monitoring. Exiting.' >&2
        return 1
        ;;
      'testing')
        sleep_time="${SLEEP_TIME_FOR_TESTING}"
        ;;
      *)
        sleep_time="${SLEEP_TIME_DEFAULT}"
        ;;
    esac

    log_stdout "Status is ${current_assessment_status} and target is ${TARGET_ASSESSMENT_STATUS}. Wait ${sleep_time} seconds."
    sleep "${sleep_time}"

    last_assessment_status="${current_assessment_status}"
    current_assessment_status="$(get_assessment_status "${INSTANCE_ID}" "${ASSESSMENT_ID}")"
  done
}

install_usbfluxd_and_dependencies()
{
  local usbfluxd_apt_deps=(
    avahi-daemon
    build-essential
    git
    libimobiledevice6
    libimobiledevice-utils
    libtool
    pkg-config
    python3-dev
    usbmuxd
  )

  local usbfluxd_compile_dep_urls=(
    'https://github.com/libimobiledevice/libplist'
    'https://github.com/corellium/usbfluxd'
  )

  log_stdout 'Installing apt-get dependencies.'
  sudo apt-get -qq update
  for dep in "${usbfluxd_apt_deps[@]}"; do
    if sudo apt-get install -y "${dep}" > /dev/null; then
      log_stdout "Installed ${dep}."
    else
      echo "Failed to install ${dep}." >&2
      sudo apt-get -qq install -y "${dep}"
      exit 1
    fi
  done
  log_stdout 'Installed apt-get dependencies.'

  local temp_compile_dir
  temp_compile_dir="$(mktemp -d)"

  cd "${temp_compile_dir}/" || exit 1
  for compile_dep_url in "${usbfluxd_compile_dep_urls[@]}"; do
    compile_dep_name="$(basename "${compile_dep_url}")"
    log_stdout "Cloning ${compile_dep_name}."
    git clone "${compile_dep_url}" "${compile_dep_name}"
    cd "${temp_compile_dir}/${compile_dep_name}/" || exit 1
    log_stdout "Generating Makefile for ${compile_dep_name}."
    ./autogen.sh
    log_stdout "Building ${compile_dep_name}."
    make -j "$(nproc)"
    log_stdout "Installing ${compile_dep_name}."
    sudo make install
    cd ../
    log_stdout "Deleting compile dir for ${compile_dep_name}."
    rm -rf "${compile_dep_name:?}/"
  done

  command -v usbfluxd
  command -v usbfluxctl

  cd "${HOME}/" || exit 1
  rm -rf "${temp_compile_dir:?}/"
}

run_usbfluxd_and_dependencies()
{
  sudo systemctl start usbmuxd
  sudo systemctl status usbmuxd
  sudo avahi-daemon &
  sudo usbfluxd -f -n &
}

add_instance_to_usbfluxd()
{
  local INSTANCE_ID="$1"
  local USBFLUXD_PORT='5000'
  local INSTANCE_SERVICES_IP
  INSTANCE_SERVICES_IP="$(get_instance_services_ip "${INSTANCE_ID}")"
  usbfluxctl add "${INSTANCE_SERVICES_IP}:${USBFLUXD_PORT}"
}
