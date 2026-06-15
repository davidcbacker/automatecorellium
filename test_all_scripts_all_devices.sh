#!/bin/bash
set -e
set -o nounset
# set -o pipefail

TEST_SCRIPTS=(
    'appium_interactions_cafe_android_cartactivity.py'
    'appium_interactions_cafe_android_customerinfoactivity.py'
    'appium_interactions_cafe_android_descriptionactivity.py'
    'appium_interactions_cafe_android_homeactivity.py'
    'appium_interactions_cafe_android_mainactivity_login_page.py'
    'appium_interactions_cafe_android_orderactivity.py'
    'appium_interactions_cafe_android_orderreviewactivity.py'
    'appium_interactions_cafe_android_paymentactivity.py'
    'appium_interactions_cafe_android_secretactivity.py'
    'appium_interactions_cafe_android_settingsactivity.py'
    'appium_interactions_cafe_android_webviewactivity.py'
    'appium_interactions_cafe_android_full_flow_no_blog.py'
)

ADB_DEVICES=(
    '10.11.1.2'
    '10.11.1.4'
    '10.11.1.8'
    '10.11.1.10'
)

cd "${HOME}/Documents/git/automatecorellium/"
for script in "${TEST_SCRIPTS[@]}"; do
    echo "Running test script: $script"
    for device in "${ADB_DEVICES[@]}"; do
        echo "Testing $script on device: $device"
        python3 "src/util/${script}" "${device}" \
            > "output/test_output_${device}.txt" \
            2> "output/test_stderr_${device}.txt" &
    done
    wait
done
