from appium import webdriver
from appium.options.android import UiAutomator2Options
from appium.webdriver.common.appiumby import AppiumBy
from time import sleep
from sys import argv

# ==== CONSTANTS: CORELLIUM DEVICE ====
default_services_ip = '10.11.1.1'
default_adb_port = '5001'

# ==== CONSTANTS: TARGET APP ====
target_app_package = 'com.corellium.cafe'
target_app_activity = '.ui.activities.MainActivity'

# ==== CONSTANTS: APPIUM SERVER ====
appium_server_ip = '127.0.0.1'
appium_server_port = '4723'
appium_server_url = f'http://{appium_server_ip}:{appium_server_port}'

def run_cafe_app_test():
    options = UiAutomator2Options()
    options.set_capability('platformName', 'Android')
    options.set_capability('appium:automationName', 'UiAutomator2')
    options.set_capability('appium:udid', corellium_device_appium_udid)
    options.set_capability('appium:appPackage', target_app_package)
    options.set_capability('appium:appActivity', target_app_activity)
    options.set_capability('appium:noReset', False) # set to true for MATRIX runs

    try:
        print("Starting session...")
        driver = webdriver.Remote(appium_server_url, options=options)
        print("Successfully loaded target app.")

        # ==== COPY-PASTE THE EXACT APPIUM INSPECTOR RECORDING SEQUENCE ====

        # ==== END OF COPY-PASTE SECTION ====
        
        sleep(2)
        print("All steps executed on Corellium Android device.")

    except Exception as e:
        print(f"TEST FAILED: {e}")
        raise

    finally:
        print("Terminating app and closing session.")
        driver.terminate_app('com.corellium.cafe') # remove this line for MATRIX runs
        driver.quit()

if __name__ == "__main__":
    match len(argv):
        case 1:
            corellium_device_appium_udid = f'{default_services_ip}:{default_adb_port}'
            print(f"Defaulting to Corellium device at {corellium_device_appium_udid}.")
        case 2:
            target_device_services_ip = argv[1]
            corellium_device_appium_udid = f'{target_device_services_ip}:{default_adb_port}'
            print(f"Running cafe app test on device at {corellium_device_appium_udid}...")
        case _:
            print("ERROR: Please provide zero or pass in the Corellium device services IP.")
            exit(1)

    run_cafe_app_test()
