

# Iterate through these but only the IPs
# 10.11.1.8:5001	device
# 10.11.1.10:5001	device
# 10.11.1.12:5001	device
# 10.11.1.14:5001	device
# 10.11.1.16:5001	device
# 10.11.1.18:5001	device
# 10.11.1.20:5001	device
# 10.11.1.22:5001	device

#ADB_DEVICES=$(adb devices | grep "device$" | awk '{print $1}' | cut -d: -f1)

# ADB_DEVICES=(
#     '10.11.1.8'
#     '10.11.1.10'
#     '10.11.1.12'
#     '10.11.1.14'
#     '10.11.1.16'
#     '10.11.1.18'
#     '10.11.1.20'
#     '10.11.1.22'
# )


ADB_DEVICES=(
    '10.11.1.1'
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

for device in "${ADB_DEVICES[@]}"; do
    echo "Testing on device: $device"
    python3 "src/util/appium_interactions_cafe_android.py" "${device}" \
        > "output/test_output_${device}.txt" \
        2> "output/test_stderr_${device}.txt" &
done
wait

echo "All tests completed."
