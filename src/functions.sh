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
  local FRIENDLY_DATE
  FRIENDLY_DATE="$(date +'%Y-%m-%dT%H:%M:%S')"
  if [ "$#" -gt 0 ]; then
    for arg in "$@"; do
      printf '[+] %s  INFO: %s\n' "${FRIENDLY_DATE}" "${arg}"
    done
  else
    log_error 'No argument supplied to log_stdout.'
    exit 1
  fi
}

log_error()
{
  local FRIENDLY_DATE
  FRIENDLY_DATE="$(date +'%Y-%m-%dT%H:%M:%S')"
  if [ "$#" -gt 0 ]; then
    for arg in "$@"; do
      printf '[!] %s  ERR: %s\n' "${FRIENDLY_DATE}" "${arg}" >&2
    done
  else
    printf '[!] %s  ERR: No argument supplied to log_error.\n' \
      "${FRIENDLY_DATE}" >&2
  fi
}

log_warn()
{
  local FRIENDLY_DATE
  FRIENDLY_DATE="$(date +'%Y-%m-%dT%H:%M:%S')"
  if [ "$#" -gt 0 ]; then
    for arg in "$@"; do
      printf '[!] %s  WARN: %s\n' "${FRIENDLY_DATE}" "${arg}" >&2
    done
  else
    log_error 'No argument supplied to log_warn'
  fi
}

does_instance_exist()
{
  local INSTANCE_ID="$1"
  if corellium instance get --instance "${INSTANCE_ID}" 2> /dev/null |
    jq -e --arg id "${INSTANCE_ID}" 'select(.id == $id)' > /dev/null; then
    return 0
  else
    log_warn "Instance ${INSTANCE_ID} does not exist."
    return 1
  fi
}

create_instance()
{
  local HARDWARE_FLAVOR="$1"
  local FIRMWARE_VERSION="$2"
  local FIRMWARE_BUILD="$3"
  local PROJECT_ID="$4"
  local NEW_INSTANCE_NAME
  NEW_INSTANCE_NAME="MATRIX Automation $(date '+%Y-%m-%d') ${RANDOM}"
  # Avoid using --wait option here since it will wait for agent ready
  # Better to create instance first then install local deps then wait

  if [ "${HARDWARE_FLAVOR}" = 'ranchu' ]; then
    CREATE_INSTANCE_REQUEST_DATA=$(
      cat << EOF
{
  "project": "${PROJECT_ID}",
  "name": "${NEW_INSTANCE_NAME}",
  "flavor": "${HARDWARE_FLAVOR}",
  "os": "${FIRMWARE_VERSION}",
  "osbuild": "${FIRMWARE_BUILD}",
  "bootOptions": {"cores": 4,"ram": 4096}
}
EOF
    )
  else
    CREATE_INSTANCE_REQUEST_DATA=$(
      cat << EOF
{
  "project": "${PROJECT_ID}",
  "name": "${NEW_INSTANCE_NAME}",
  "flavor": "${HARDWARE_FLAVOR}",
  "os": "${FIRMWARE_VERSION}",
  "osbuild": "${FIRMWARE_BUILD}"
}
EOF
    )
  fi

  check_env_vars
  curl -X POST "${CORELLIUM_API_ENDPOINT}/api/v1/instances" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${CORELLIUM_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${CREATE_INSTANCE_REQUEST_DATA}" |
    jq -r .id || {
    log_error "Failed to create new instance in project ${PROJECT_ID}." >&2
    log_error "Hardware was ${HARDWARE_FLAVOR} running ${FIRMWARE_VERSION} (${FIRMWARE_BUILD})." >&2
    exit 1
  }
}
delete_instance()
{
  local INSTANCE_ID="$1"
  log_stdout "Deleting instance ${INSTANCE_ID}."
  corellium instance delete "${INSTANCE_ID}" > /dev/null || {
    log_error "Failed to delete instance ${INSTANCE_ID}." >&2
    exit 1
  }
  log_stdout "Deleted instance ${INSTANCE_ID}."
}

start_instance()
{
  local INSTANCE_ID="$1"
  local TARGET_INSTANCE_STATUS_ON='on'
  local TARGET_INSTANCE_STATUS_CREATING='creating'
  does_instance_exist "${INSTANCE_ID}" || exit 1
  case "$(get_instance_status "${INSTANCE_ID}")" in
    "${TARGET_INSTANCE_STATUS_ON}")
      log_stdout "Instance ${INSTANCE_ID} is already ${TARGET_INSTANCE_STATUS_ON}."
      ;;
    "${TARGET_INSTANCE_STATUS_CREATING}")
      log_stdout "Instance ${INSTANCE_ID} is ${TARGET_INSTANCE_STATUS_CREATING}. Waiting for ${TARGET_INSTANCE_STATUS_ON} state."
      wait_for_instance_status "${INSTANCE_ID}" "${TARGET_INSTANCE_STATUS_ON}"
      log_stdout "Instance ${INSTANCE_ID} is ${TARGET_INSTANCE_STATUS_ON}."
      ;;
    *)
      log_stdout "Starting instance ${INSTANCE_ID}"
      corellium instance start "${INSTANCE_ID}" --wait > /dev/null
      log_stdout "Instance ${INSTANCE_ID} is ${TARGET_INSTANCE_STATUS_ON}."
      ;;
  esac
}

stop_instance()
{
  local INSTANCE_ID="$1"
  local TARGET_INSTANCE_STATUS_OFF='off'
  local TARGET_INSTANCE_STATUS_CREATING='creating'
  does_instance_exist "${INSTANCE_ID}" || exit 1
  case "$(get_instance_status "${INSTANCE_ID}")" in
    "${TARGET_INSTANCE_STATUS_OFF}")
      log_stdout "Instance ${INSTANCE_ID} is already ${TARGET_INSTANCE_STATUS_OFF}."
      ;;
    "${TARGET_INSTANCE_STATUS_CREATING}")
      log_stdout "Instance ${INSTANCE_ID} is ${TARGET_INSTANCE_STATUS_CREATING}. Waiting for ${TARGET_INSTANCE_STATUS_ON} state."
      wait_for_instance_status "${INSTANCE_ID}" "${TARGET_INSTANCE_STATUS_ON}"
      log_stdout "Instance ${INSTANCE_ID} is ${TARGET_INSTANCE_STATUS_ON}."
      log_stdout "Stopping instance ${INSTANCE_ID}"
      corellium instance stop "${INSTANCE_ID}" --wait > /dev/null
      log_stdout "Instance ${INSTANCE_ID} is ${TARGET_INSTANCE_STATUS_OFF}."
      ;;
    *)
      log_stdout "Stopping instance ${INSTANCE_ID}"
      corellium instance stop "${INSTANCE_ID}" --wait > /dev/null
      log_stdout "Instance ${INSTANCE_ID} is ${TARGET_INSTANCE_STATUS_OFF}."
      ;;
  esac
}

soft_stop_instance()
{
  local INSTANCE_ID="$1"
  local TARGET_INSTANCE_STATUS_OFF='off'
  does_instance_exist "${INSTANCE_ID}" || exit 1
  case "$(get_instance_status "${INSTANCE_ID}")" in
    "${TARGET_INSTANCE_STATUS_OFF}")
      log_stdout "Instance ${INSTANCE_ID} is already ${TARGET_INSTANCE_STATUS_OFF}."
      ;;
    *)
      log_stdout "Stopping instance ${INSTANCE_ID}."
      check_env_vars
      curl --silent -X POST "${CORELLIUM_API_ENDPOINT}/api/v1/instances/${INSTANCE_ID}/stop" \
        -H "Accept: application/json" \
        -H "Authorization: Bearer ${CORELLIUM_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"soft":true}'
      log_stdout "Soft stopped instance ${INSTANCE_ID}. Waiting for ${TARGET_INSTANCE_STATUS_OFF} state."
      wait_for_instance_status "${INSTANCE_ID}" "${TARGET_INSTANCE_STATUS_OFF}"
      log_stdout "Instance ${INSTANCE_ID} is ${TARGET_INSTANCE_STATUS_OFF}."
      ;;
  esac
}

get_instance_status()
{
  local INSTANCE_ID="$1"
  local GET_INSTANCE_RESPONSE_JSON INSTANCE_STATE
  GET_INSTANCE_RESPONSE_JSON="$(corellium instance get --instance "${INSTANCE_ID}")" || {
    log_error "Failed to get details for instance ${INSTANCE_ID}." >&2
    return
  }
  INSTANCE_STATE="$(echo "${GET_INSTANCE_RESPONSE_JSON}" | jq -r '.state')" || {
    log_error "Failed to parse get details JSON response for instance ${INSTANCE_ID}." >&2
    exit 1
  }
  echo "${INSTANCE_STATE}"
}

get_instance_services_ip()
{
  local instance_id="$1"
  corellium instance get --instance "${instance_id}" | jq -r '.serviceIp'
}

wait_until_agent_ready()
{
  local instance_id="$1"
  local AGENT_READY_SLEEP_TIME='15'
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
  local INSTANCE_ID="$1"
  local APP_BUNDLE_ID="$2"
  if [ "$(is_app_running "${INSTANCE_ID}" "${APP_BUNDLE_ID}")" = 'true' ]; then
    log_stdout "Killing running app ${APP_BUNDLE_ID}"
    if curl --silent -X POST \
      "${CORELLIUM_API_ENDPOINT}/api/v1/instances/${INSTANCE_ID}/agent/v1/app/apps/${APP_BUNDLE_ID}/kill" \
      -H "Accept: application/json" \
      -H "Authorization: Bearer ${CORELLIUM_API_TOKEN}"; then
      log_stdout "Killed running app ${APP_BUNDLE_ID}"
    else
      echo "Error killing app ${APP_BUNDLE_ID}. Exiting." >&2
      exit 1
    fi
  fi
}

kill_corellium_cafe_android()
{
  local INSTANCE_ID="$1"
  local CORELLIUM_CAFE_BUNDLE_ID='com.corellium.cafe'
  kill_app "${INSTANCE_ID}" "${CORELLIUM_CAFE_BUNDLE_ID}"
}

kill_corellium_cafe_ios()
{
  local INSTANCE_ID="$1"
  local CORELLIUM_CAFE_BUNDLE_ID='com.corellium.Cafe'
  kill_app "${INSTANCE_ID}" "${CORELLIUM_CAFE_BUNDLE_ID}"
}

get_project_from_instance_id()
{
  local INSTANCE_ID="$1"
  corellium instance get --instance "${INSTANCE_ID}" | jq -r '.project'
}

install_app_from_url()
{
  local INSTANCE_ID="$1"
  local APP_URL="$2"

  local PROJECT_ID
  PROJECT_ID="$(get_project_from_instance_id "${INSTANCE_ID}")"
  local APP_FILENAME
  APP_FILENAME="$(basename "${APP_URL}")"

  log_stdout "Downloading ${APP_FILENAME}"
  if wget --quiet "${APP_URL}"; then
    log_stdout "Downloaded ${APP_FILENAME}"
  else
    echo "Error downloading app ${APP_FILENAME}. Exiting." >&2
    exit 1
  fi

  log_stdout "Installing ${APP_FILENAME}"
  if corellium apps install \
    --instance "${INSTANCE_ID}" \
    --project "${PROJECT_ID}" \
    --app "${APP_FILENAME}" > /dev/null; then
    log_stdout "Installed ${APP_FILENAME}"
  else
    echo "Error installing app ${APP_FILENAME}. Exiting." >&2
    exit 1
  fi
}

install_corellium_cafe_android()
{
  local INSTANCE_ID="$1"
  local CORELLIUM_CAFE_ANDROID_URL="https://www.corellium.com/hubfs/Corellium_Cafe.apk"
  local CORELLIUM_CAFE_BUNDLE_ID='com.corellium.cafe'
  kill_app "${INSTANCE_ID}" "${CORELLIUM_CAFE_BUNDLE_ID}"
  install_app_from_url "${INSTANCE_ID}" "${CORELLIUM_CAFE_ANDROID_URL}"
}

install_corellium_cafe_ios()
{
  local INSTANCE_ID="$1"
  local CORELLIUM_CAFE_IOS_URL="https://www.corellium.com/hubfs/Corellium_Cafe.ipa"
  local CORELLIUM_CAFE_BUNDLE_ID='com.corellium.Cafe'
  kill_app "${INSTANCE_ID}" "${CORELLIUM_CAFE_BUNDLE_ID}"
  install_app_from_url "${INSTANCE_ID}" "${CORELLIUM_CAFE_IOS_URL}"
}

install_appium_runner_ios()
{
  local INSTANCE_ID="$1"
  local APPIUM_RUNNER_IOS_URL="https://www.corellium.com/hubfs/Blog%20Attachments/WebDriverAgentRunner-Runner.ipa"
  local APPIUM_RUNNER_IOS_BUNDLE_ID='org.appium.WebDriverAgentRunner.xctrunner'
  kill_app "${INSTANCE_ID}" "${APPIUM_RUNNER_IOS_BUNDLE_ID}"
  install_app_from_url "${INSTANCE_ID}" "${APPIUM_RUNNER_IOS_URL}"
}

launch_app()
{
  local INSTANCE_ID="$1"
  local APP_BUNDLE_ID="$2"
  local PROJECT_ID
  PROJECT_ID="$(get_project_from_instance_id "${INSTANCE_ID}")"
  kill_app "${INSTANCE_ID}" "${APP_BUNDLE_ID}"
  log_stdout "Launching app ${APP_BUNDLE_ID}"
  if corellium apps open \
    --instance "${INSTANCE_ID}" \
    --project "${PROJECT_ID}" \
    --bundle "${APP_BUNDLE_ID}" > /dev/null; then
    log_stdout "Launched app ${APP_BUNDLE_ID}"
  else
    echo "Error launching app ${APP_BUNDLE_ID}. Exiting." >&2
    exit 1
  fi
}

launch_appium_runner_ios()
{
  local INSTANCE_ID="$1"
  local APPIUM_RUNNER_IOS_BUNDLE_ID='org.appium.WebDriverAgentRunner.xctrunner'
  launch_app "${INSTANCE_ID}" "${APPIUM_RUNNER_IOS_BUNDLE_ID}"
}

unlock_instance()
{
  local INSTANCE_ID="$1"
  log_stdout "Unlocking instance ${INSTANCE_ID}."
  corellium instance unlock --instance "${INSTANCE_ID}" > /dev/null
  log_stdout "Unlocked instance ${INSTANCE_ID}."
}

is_app_running()
{
  local INSTANCE_ID="$1"
  local APP_BUNDLE_ID="$2"
  local PROJECT_ID
  PROJECT_ID="$(get_project_from_instance_id "${INSTANCE_ID}")"
  corellium apps --project "${PROJECT_ID}" --instance "${INSTANCE_ID}" |
    jq -r --arg id "${APP_BUNDLE_ID}" '.[] | select(.bundleID == $id) | .running'
}

create_matrix_assessment()
{
  local INSTANCE_ID="$1"
  local APP_BUNDLE_ID="$2"
  corellium matrix create-assessment --instance "${INSTANCE_ID}" --bundle "${APP_BUNDLE_ID}" | jq -r '.id'
}

start_matrix_monitoring()
{
  local INSTANCE_ID="$1"
  local MATRIX_ASSESSMENT_ID="$2"
  local MATRIX_STATUS_MONITORING='monitoring'
  log_stdout "Starting monitoring for MATRIX assessment ${MATRIX_ASSESSMENT_ID}."
  corellium matrix start-monitor \
    --instance "${INSTANCE_ID}" \
    --assessment "${MATRIX_ASSESSMENT_ID}" \
    > /dev/null
  wait_for_assessment_status \
    "${INSTANCE_ID}" \
    "${MATRIX_ASSESSMENT_ID}" \
    "${MATRIX_STATUS_MONITORING}" ||
    return 1
  log_stdout "MATRIX assessment ${MATRIX_ASSESSMENT_ID} is ${MATRIX_STATUS_MONITORING}."
}

stop_matrix_monitoring()
{
  local INSTANCE_ID="$1"
  local MATRIX_ASSESSMENT_ID="$2"
  local MATRIX_STATUS_READY_FOR_TESTING='readyForTesting'
  log_stdout "Stopping monitoring for MATRIX assessment ${MATRIX_ASSESSMENT_ID}."
  corellium matrix stop-monitor \
    --instance "${INSTANCE_ID}" \
    --assessment "${MATRIX_ASSESSMENT_ID}" \
    > /dev/null
  wait_for_assessment_status \
    "${INSTANCE_ID}" \
    "${MATRIX_ASSESSMENT_ID}" \
    "${MATRIX_STATUS_READY_FOR_TESTING}" ||
    return 1
  log_stdout "MATRIX assessment ${MATRIX_ASSESSMENT_ID} is ${MATRIX_STATUS_READY_FOR_TESTING}."
}

test_matrix_evidence()
{
  local INSTANCE_ID="$1"
  local MATRIX_ASSESSMENT_ID="$2"
  local MATRIX_STATUS_COMPLETE='complete'
  log_stdout "Running test for MATRIX assessment ${MATRIX_ASSESSMENT_ID}."
  corellium matrix test \
    --instance "${INSTANCE_ID}" \
    --assessment "${MATRIX_ASSESSMENT_ID}" \
    > /dev/null
  wait_for_assessment_status \
    "${INSTANCE_ID}" \
    "${MATRIX_ASSESSMENT_ID}" \
    "${MATRIX_STATUS_COMPLETE}" ||
    return 1
  log_stdout "MATRIX assessment ${MATRIX_ASSESSMENT_ID} is ${MATRIX_STATUS_COMPLETE}."
}

get_matrix_report_id()
{
  local INSTANCE_ID="$1"
  local MATRIX_ASSESSMENT_ID="$2"
  corellium matrix get-assessment --instance "${INSTANCE_ID}" --assessment "${MATRIX_ASSESSMENT_ID}" | jq -r '.reportId'
}

download_matrix_report_html_to_path()
{
  local INSTANCE_ID="$1"
  local MATRIX_ASSESSMENT_ID="$2"
  local MATRIX_REPORT_DOWNLOAD_PATH="$3"
  log_stdout "Downloading MATRIX assessment ${MATRIX_ASSESSMENT_ID} report as HTML"
  corellium matrix download-report --instance "${INSTANCE_ID}" --assessment "${MATRIX_ASSESSMENT_ID}" > "${MATRIX_REPORT_DOWNLOAD_PATH}"
}

download_matrix_report_json_to_path()
{
  local INSTANCE_ID="$1"
  local MATRIX_ASSESSMENT_ID="$2"
  local MATRIX_REPORT_DOWNLOAD_PATH="$3"
  log_stdout "Downloading MATRIX assessment ${MATRIX_ASSESSMENT_ID} report as JSON"
  corellium matrix download-report \
    --instance "${INSTANCE_ID}" \
    --assessment "${MATRIX_ASSESSMENT_ID}" \
    --format json > "${MATRIX_REPORT_DOWNLOAD_PATH}"
}

delete_matrix_assessment()
{
  local INSTANCE_ID="$1"
  local MATRIX_ASSESSMENT_ID="$2"
  log_stdout "Deleting MATRIX assessment ${MATRIX_ASSESSMENT_ID}."
  corellium matrix delete-assessment \
    --instance "${INSTANCE_ID}" \
    --assessment "${MATRIX_ASSESSMENT_ID}"
  log_stdout "Deleted MATRIX assessment ${MATRIX_ASSESSMENT_ID}."
}

get_open_matrix_assessment_json()
{
  local INSTANCE_ID="$1"
  corellium matrix get-assessments --instance "${INSTANCE_ID}" |
    jq -r '.[] | select(.status != "complete" and .status != "failed")'
}

handle_open_matrix_assessment()
{
  local INSTANCE_ID="$1"
  local OPEN_MATRIX_ASSESSMENT_JSON
  OPEN_MATRIX_ASSESSMENT_JSON="$(get_open_matrix_assessment_json "${INSTANCE_ID}")"
  local MATRIX_STATUS_COMPLETE='complete'
  if [ -n "${OPEN_MATRIX_ASSESSMENT_JSON}" ]; then
    # There should only ever be one open MATRIX assessment. Added head -1 in case of handle edge cases.
    local OPEN_MATRIX_ASSESSMENT_ID OPEN_MATRIX_ASSESSMENT_STATUS
    OPEN_MATRIX_ASSESSMENT_ID="$(echo "${OPEN_MATRIX_ASSESSMENT_JSON}" | jq -r '.id' | head -1)"
    OPEN_MATRIX_ASSESSMENT_STATUS="$(echo "${OPEN_MATRIX_ASSESSMENT_JSON}" | jq -r '.status' | head -1)"
    log_warn "Assessment ${OPEN_MATRIX_ASSESSMENT_ID} is currently ${OPEN_MATRIX_ASSESSMENT_STATUS}."
    case "${OPEN_MATRIX_ASSESSMENT_STATUS}" in
      'testing')
        log_stdout "Waiting until ${OPEN_MATRIX_ASSESSMENT_ID} is ${MATRIX_STATUS_COMPLETE}."
        wait_for_assessment_status \
          "${INSTANCE_ID}" \
          "${OPEN_MATRIX_ASSESSMENT_ID}" \
          "${MATRIX_STATUS_COMPLETE}" ||
          exit 1
        ;;
      *)
        delete_matrix_assessment "${INSTANCE_ID}" "${OPEN_MATRIX_ASSESSMENT_ID}"
        ;;
    esac
  fi
}

run_full_matrix_assessment()
{
  local INSTANCE_ID="$1"
  local APP_BUNDLE_ID="$2"
  handle_open_matrix_assessment "${INSTANCE_ID}"
  log_stdout "Creating MATRIX assessment"
  local MATRIX_ASSESSMENT_ID
  MATRIX_ASSESSMENT_ID="$(create_matrix_assessment "${INSTANCE_ID}" "${APP_BUNDLE_ID}")"
  if [ -z "${MATRIX_ASSESSMENT_ID}" ]; then
    echo "Failed to create assessment" >&2
    return 1
  fi
  log_stdout "Created MATRIX assessment ${MATRIX_ASSESSMENT_ID}."
  start_matrix_monitoring "${INSTANCE_ID}" "${MATRIX_ASSESSMENT_ID}"
  # TODO: add app interactions
  sleep 10
  stop_matrix_monitoring "${INSTANCE_ID}" "${MATRIX_ASSESSMENT_ID}"
  test_matrix_evidence "${INSTANCE_ID}" "${MATRIX_ASSESSMENT_ID}"
  log_stdout "Completed MATRIX assessment ${MATRIX_ASSESSMENT_ID}."
  kill_app "${INSTANCE_ID}" "${APP_BUNDLE_ID}"
  download_matrix_report_html_to_path "${INSTANCE_ID}" "${MATRIX_ASSESSMENT_ID}" "matrix_report_${MATRIX_ASSESSMENT_ID}.html"
  download_matrix_report_json_to_path "${INSTANCE_ID}" "${MATRIX_ASSESSMENT_ID}" "matrix_report_${MATRIX_ASSESSMENT_ID}.json"
  log_stdout "Downloaded reports for MATRIX assessment ${MATRIX_ASSESSMENT_ID}."
}

run_matrix_cafe_checks_android()
{
  local INSTANCE_ID="$1"
  local APP_BUNDLE_ID='com.corellium.cafe'
  run_full_matrix_assessment "${INSTANCE_ID}" "${APP_BUNDLE_ID}"
}

run_matrix_cafe_checks_ios()
{
  local INSTANCE_ID="$1"
  local APP_BUNDLE_ID='com.corellium.Cafe'
  run_full_matrix_assessment "${INSTANCE_ID}" "${APP_BUNDLE_ID}"
}

delete_unauthorized_devices()
{
  if [[ -z "${AUTHORIZED_INSTANCES}" ]]; then
    log_stdout "Error: AUTHORIZED_INSTANCES is empty or unset."
    return 1
  fi

  local INSTANCES_TO_KEEP=()
  while IFS= read -r line; do
    INSTANCES_TO_KEEP+=("$(echo "${line}" | tr -d '\r\n')")
  done <<< "${AUTHORIZED_INSTANCES}"

  local CORELLIUM_DEVICES_JSON ALL_EXISTING_DEVICES
  CORELLIUM_DEVICES_JSON="$(corellium list)" || {
    echo "Error getting device list" >&2
    exit 1
  }
  # disable lint check since all values are assumed to be UUIDs
  #shellcheck disable=SC2207
  ALL_EXISTING_DEVICES=($(echo "${CORELLIUM_DEVICES_JSON}" | jq -r '.[].id')) || {
    echo "Error parsing device list" >&2
    exit 1
  }

  local UNAUTHORIZED_DEVICES=()
  local IS_DEVICE_AUTHORIZED
  for EXISTING_DEVICE in "${ALL_EXISTING_DEVICES[@]}"; do
    log_stdout "Checking ${EXISTING_DEVICE}."
    IS_DEVICE_AUTHORIZED='false'
    for AUTHORIZED_DEVICE in "${INSTANCES_TO_KEEP[@]}"; do
      if [ "${EXISTING_DEVICE}" = "${AUTHORIZED_DEVICE}" ]; then
        IS_DEVICE_AUTHORIZED='true'
        break
      fi
    done
    if [ "${IS_DEVICE_AUTHORIZED}" = 'true' ]; then
      log_stdout "Device ${EXISTING_DEVICE} is authorized."
    else
      log_stdout "Device ${EXISTING_DEVICE} is unauthorized."
      UNAUTHORIZED_DEVICES+=("${EXISTING_DEVICE}")
    fi
  done

  for DEVICE_TO_DELETE in "${UNAUTHORIZED_DEVICES[@]}"; do
    log_stdout "Deleting unauthorized device ${DEVICE_TO_DELETE}."
    corellium instance delete "${DEVICE_TO_DELETE}" --wait
    log_stdout "Deleted unauthorized device ${DEVICE_TO_DELETE}."
  done
}

start_demo_instances()
{
  local INSTANCE_START_SLEEP_TIME='30'
  local INSTANCES_TO_START=()
  while IFS= read -r line; do
    INSTANCES_TO_START+=("$(echo "${line}" | tr -d '\r\n')")
  done <<< "${START_INSTANCES}"
  for INSTANCE_ID in "${INSTANCES_TO_START[@]}"; do
    start_instance "${INSTANCE_ID}"
    sleep "${INSTANCE_START_SLEEP_TIME}"
  done
}

stop_demo_instances()
{
  local INSTANCES_TO_STOP=()
  while IFS= read -r line; do
    INSTANCES_TO_STOP+=("$(echo "${line}" | tr -d '\r\n')")
  done <<< "${STOP_INSTANCES}"
  for INSTANCE_ID in "${INSTANCES_TO_STOP[@]}"; do
    stop_instance "${INSTANCE_ID}"
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

  curl --silent -X GET \
    "${CORELLIUM_API_ENDPOINT}/api/v1/instances/${INSTANCE_ID}/agent/v1/file/device/${encoded_download_path}" \
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
  log_stdout "Saving ovpn profile to ${LOCAL_SAVE_PATH}."
  corellium project vpnConfig --project "${PROJECT_ID}" --path "${LOCAL_SAVE_PATH}"
  log_stdout "Saved ovpn profile to ${LOCAL_SAVE_PATH}."
}

wait_for_instance_status()
{
  local INSTANCE_ID="$1"
  local TARGET_INSTANCE_STATUS="$2"
  local SLEEP_TIME_DEFAULT='2'

  case "${TARGET_INSTANCE_STATUS}" in
    'on' | 'off') ;;
    *)
      echo "Unsupported target status: '${TARGET_INSTANCE_STATUS}'. Exiting." >&2
      exit 1
      ;;
  esac

  local CURRENT_INSTANCE_STATUS
  CURRENT_INSTANCE_STATUS="$(get_instance_status "${INSTANCE_ID}")"
  while [ "${CURRENT_INSTANCE_STATUS}" != "${TARGET_INSTANCE_STATUS}" ]; do
    log_stdout "Status is ${CURRENT_INSTANCE_STATUS} and target is ${TARGET_INSTANCE_STATUS}. Waiting ${SLEEP_TIME_DEFAULT} seconds."
    sleep "${SLEEP_TIME_DEFAULT}"
    CURRENT_INSTANCE_STATUS="$(get_instance_status "${INSTANCE_ID}")"
  done
}

wait_for_assessment_status()
{
  local INSTANCE_ID="$1"
  local ASSESSMENT_ID="$2"
  local TARGET_ASSESSMENT_STATUS="$3"
  local SLEEP_TIME_DEFAULT='5'
  local SLEEP_TIME_FOR_TESTING='60'

  case "${TARGET_ASSESSMENT_STATUS}" in
    'complete' | 'failed' | 'monitoring' | 'readyForTesting' | 'startMonitoring' | 'stopMonitoring' | 'testing') ;;
    *)
      echo "Unsupported target status: '${TARGET_ASSESSMENT_STATUS}'. Exiting." >&2
      exit 1
      ;;
  esac

  local CURRENT_ASSESSMENT_STATUS LAST_ASSESSMENT_STATUS ASSESSMENT_STATUS_SLEEP_TIME
  CURRENT_ASSESSMENT_STATUS="$(get_assessment_status "${INSTANCE_ID}" "${ASSESSMENT_ID}")"
  while [ "${CURRENT_ASSESSMENT_STATUS}" != "${TARGET_ASSESSMENT_STATUS}" ]; do
    case "${CURRENT_ASSESSMENT_STATUS}" in
      'failed')
        echo "Detected a failed run. Last state was '${LAST_ASSESSMENT_STATUS}'. Exiting." >&2
        return 1
        ;;
      'monitoring')
        echo 'Cannot wait when status is monitoring. Exiting.' >&2
        return 1
        ;;
      'testing')
        ASSESSMENT_STATUS_SLEEP_TIME="${SLEEP_TIME_FOR_TESTING}"
        ;;
      *)
        ASSESSMENT_STATUS_SLEEP_TIME="${SLEEP_TIME_DEFAULT}"
        ;;
    esac

    log_stdout "Status is ${CURRENT_ASSESSMENT_STATUS} and target is ${TARGET_ASSESSMENT_STATUS}. Waiting ${ASSESSMENT_STATUS_SLEEP_TIME} seconds."
    sleep "${ASSESSMENT_STATUS_SLEEP_TIME}"

    LAST_ASSESSMENT_STATUS="${CURRENT_ASSESSMENT_STATUS}"
    CURRENT_ASSESSMENT_STATUS="$(get_assessment_status "${INSTANCE_ID}" "${ASSESSMENT_ID}")"
  done
}

install_openvpn_dependencies()
{
  log_stdout 'Installing openvpn.'
  sudo apt-get -qq update
  sudo apt-get -qq install --assume-yes --no-install-recommends openvpn
  if command -v openvpn > /dev/null; then
    log_stdout 'Installed openvpn.'
  else
    log_error 'Failed to install openvpn dependency'
    exit 1
  fi
}

install_adb_dependency()
{
  log_stdout 'Installing adb.'
  sudo apt-get -qq update
  sudo apt-get -qq install adb

  if command -v adb > /dev/null; then
    log_stdout 'Installed adb.'
  else
    log_error 'Failed to install adb dependency'
    exit 1
  fi
}

install_usbfluxd_and_dependencies()
{
  local USBFLUXD_APT_DEPS=(
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

  local USBFLUXD_COMPILE_DEP_URLS=(
    'https://github.com/libimobiledevice/libplist'
    'https://github.com/corellium/usbfluxd'
  )

  local USBFLUXD_EXPECTED_BINARIES=(
    usbfluxd
    usbfluxctl
  )

  log_stdout 'Installing usbfluxd apt-get dependencies.'
  sudo apt-get -qq update
  sudo apt-get -qq install --assume-yes --no-install-recommends "${USBFLUXD_APT_DEPS[@]}"
  log_stdout 'Installed usbfluxd apt-get dependencies.'

  log_stdout 'Installing usbfluxd compiled dependencies.'
  local COMPILE_TEMP_DIR COMPILE_DEP_NAME
  COMPILE_TEMP_DIR="$(mktemp -d)"
  cd "${COMPILE_TEMP_DIR}/" || exit 1
  for COMPILE_DEP_URL in "${USBFLUXD_COMPILE_DEP_URLS[@]}"; do
    COMPILE_DEP_NAME="$(basename "${COMPILE_DEP_URL}")"
    log_stdout "Cloning ${COMPILE_DEP_NAME}."
    git clone --quiet "${COMPILE_DEP_URL}" "${COMPILE_DEP_NAME}"
    cd "${COMPILE_TEMP_DIR}/${COMPILE_DEP_NAME}/" || exit 1
    log_stdout "Generating Makefile for ${COMPILE_DEP_NAME}."
    ./autogen.sh > /dev/null 2>&1
    log_stdout "Compiling ${COMPILE_DEP_NAME}."
    make --jobs "$(nproc)" 2>&1 | grep 'Making all in ' || make --jobs "$(nproc)"
    log_stdout "Installing ${COMPILE_DEP_NAME}."
    sudo make install | grep '/usr/bin/install '
    cd "${COMPILE_TEMP_DIR}/" || exit 1
    log_stdout "Deleting build directory for ${COMPILE_DEP_NAME}."
    rm -rf "${COMPILE_DEP_NAME:?}/"
    log_stdout "Installed ${COMPILE_DEP_NAME} and cleaned up build directory."
  done
  log_stdout 'Installed usbfluxd compiled dependencies.'

  for EXPECTED_BINARY in "${USBFLUXD_EXPECTED_BINARIES[@]}"; do
    if command -v "${EXPECTED_BINARY}" > /dev/null; then
      log_stdout "Installed ${EXPECTED_BINARY} at $(command -v "${EXPECTED_BINARY}")."
    else
      log_error "Failed to install ${EXPECTED_BINARY}."
      exit 1
    fi
  done
  cd "${HOME}/" || exit 1
  rm -rf "${COMPILE_TEMP_DIR:?}/"
}

install_appium_server_and_dependencies()
{
  log_stdout 'Installing appium dependencies.'
  sudo apt-get -qq update
  sudo apt-get -qq install --assume-yes --no-install-recommends libusb-dev
  python3 -m pip install -U pymobiledevice3
  log_stdout 'Installed appium dependencies.'
  log_stdout 'Installing appium and xcuitest driver.'
  npm install --location=global appium
  appium driver install uiautomator2
  #appium driver install xcuitest # for ios devices
  log_stdout 'Installed appium and device driver.'
}

connect_to_vpn_for_instance()
{
  # Run this function with a timeout like 1 minute
  local INSTANCE_ID="$1"
  local OVPN_CONFIG_PATH="$2"
  local INSTANCE_SERVICES_IP
  INSTANCE_SERVICES_IP="$(get_instance_services_ip "${INSTANCE_ID}")"

  if ! command -v openvpn > /dev/null; then
    log_warn 'Attempting to install openvpn dependency.'
    install_openvpn_dependency
  fi

  save_vpn_config_to_local_path "${INSTANCE_ID}" "${OVPN_CONFIG_PATH}"
  log_stdout 'Connecting to Corellium project VPN.'
  sudo openvpn --config "${OVPN_CONFIG_PATH}" &
  log_stdout 'Connected to Corellium project VPN.'

  # Wait for the tunnel to establish, find the VPN IPv4 address, and test the connection
  until ip addr show tap0 > /dev/null 2>&1; do sleep 0.1; done
  log_stdout 'Found the project VPN tap0 interface.'
  local INSTANCE_VPN_IP
  INSTANCE_VPN_IP="$(ip addr show tap0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)"
  until ping -c1 "${INSTANCE_VPN_IP}"; do sleep 0.1; done
  log_stdout 'Successfully pinged the project VPN IP.'
  until ping -c1 "${INSTANCE_SERVICES_IP}"; do sleep 0.1; done
  log_stdout 'Successfully pinged the instance services IP.'
}

connect_with_adb()
{
  local INSTANCE_ID="$1"
  local INSTANCE_SERVICES_IP
  INSTANCE_SERVICES_IP="$(get_instance_services_ip "${INSTANCE_ID}")"
  local ADB_CONNECT_PORT='5001'
  local ADB_CONNECT_SOCKET="${INSTANCE_SERVICES_IP}:${ADB_CONNECT_PORT}"

  if ! command -v adb > /dev/null; then
    log_warn 'Attempting to install adb dependency.'
    install_adb_dependency
  fi

  adb connect "${ADB_CONNECT_SOCKET}"
  adb devices -l | grep -q "${ADB_CONNECT_SOCKET}" || {
    log_error "Unable to connect to ${INSTANCE_ID} at ${ADB_CONNECT_SOCKET}."
    adb devices -l
    exit 1
  }
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

verify_usbflux_connection()
{
  until idevice_id --list; do sleep 0.1; done
  idevicepair pair || {
    log_error 'Unable to establish idevicepair'
    exit 1
  }
}

run_appium_server()
{
  log_stdout 'Starting appium.
  appium \
    --port 4723 \
    --log-level info \
    --allow-insecure=uiautomator2:chromedriver_autodownload \
    --default-capabilities '{"appium:adbExecTimeout":60000}'
  log_stdout 'Starting appium.'
}

test_create_appium_session_cafe()
{
  local INSTANCE_ID="$1"
  local CAFE_PAGKAGE_NAME='com.corellium.cafe'
  test_create_appium_session "${INSTANCE_ID}" "${CAFE_PAGKAGE_NAME}"
}

test_create_appium_session()
{
  local INSTANCE_ID="$1"
  local APP_PACKAGE_NAME="$2"
  local DEFAULT_APPIUM_PORT='4723'
  local DEFAULT_APPIUM_PORT='5001'
  local INSTANCE_SERVICES_IP APPIUM_SESSION_JSON_PAYLOAD
  INSTANCE_SERVICES_IP="$(get_instance_services_ip "${INSTANCE_ID}")"

  APPIUM_SESSION_JSON_PAYLOAD=$(cat <<EOF
{
  "capabilities": {
    "alwaysMatch": {
      "platformName": "Android",
      "appium:automationName": "UiAutomator2",
      "appium:udid": "${INSTANCE_SERVICES_IP}:${DEFAULT_APPIUM_PORT}",
      "appium:deviceName": "Corellium",
      "appium:appPackage": "${APP_PACKAGE_NAME}",
      "appium:appActivity": ".ui.activities.MainActivity",
      "appium:noReset": false,
      "appium:systemPort": 8200
    },
    "firstMatch": [{}]
  }
}
EOF
)

  log_stdout 'Starting appium session.
  curl -X POST "http://127.0.0.1:${DEFAULT_APPIUM_PORT}/session" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD"
  log_stdout 'Started appium session.
}
