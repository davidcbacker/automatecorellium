#!/bin/bash
set -e
set -o nounset
set -o pipefail

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

ADB_DEVICES=(
    '10.11.1.3'
    '10.11.1.5'
    '10.11.1.7'
    '10.11.1.9'
    '10.11.1.11'
    '10.11.1.13'
    '10.11.1.15'
    '10.11.1.17'
)

cd "${HOME}/Documents/git/automatecorellium/"

echo "Testing all scripts on these rooted ADB-connected devices:"
for device in "${ADB_DEVICES[@]}"; do  
    printf '%s ' "'$device'"
done
printf '\n'


#for device in 10.11.1.17 10.11.1.15 10.11.1.13 10.11.1.11 10.11.1.9 10.11.1.7 10.11.1.5 10.11.1.3; do
# for i in $(seq 3 2 17); do
  # device="10.11.1.$i"
for device in "${ADB_DEVICES[@]}"; do
  adb connect $device:5001
  adb -s $device:5001 root
  curl --silent \
    -X POST "http://127.0.0.1:4723/session" \
    -H "Content-Type: application/json" \
    -d "{
    \"capabilities\": {
      \"alwaysMatch\": {
        \"platformName\": \"Android\",
        \"appium:automationName\": \"UiAutomator2\",
        \"appium:udid\": \"$device:5001\",
        \"appium:appPackage\": \"com.corellium.cafe\",
        \"appium:appActivity\": \".ui.activities.WebViewActivity\",
        \"appium:uiautomator2ServerInstallTimeout\": 120000,
        \"appium:uiautomator2ServerLaunchTimeout\": 60000
      },
      \"firstMatch\": [{}]
    }
  }" | jq -r '.value.sessionId'
done



for script in "${TEST_SCRIPTS[@]}"; do
    echo "Testing $script"
    for device in "${ADB_DEVICES[@]}"; do
        python3 "src/util/${script}" "${device}" \
            > "output/test_output_${device}.txt" \
            2> "output/test_stderr_${device}.txt" &
    done
    wait
done
