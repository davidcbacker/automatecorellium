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
    printf '[!] %s ERROR: No argument supplied to log_stdout.\n' \
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

ensure_instance_exists()
{
  local INSTANCE_ID="$1"
  if ! corellium instance get --instance "${INSTANCE_ID}" |
    jq -e --arg id "${INSTANCE_ID}" 'select(.id == $id)' > /dev/null; then
    echo "Error, instance ${INSTANCE_ID} does not exist." >&2
    exit 1
  fi
}

start_instance()
{
  local INSTANCE_ID="$1"
  ensure_instance_exists "${INSTANCE_ID}"
  case "$(get_instance_status "${INSTANCE_ID}")" in
    'on')
      log_stdout "Instance ${INSTANCE_ID} is already on."
      ;;
    *)
      log_stdout "Starting instance ${INSTANCE_ID}"
      corellium instance start "${INSTANCE_ID}" --wait > /dev/null
      log_stdout "Started instance ${INSTANCE_ID}"
      ;;
  esac
}

soft_stop_instance()
{
  local INSTANCE_ID="$1"
  local TARGET_INSTANCE_STATUS_OFF='off'
  check_env_vars
  case "$(get_instance_status "${INSTANCE_ID}")" in
    "${TARGET_INSTANCE_STATUS_OFF}")
      log_stdout "Instance ${INSTANCE_ID} is already ${TARGET_INSTANCE_STATUS_OFF}."
      ;;
    *)
      log_stdout "Stopping instance ${INSTANCE_ID}."
      # Fix if this causes nonzero exit status or stderr messages
      curl -X POST "${CORELLIUM_API_ENDPOINT}/api/v1/instances/${INSTANCE_ID}/stop" \
        -H "Accept: application/json" \
        -H "Authorization: Bearer ${CORELLIUM_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"soft":true}'
      log_stdout "Initiated a soft stop of instance ${INSTANCE_ID}."
      wait_for_instance_status "${INSTANCE_ID}" "${TARGET_INSTANCE_STATUS_OFF}"
      log_stdout "Instance ${INSTANCE_ID} is ${TARGET_INSTANCE_STATUS_OFF}."
      ;;
  esac
}

get_instance_status()
{
  local INSTANCE_ID="$1"
  corellium instance get --instance "${INSTANCE_ID}" | jq -r '.state'
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
  local INSTANCE_ID="$1"
  local APP_BUNDLE_ID="$2"
  if [ "$(is_app_running "${INSTANCE_ID}" "${APP_BUNDLE_ID}")" = 'true' ]; then
    log_stdout "Killing running app ${APP_BUNDLE_ID}"
    if curl -sX POST \
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
  corellium instance unlock --instance "${INSTANCE_ID}"
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
  local MATRIX_STATUS_COMPLETED_TESTING='complete'
  log_stdout "Running test for MATRIX assessment ${MATRIX_ASSESSMENT_ID}."
  corellium matrix test \
    --instance "${INSTANCE_ID}" \
    --assessment "${MATRIX_ASSESSMENT_ID}" \
    > /dev/null
  wait_for_assessment_status \
    "${INSTANCE_ID}" \
    "${MATRIX_ASSESSMENT_ID}" \
    "${MATRIX_STATUS_COMPLETED_TESTING}" ||
    return 1
  log_stdout "MATRIX assessment ${MATRIX_ASSESSMENT_ID} is ${MATRIX_STATUS_COMPLETED_TESTING}."
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
  corellium matrix download-report --instance "${INSTANCE_ID}" --assessment "${MATRIX_ASSESSMENT_ID}" --format json > "${MATRIX_REPORT_DOWNLOAD_PATH}"
}

run_full_matrix_assessment()
{
  local INSTANCE_ID="$1"
  local APP_BUNDLE_ID="$2"
  log_stdout "Creating new MATRIX assessment"
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
  download_matrix_report_html_to_path "${INSTANCE_ID}" "${MATRIX_ASSESSMENT_ID}" "matrix_report_${MATRIX_ASSESSMENT_ID}.html"
  download_matrix_report_json_to_path "${INSTANCE_ID}" "${MATRIX_ASSESSMENT_ID}" "matrix_report_${MATRIX_ASSESSMENT_ID}.json"
  log_stdout "Downloaded reports for MATRIX assessment ${MATRIX_ASSESSMENT_ID}."
  kill_app "${INSTANCE_ID}" "${APP_BUNDLE_ID}"
}

run_matrix_cafe_checks()
{
  local INSTANCE_ID="$1"
  local APP_BUNDLE_ID='com.corellium.Cafe'
  run_full_matrix_assessment "${INSTANCE_ID}" "${APP_BUNDLE_ID}"
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

  local is_device_authorized
  for device in "${corellium_devices[@]}"; do
    is_device_authorized='false'
    log_stdout "Checking if ${device} is authorized."
    for authorized_device in "${authorized_instances[@]}"; do
      if [ "${device}" = "${authorized_device}" ]; then
        log_stdout "Device ${device} is authorized."
        is_device_authorized='true'
        break
      fi
    done
    if [ "${is_device_authorized}" != 'true' ]; then
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
    log_stdout "Starting instance ${instance}"
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

wait_for_instance_status()
{
  local INSTANCE_ID="$1"
  local TARGET_INSTANCE_STATUS="$2"
  local SLEEP_TIME_DEFAULT='5'

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

    log_stdout "Status is ${current_assessment_status} and target is ${TARGET_ASSESSMENT_STATUS}. Waiting ${sleep_time} seconds."
    sleep "${sleep_time}"

    last_assessment_status="${current_assessment_status}"
    current_assessment_status="$(get_assessment_status "${INSTANCE_ID}" "${ASSESSMENT_ID}")"
  done
}

install_openvpn_dependencies()
{
  sudo apt-get -qq update
  sudo apt-get -qq install -y openvpn
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

  log_stdout 'Installing apt-get dependencies.'
  sudo apt-get -qq update
  for APT_DEP in "${USBFLUXD_APT_DEPS[@]}"; do
    if sudo apt-get install -y "${APT_DEP}" > /dev/null; then
      log_stdout "Installed ${APT_DEP}."
    else
      echo "Failed to install ${APT_DEP}." >&2
      sudo apt-get -qq install -y "${APT_DEP}"
      exit 1
    fi
  done
  log_stdout 'Installed apt-get dependencies.'

  local COMPILE_TEMP_DIR COMPILE_DEP_NAME
  COMPILE_TEMP_DIR="$(mktemp -d)"
  cd "${COMPILE_TEMP_DIR}/" || exit 1
  for COMPILE_DEP_URL in "${USBFLUXD_COMPILE_DEP_URLS[@]}"; do
    COMPILE_DEP_NAME="$(basename "${COMPILE_DEP_URL}")"
    log_stdout "Cloning ${COMPILE_DEP_NAME}."
    git clone "${COMPILE_DEP_URL}" "${COMPILE_DEP_NAME}"
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

  for EXPECTED_BINARY in "${USBFLUXD_EXPECTED_BINARIES[@]}"; do
    if command -v "${EXPECTED_BINARY}" > /dev/null; then
      log_stdout "Installed ${EXPECTED_BINARY} at $(command -v "${EXPECTED_BINARY}")."
    else
      echo "Error, failed to install ${EXPECTED_BINARY}."
      exit 1
    fi
  done

  cd "${HOME}/" || exit 1
  rm -rf "${COMPILE_TEMP_DIR:?}/"
}

install_appium_server_and_dependencies()
{
  sudo apt-get -qq update
  sudo apt-get -qq install -y libusb-dev
  npm install --location=global appium
  appium driver install xcuitest
  python3 -m pip install -U pymobiledevice3
}

connect_to_vpn_for_instance()
{
  # Run this function with a timeout like 1 minute
  local INSTANCE_ID="$1"
  local OVPN_CONFIG_PATH="$2"
  local INSTANCE_SERVICES_IP
  INSTANCE_SERVICES_IP="$(get_instance_services_ip "${INSTANCE_ID}")"

  if ! command -v openvpn; then
    log_stdout 'Warning - openvpn not found. Attempting to install.'
    install_openvpn_dependency
  fi
  save_vpn_config_to_local_path "${INSTANCE_ID}" "${OVPN_CONFIG_PATH}"
  sudo openvpn --config "${OVPN_CONFIG_PATH}" &

  # Wait for the tunnel to establish, find the VPN IPv4 address, and test the connection
  until ip addr show tap0 > /dev/null 2>&1; do sleep 0.1; done
  local INSTANCE_VPN_IP
  INSTANCE_VPN_IP="$(ip addr show tap0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)"
  until ping -c1 "${INSTANCE_VPN_IP}"; do sleep 0.1; done
  log_stdout 'Successfully pinged the project VPN IP.'
  until ping -c1 "${INSTANCE_SERVICES_IP}"; do sleep 0.1; done
  log_stdout 'Successfully pinged the instance services IP.'
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
