#!/bin/bash

source src/functions.sh

export CORELLIUM_API_TOKEN="${JEDI_API_TOKEN:?Error: JEDI_API_TOKEN is not set. Please set it in your environment.}"
export CORELLIUM_API_ENDPOINT="${JEDI_DOMAIN:?Error: JEDI_DOMAIN is not set. Please set it in your environment.}"

corellium login --apitoken "${CORELLIUM_API_TOKEN}" --endpoint "${CORELLIUM_API_ENDPOINT}"

UUID_REGEX='^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$'

CORELLIUM_PROJECT_ID='a9ebc713-33a7-44c7-894e-b8c4c450db9d'
CORELLIUM_OS='Android'
CORELLIUM_HARDWARE_FLAVOR='ranchu'
CORELLIUM_FIRMWARE_VERSION='16.0.0'
CORELLIUM_FIRMWARE_BUILD='r2 userdebug'
CORELLIUM_CAFE_APP_ID='com.corellium.cafe'
CORELLIUM_CAFE_SOURCE_URL='https://www.corellium.com/hubfs/Corellium_Cafe.apk'

CORELLIUM_INSTANCE_NAME_PREFIX='Android Device Farm -'

DEVICES_TO_CREATE=2
CORES_PER_DEVICE=4  
CORES_REQUIRED=$((DEVICES_TO_CREATE * CORES_PER_DEVICE))

TEST_SCRIPTS=(
    'appium_interactions_cafe_android_mainactivity_login_page.py'
    'appium_interactions_cafe_android_cartactivity.py'
    'appium_interactions_cafe_android_customerinfoactivity.py'
    'appium_interactions_cafe_android_descriptionactivity.py'
    'appium_interactions_cafe_android_homeactivity.py'
    'appium_interactions_cafe_android_orderactivity.py'
    'appium_interactions_cafe_android_orderreviewactivity.py'
    'appium_interactions_cafe_android_paymentactivity.py'
    'appium_interactions_cafe_android_secretactivity.py'
    'appium_interactions_cafe_android_settingsactivity.py'
    'appium_interactions_cafe_android_webviewactivity.py'
    'appium_interactions_cafe_android_full_flow_no_blog.py'
)

log_info "Checking for available cores in project."
wait_until_available_cores \
    "${CORELLIUM_PROJECT_ID}" \
    "${CORES_REQUIRED}"
log_info "Sufficient cores are available for ${DEVICES_TO_CREATE} devices."

log_info "Disconnecting from any existing ADB connections."
adb disconnect

CREATED_INSTANCE_IDS=()

for ((i=1; i<=DEVICES_TO_CREATE; i++)); do
    log_info "Creating device $i of ${DEVICES_TO_CREATE}."
    wait_until_available_cores \
        "${CORELLIUM_PROJECT_ID}" \
        "${CORES_PER_DEVICE}"
    CREATE_INSTANCE_RESPONSE="$(create_instance \
        "${CORELLIUM_HARDWARE_FLAVOR}" \
        "${CORELLIUM_FIRMWARE_VERSION}" \
        "${CORELLIUM_FIRMWARE_BUILD}" \
        "${CORELLIUM_PROJECT_ID}" \
        "${CORELLIUM_INSTANCE_NAME_PREFIX}")"

    if [[ -z "$CREATE_INSTANCE_RESPONSE" ]]; then
        log_error "create_instance returned an empty response. Creation failed."
    elif [[ $CREATE_INSTANCE_RESPONSE =~ $UUID_REGEX ]]; then
        log_info "Successfully created device with instance ID: $CREATE_INSTANCE_RESPONSE"
        CREATED_INSTANCE_IDS+=("${CREATE_INSTANCE_RESPONSE}")
        sleep 30
    else
        log_error "Failed to create device: $CREATE_INSTANCE_RESPONSE"
    fi
done

if [ "${#CREATED_INSTANCE_IDS[@]}" -eq 0 ]; then
    log_error "No devices were created successfully. Exiting."
    exit 1
fi

log_info "Created ${#CREATED_INSTANCE_IDS[@]} devices: ${CREATED_INSTANCE_IDS[*]}"


log_info "Installing Corellium Cafe app on each device."
for instance_id in "${CREATED_INSTANCE_IDS[@]}"; do
    log_info "Waiting for device with instance ID ${instance_id} to be ready."
    wait_until_agent_ready "${instance_id}"
    install_app_from_url "${instance_id}" "${CORELLIUM_CAFE_SOURCE_URL}"
done

log_info "All devices are ready and Corellium Cafe app is installed."

# build out an array of instance services IPs for each created instance

CREATED_INSTANCE_SERVICES_IPS=()
for instance_id in "${CREATED_INSTANCE_IDS[@]}"; do
    instance_services_ip="$(get_instance_services_ip "${instance_id}")"
    if [[ -n "${instance_services_ip}" ]]; then
        CREATED_INSTANCE_SERVICES_IPS+=("${instance_services_ip}")
    else
        log_error "Failed to retrieve services IP for instance ID: ${instance_id}"
    fi
done

log_info "Listing all created instance services IPs:"
echo "Created instance IDs: ${CREATED_INSTANCE_IDS[*]}"
log_info "Listing all created instance services IPs:"
echo "Created instance services IPs: ${CREATED_INSTANCE_SERVICES_IPS[*]}"

for instance_services_ip in "${CREATED_INSTANCE_SERVICES_IPS[@]}"; do
    log_info "Connecting to device with Services IP: ${instance_services_ip}"
    adb connect "${instance_services_ip}:5001"
    log_info "Restarting ADB as root for device with Services IP: ${instance_services_ip}"
    adb -s "${instance_services_ip}:5001" root
    log_info "Starting Appium session for device with Services IP: ${instance_services_ip}"
    curl --silent \
        -X POST "http://127.0.0.1:4723/session" \
        -H "Content-Type: application/json" \
        -d "{
        \"capabilities\": {
            \"alwaysMatch\": {
                \"platformName\": \"Android\",
                \"appium:automationName\": \"UiAutomator2\",
                \"appium:udid\": \"${instance_services_ip}:5001\",
                \"appium:appPackage\": \"com.corellium.cafe\",
                \"appium:appActivity\": \".ui.activities.WebViewActivity\",
                \"appium:uiautomator2ServerInstallTimeout\": 120000,
                \"appium:uiautomator2ServerLaunchTimeout\": 60000
            },
            \"firstMatch\": [{}]
        }
    }" | jq -r '.value.sessionId'
done

log_info "All devices are connected, ADB is running as root, and Appium sessions are started."
log_info "Waiting for 70 seconds to allow appium sessions to time out."
sleep 70

for script in "${TEST_SCRIPTS[@]}"; do
    echo "Testing $script"
    for instance_services_ip in "${CREATED_INSTANCE_SERVICES_IPS[@]}"; do
        python3 "src/util/${script}" "${instance_services_ip}" \
            > "output/test_output_${instance_services_ip}.txt" \
            2> "output/test_stderr_${instance_services_ip}.txt" &
    done
    wait
done
