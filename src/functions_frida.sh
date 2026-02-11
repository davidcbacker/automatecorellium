#!/bin/bash
#
#

install_frida_dependencies()
{
  log_stdout 'Installing frida.'
  local TARGET_FRIDA_VERSION='17.2.15'
  python3 -m pip install -U "frida==${TARGET_FRIDA_VERSION}" frida-tools
  log_stdout 'Installed frida.'
  # python3 -m pip install -U objection # Objection does not support Frida 17 yet
}

run_frida_list_devices()
{
  log_stdout 'Listing devices.'
  frida-ls-devices < /dev/null || true
  log_stdout 'Listed devices.'
}

run_frida_ps_device()
{
  local INSTANCE_ID="$1"
  local GET_INSTANCE_JSON_RESPONSE INSTANCE_SERVICES_IP FRIDA_DEVICE_ID
  GET_INSTANCE_JSON_RESPONSE="$(corellium instance get --instance "${INSTANCE_ID}")"
  INSTANCE_FLAVOR="$(echo "${GET_INSTANCE_JSON_RESPONSE}" | jq -r '.flavor')"
  if [ "${INSTANCE_FLAVOR}" = 'ranchu' ]; then
    INSTANCE_SERVICES_IP="$(echo "${GET_INSTANCE_JSON_RESPONSE}" | jq -r '.serviceIp')"
    FRIDA_DEVICE_ID="${INSTANCE_SERVICES_IP}:5001"
  else
    INSTANCE_UDID="$(echo "${GET_INSTANCE_JSON_RESPONSE}" | jq -r '.bootOptions.udid')"
    FRIDA_DEVICE_ID="${INSTANCE_UDID}"
  fi
  log_stdout 'Listing running apps.'
  frida-ps --device "${FRIDA_DEVICE_ID}" --applications || {
    log_warn 'Failed to enumerate running apps. Retrying.'
    frida-ps --device "${FRIDA_DEVICE_ID}" --applications
  }
  log_stdout 'Listed running apps.'
}

run_frida_ps_network()
{
  local INSTANCE_ID="$1"
  local GET_INSTANCE_JSON_RESPONSE
  GET_INSTANCE_JSON_RESPONSE="$(corellium instance get --instance "${INSTANCE_ID}")"
  if echo "${GET_INSTANCE_JSON_RESPONSE}" | jq -e '.flavor != ranchu' > /dev/null &&
    ! echo "${GET_INSTANCE_JSON_RESPONSE}" | grep Port | grep -q 27042; then
    log_error "Port 27042 must be forwarded and exposed on instance ${INSTANCE_ID}."
    exit 1
  fi
  local INSTANCE_SERVICES_IP
  INSTANCE_SERVICES_IP="$(get_instance_services_ip "${INSTANCE_ID}")"
  log_stdout 'Listing running apps.'
  frida-ps --host "${INSTANCE_SERVICES_IP}" --applications || {
    log_warn 'Failed to enumerate running apps. Retrying.'
    frida-ps --host "${INSTANCE_SERVICES_IP}" --applications
  }
  log_stdout 'Listied running apps.'
}

run_frida_ps_usb()
{
  log_stdout 'Listing running apps.'
  frida-ps --usb --applications || {
    log_warn 'Failed to enumerate running apps. Retrying.'
    frida-ps --usb --applications
  }
  log_stdout 'Listed running apps.'
}

run_frida_script_usb()
{
  local APP_PACKAGE_NAME="$1"
  local FRIDA_SCRIPT_PATH="$2"
  log_stdout "Spawning app ${APP_PACKAGE_NAME} with Frida script $(basename "${FRIDA_SCRIPT_PATH}")."

  if [ "${CI:-false}" = 'true' ]; then
    local FRIDA_TIMEOUT_SECONDS='10'
    log_stdout "Frida script will timeout after ${FRIDA_TIMEOUT_SECONDS} seconds."
    timeout "${FRIDA_TIMEOUT_SECONDS}" \
      frida --usb --file "${APP_PACKAGE_NAME}" --load "${FRIDA_SCRIPT_PATH}" || {
      local FAILURE_EXIT_STATUS="$?"
      if [ "${FAILURE_EXIT_STATUS}" -eq 124 ]; then
        log_stdout "Frida successfully timed out after ${FRIDA_TIMEOUT_SECONDS} seconds."
      else
        log_error "Unknown exit status ${FAILURE_EXIT_STATUS}."
        exit 1
      fi
    }
  else
    log_stdout "Frida script will run indefinitely with no timeout."
    frida --usb --file "${APP_PACKAGE_NAME}" --load "${FRIDA_SCRIPT_PATH}"
  fi
}
