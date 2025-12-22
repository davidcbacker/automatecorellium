#!/bin/bash
#
# Define reusable functions for Corellium MATRIX

install_appium_server_and_dependencies()
{
  log_stdout 'Installing appium dependencies.'
  sudo apt-get -qq update
  sudo apt-get -qq install --assume-yes --no-install-recommends libusb-dev
  #python3 -m pip install -U pymobiledevice3 # for ios devices
  python3 -m pip install -U Appium-Python-Client
  log_stdout 'Installed appium dependencies.'
  log_stdout 'Installing appium and device driver.'
  npm install --location=global appium
  appium driver install uiautomator2
  #appium driver install xcuitest # for ios devices
  log_stdout 'Installed appium and device driver.'
}

install_appium_runner_ios()
{
  local INSTANCE_ID="$1"
  local APPIUM_RUNNER_IOS_URL="https://www.corellium.com/hubfs/Blog%20Attachments/WebDriverAgentRunner-Runner.ipa"
  local APPIUM_RUNNER_IOS_BUNDLE_ID='org.appium.WebDriverAgentRunner.xctrunner'
  kill_app "${INSTANCE_ID}" "${APPIUM_RUNNER_IOS_BUNDLE_ID}"
  install_app_from_url "${INSTANCE_ID}" "${APPIUM_RUNNER_IOS_URL}"
}

create_matrix_assessment()
{
  local INSTANCE_ID="$1"
  local APP_BUNDLE_ID="$2"
  local MATRIX_WORDLIST_ID="$3"
  corellium matrix create-assessment \
    --instance "${INSTANCE_ID}" \
    --bundle "${APP_BUNDLE_ID}" \
    --wordlist "${MATRIX_WORDLIST_ID}" |
    jq -r '.id'
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
  wait_for_matrix_assessment_status \
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
  wait_for_matrix_assessment_status \
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
  wait_for_matrix_assessment_status \
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

get_raw_matrix_report()
{
  local INSTANCE_ID="$1"
  local MATRIX_ASSESSMENT_ID="$2"
  local MATRIX_REPORT_DEFAULT_FORMAT='html'
  local MATRIX_REPORT_TARGET_FORMAT="${3:-${MATRIX_REPORT_DEFAULT_FORMAT}}"
  case "${MATRIX_REPORT_TARGET_FORMAT}" in
    html | json) ;;
    *)
      log_error "Invalid MATRIX report format ${MATRIX_REPORT_TARGET_FORMAT}."
      exit 1
      ;;
  esac
  corellium matrix download-report \
    --instance "${INSTANCE_ID}" \
    --assessment "${MATRIX_ASSESSMENT_ID}" \
    --format "${MATRIX_REPORT_TARGET_FORMAT}"
}

download_matrix_report_to_local_path()
{
  local INSTANCE_ID="$1"
  local MATRIX_ASSESSMENT_ID="$2"
  local MATRIX_REPORT_DOWNLOAD_PATH="$3"
  local MATRIX_REPORT_DEFAULT_FORMAT='html'
  local MATRIX_REPORT_TARGET_FORMAT="${4:-${MATRIX_REPORT_DEFAULT_FORMAT}}"
  log_stdout "Downloading ${MATRIX_REPORT_TARGET_FORMAT^^} report for MATRIX assessment ${MATRIX_ASSESSMENT_ID}."
  get_raw_matrix_report \
    "${INSTANCE_ID}" \
    "${MATRIX_ASSESSMENT_ID}" \
    "${MATRIX_REPORT_TARGET_FORMAT}" \
    > "${MATRIX_REPORT_DOWNLOAD_PATH}"
  log_stdout "Downloaded ${MATRIX_REPORT_TARGET_FORMAT^^} report for MATRIX assessment ${MATRIX_ASSESSMENT_ID}."
}

print_failed_matrix_checks()
{
  local INSTANCE_ID="$1"
  local MATRIX_ASSESSMENT_ID="$2"
  local MATRIX_REPORT_FORMAT='json'
  get_raw_matrix_report \
    "${INSTANCE_ID}" \
    "${MATRIX_ASSESSMENT_ID}" \
    "${MATRIX_REPORT_FORMAT}" |
    jq -r '.results[] | select(.outcome == "fail") | .name' |
    sort
}

delete_matrix_assessment()
{
  local INSTANCE_ID="$1"
  local MATRIX_ASSESSMENT_ID="$2"
  log_stdout "Deleting MATRIX assessment ${MATRIX_ASSESSMENT_ID}."
  corellium matrix delete-assessment \
    --instance "${INSTANCE_ID}" \
    --assessment "${MATRIX_ASSESSMENT_ID}" \
    > /dev/null
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
        log_stdout "Waiting until assessment ${OPEN_MATRIX_ASSESSMENT_ID} is ${MATRIX_STATUS_COMPLETE}."
        wait_for_matrix_assessment_status \
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
  local MATRIX_WORDLIST_ID="$3"
  handle_open_matrix_assessment "${INSTANCE_ID}"
  log_stdout "Creating MATRIX assessment."
  local MATRIX_ASSESSMENT_ID
  MATRIX_ASSESSMENT_ID="$(create_matrix_assessment "${INSTANCE_ID}" "${APP_BUNDLE_ID}" "${MATRIX_WORDLIST_ID}")"
  if [ -z "${MATRIX_ASSESSMENT_ID}" ]; then
    log_error "Failed to create assessment."
    return 1
  fi
  log_stdout "Created MATRIX assessment ${MATRIX_ASSESSMENT_ID}."
  start_matrix_monitoring "${INSTANCE_ID}" "${MATRIX_ASSESSMENT_ID}"
  wait_until_app_is_running_on_instance "${INSTANCE_ID}" "${APP_BUNDLE_ID}"
  run_appium_interactions_cafe "${INSTANCE_ID}"
  ensure_app_is_running_on_instance "${INSTANCE_ID}" "${APP_BUNDLE_ID}"
  stop_matrix_monitoring "${INSTANCE_ID}" "${MATRIX_ASSESSMENT_ID}"
  test_matrix_evidence "${INSTANCE_ID}" "${MATRIX_ASSESSMENT_ID}"
  log_stdout "Completed MATRIX assessment ${MATRIX_ASSESSMENT_ID}."
  kill_app "${INSTANCE_ID}" "${APP_BUNDLE_ID}"
  download_matrix_report_to_local_path \
    "${INSTANCE_ID}" \
    "${MATRIX_ASSESSMENT_ID}" \
    "matrix_report_${MATRIX_ASSESSMENT_ID}.html" \
    'html'
  download_matrix_report_to_local_path \
    "${INSTANCE_ID}" \
    "${MATRIX_ASSESSMENT_ID}" \
    "matrix_report_${MATRIX_ASSESSMENT_ID}.json" \
    'json'
}

get_matrix_assessment_status()
{
  local instance_id="$1"
  local assessment_id="$2"
  corellium matrix get-assessment --instance "${instance_id}" --assessment "${assessment_id}" | jq -r '.status'
}

wait_for_matrix_assessment_status()
{
  local INSTANCE_ID="$1"
  local ASSESSMENT_ID="$2"
  local TARGET_ASSESSMENT_STATUS="$3"
  local SLEEP_TIME_DEFAULT='2'
  local SLEEP_TIME_FOR_TESTING='5'

  case "${TARGET_ASSESSMENT_STATUS}" in
    'complete' | 'failed' | 'monitoring' | 'readyForTesting' | 'startMonitoring' | 'stopMonitoring' | 'testing') ;;
    *)
      log_error "Unsupported target assessment status '${TARGET_ASSESSMENT_STATUS}'."
      exit 1
      ;;
  esac

  local CURRENT_ASSESSMENT_STATUS LAST_ASSESSMENT_STATUS ASSESSMENT_STATUS_SLEEP_TIME
  LAST_ASSESSMENT_STATUS='UNDEFINED'
  CURRENT_ASSESSMENT_STATUS="$(get_matrix_assessment_status "${INSTANCE_ID}" "${ASSESSMENT_ID}")"
  while [ "${CURRENT_ASSESSMENT_STATUS}" != "${TARGET_ASSESSMENT_STATUS}" ]; do
    case "${CURRENT_ASSESSMENT_STATUS}" in
      '')
        log_warn "Failed to get instance status. Checking again in ${SLEEP_TIME_DEFAULT} seconds."
        ASSESSMENT_STATUS_SLEEP_TIME="${SLEEP_TIME_DEFAULT}"
        ;;
      'failed')
        log_error "Detected a failed run. Last state was '${LAST_ASSESSMENT_STATUS}'."
        exit 1
        ;;
      'monitoring')
        log_error 'Cannot wait when status is monitoring.'
        exit 1
        ;;
      'testing')
        ASSESSMENT_STATUS_SLEEP_TIME="${SLEEP_TIME_FOR_TESTING}"
        ;;
      *)
        ASSESSMENT_STATUS_SLEEP_TIME="${SLEEP_TIME_DEFAULT}"
        ;;
    esac
    sleep "${ASSESSMENT_STATUS_SLEEP_TIME}"
    LAST_ASSESSMENT_STATUS="${CURRENT_ASSESSMENT_STATUS}"
    CURRENT_ASSESSMENT_STATUS="$(get_matrix_assessment_status "${INSTANCE_ID}" "${ASSESSMENT_ID}")"
  done
}

run_appium_server()
{
  log_stdout 'Starting appium server.'
  command -v appium > /dev/null || {
    log_error 'Cannot find appium in PATH.'
    exit 1
  }
  appium &
  until curl --silent http://127.0.0.1:4723/status |
    jq -e '.value.ready == true' > /dev/null; do sleep 0.1; done
  log_stdout 'Started appium server.'
}

open_appium_session()
{
  local INSTANCE_ID="$1"
  local APP_PACKAGE_NAME="$2"
  local DEFAULT_APPIUM_PORT='4723'
  local DEFAULT_ADB_PORT='5001'
  local INSTANCE_SERVICES_IP APPIUM_SESSION_JSON_PAYLOAD OPEN_APPIUM_SESSION_JSON_RESPONSE OPENED_SESSION_ID
  INSTANCE_SERVICES_IP="$(get_instance_services_ip "${INSTANCE_ID}")"

  APPIUM_SESSION_JSON_PAYLOAD=$(
    cat << EOF
{
  "capabilities": {
    "alwaysMatch": {
      "platformName": "Android",
      "appium:automationName": "UiAutomator2",
      "appium:udid": "${INSTANCE_SERVICES_IP}:${DEFAULT_ADB_PORT}",
      "appium:appPackage": "${APP_PACKAGE_NAME}"
    },
    "firstMatch": [{}]
  }
}
EOF
  )

  OPEN_APPIUM_SESSION_JSON_RESPONSE="$(curl --silent --retry 5 \
    -X POST "http://127.0.0.1:${DEFAULT_APPIUM_PORT}/session" \
    -H "Content-Type: application/json" \
    -d "${APPIUM_SESSION_JSON_PAYLOAD}")" || {
    log_error 'Failed to open appium session.'
    exit 1
  }
  log_warn 'DEBUG SHOWING THE JSON RESPONSE DETAILS'
  echo "${OPEN_APPIUM_SESSION_JSON_RESPONSE}" >&2
  OPENED_SESSION_ID="$(echo "${OPEN_APPIUM_SESSION_JSON_RESPONSE}" | jq -r '.value.sessionId')" || {
    log_error 'Failed to parse open appium session JSON response.'
    exit 1
  }
  echo "${OPENED_SESSION_ID}"
}

close_appium_session()
{
  local SESSION_ID="$1"
  local DEFAULT_APPIUM_PORT='4723'
  local APPIUM_API_SESSION_URL="http://127.0.0.1:${DEFAULT_APPIUM_PORT}/session/${SESSION_ID}"
  curl --silent -X DELETE "${APPIUM_API_SESSION_URL}" \
    -H "Content-Type: application/json" > /dev/null || {
    log_error 'Failed to close session.'
    exit 1
  }

  # Verify that the session ID is now invalid
  local GET_APPIUM_SESSION_JSON_RESPONSE
  GET_APPIUM_SESSION_JSON_RESPONSE="$(curl --silent -X GET "${APPIUM_API_SESSION_URL}")"
  if ! echo "${GET_APPIUM_SESSION_JSON_RESPONSE}" | jq -e '.value.error == "invalid session id"' > /dev/null; then
    echo "${GET_APPIUM_SESSION_JSON_RESPONSE}"
    log_error "Appium session ${SESSION_ID} is still valid after close."
    exit 1
  fi
}

run_appium_interactions_cafe()
{
  local INSTANCE_ID="$1"
  local INSTANCE_SERVICES_IP APPIUM_SESSION_JSON_PAYLOAD
  INSTANCE_SERVICES_IP="$(get_instance_services_ip "${INSTANCE_ID}")"
  log_stdout 'Starting automated Appium interactions.'
  PYTHONUNBUFFERED=1 python3 src/util/appium_interactions_cafe.py "${INSTANCE_SERVICES_IP}"
  log_stdout 'Finished automated Appium interactions.'
}

run_appium_interactions_template()
{
  local INSTANCE_ID="$1"
  local INSTANCE_SERVICES_IP APPIUM_SESSION_JSON_PAYLOAD
  INSTANCE_SERVICES_IP="$(get_instance_services_ip "${INSTANCE_ID}")"
  log_stdout 'Starting automated Appium interactions.'
  python3 src/util/appium_interactions_template.py "${INSTANCE_SERVICES_IP}"
  log_stdout 'Finished automated Appium interactions.'
}

analyze_corellium_cafe_matrix_report_from_local_path()
{
  local MATRIX_JSON_REPORT_PATH="$1"
  local MATRIX_CHECK_TO_ANALYZE='masvs-storage-1-android-12'
  local MATRIX_CHECK_EXPECTED_OUTCOME='fail'
  [ -f "${MATRIX_JSON_REPORT_PATH}" ] || {
    log_error "${MATRIX_JSON_REPORT_PATH} is not a file."
    exit 1
  }
  jq '.' "${MATRIX_JSON_REPORT_PATH}" > /dev/null 2>&1 || {
    log_error "Failed to parse ${MATRIX_JSON_REPORT_PATH}."
    exit 1
  }
  log_stdout "Listing failed assessment checks for ${report}."
  print_matching_matrix_check_outcomes_from_local_json_path \
    "${MATRIX_JSON_REPORT_PATH}" \
    "${MATRIX_CHECK_EXPECTED_OUTCOME}"
  log_stdout 'Listed failed assessment checks.'
  log_stdout "Verifying outcome of local storage check for ${report}."
  ensure_matrix_check_outcomes_from_local_json_path \
    "${MATRIX_JSON_REPORT_PATH}" \
    "${MATRIX_CHECK_TO_ANALYZE}" \
    "${MATRIX_CHECK_EXPECTED_OUTCOME}"
  log_stdout 'Verified outcome of local storage check.'
}

print_matching_matrix_check_outcomes_from_local_json_path()
{
  local MATRIX_JSON_REPORT_PATH="$1"
  local MATRIX_CHECK_DEFAULT_EXPECTED_OUTCOME='fail'
  local MATRIX_CHECK_EXPECTED_OUTCOME="${2:-${MATRIX_CHECK_DEFAULT_EXPECTED_OUTCOME}}"
  jq -r \
    --arg expected_outcome "${MATRIX_CHECK_EXPECTED_OUTCOME}" \
    '.results[] | select(.outcome == $expected_outcome) | "\(.name) [\(.id)]"' \
    "${MATRIX_JSON_REPORT_PATH}" |
    sort
}

ensure_matrix_check_outcomes_from_local_json_path()
{
  local MATRIX_JSON_REPORT_PATH="$1"
  local MATRIX_CHECK_TO_ANALYZE="$2"
  local MATRIX_CHECK_EXPECTED_OUTCOME="$3"
  jq -e \
    --arg id "${MATRIX_CHECK_TO_ANALYZE}" \
    --arg expected_outcome "${MATRIX_CHECK_EXPECTED_OUTCOME}" \
    '.results[] | select(.id == $id) | .outcome == $expected_outcome' \
    "${MATRIX_JSON_REPORT_PATH}" || {
    log_error "MATRIX check ${MATRIX_CHECK_TO_ANALYZE} is not ${MATRIX_CHECK_EXPECTED_OUTCOME}."
    exit 1
  }
}

compress_matrix_runtime_artifacts()
{
  local INSTANCE_ID="$1"
  local INSTANCE_SERVICES_IP
  INSTANCE_SERVICES_IP="$(get_instance_services_ip "${INSTANCE_ID}")"
  local INSTANCE_FLAVOR ARCHIVE_INPUT_ARTIFACTS_PATH ARCHIVE_INPUT_ASSESSMENTS_PATH
  INSTANCE_FLAVOR="$(get_instance_flavor "${INSTANCE_ID}")"
  if [ "${INSTANCE_FLAVOR}" = 'ranchu' ]; then
    ARCHIVE_INPUT_ARTIFACTS_PATH='/data/local/tmp/artifacts/'
    ARCHIVE_INPUT_ASSESSMENTS_PATH='/data/local/tmp/assessment.*/'
  else
    ARCHIVE_INPUT_ARTIFACTS_PATH='/tmp/artifacts/'
    ARCHIVE_INPUT_ASSESSMENTS_PATH='/tmp/assessment.*/'
  fi
  local ARCHIVE_OUTPUT_PATH='/tmp/matrix_artifacts.tar.gz'
  local TARGET_COMMANDS=(
    "tar -czvf ${ARCHIVE_OUTPUT_PATH} '${ARCHIVE_INPUT_ARTIFACTS_PATH}' '${ARCHIVE_INPUT_ASSESSMENTS_PATH}'"
    "ls -l ${ARCHIVE_OUTPUT_PATH}"
    "sha256sum ${ARCHIVE_OUTPUT_PATH}"
  )
  for target_command in "${TARGET_COMMANDS[@]}"; do
    if [ "${INSTANCE_FLAVOR}" = 'ranchu' ]; then
      remote_code_execution_with_adb "${INSTANCE_SERVICES_IP}" "${target_command}"
    else
      remote_code_execution_with_ssh "${INSTANCE_SERVICES_IP}" "${target_command}"
    fi
  done
}
