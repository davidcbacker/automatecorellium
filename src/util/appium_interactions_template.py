"""
Automate Corellium virtual device interactions using Appium on Android apps.
"""

from time import sleep
import sys
from appium import webdriver
from appium.options.android import UiAutomator2Options
from appium.webdriver.common.appiumby import AppiumBy

# ==== CONSTANTS: CORELLIUM DEVICE ====
DEFAULT_SERVICES_IP = '10.11.1.1'
DEFAULT_ADB_PORT = '5001'

# ==== CONSTANTS: TARGET APP ====
TARGET_APP_PACKAGE = 'com.mypackage.name'
TARGET_APP_ACTIVITY = '.MainActivity'

# ==== CONSTANTS: APPIUM SERVER ====
APPIUM_SERVER_IP = '127.0.0.1'
APPIUM_SERVER_PORT = '4723'
APPIUM_SERVER_SOCKET = f'http://{APPIUM_SERVER_IP}:{APPIUM_SERVER_PORT}'

def run_app_automation():
    '''Launch the app and interact using Appium commands.'''
    options = UiAutomator2Options()
    options.set_capability('platformName', 'Android')
    options.set_capability('appium:automationName', 'UiAutomator2')
    options.set_capability('appium:udid', CORELLIUM_DEVICE_APPIUM_UDID)
    options.set_capability('appium:appPackage', TARGET_APP_PACKAGE)
    options.set_capability('appium:appActivity', TARGET_APP_ACTIVITY)
    options.set_capability('appium:noReset', False) # set to true for MATRIX runs

    try:
        print("Starting session...")
        driver = webdriver.Remote(APPIUM_SERVER_SOCKET, options=options)
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
        driver.terminate_app(TARGET_APP_PACKAGE) # remove this line for MATRIX runs
        driver.quit()

if __name__ == "__main__":
    match len(sys.argv):
        case 1:
            CORELLIUM_DEVICE_APPIUM_UDID = f'{DEFAULT_SERVICES_IP}:{DEFAULT_ADB_PORT}'
            print(f'Defaulting to Corellium device at {DEFAULT_SERVICES_IP}.')
        case 2:
            TARGET_DEVICE_SERVICES_IP = sys.argv[1]
            CORELLIUM_DEVICE_APPIUM_UDID = f'{TARGET_DEVICE_SERVICES_IP}:{DEFAULT_ADB_PORT}'
            print(f'Running app test on device at {CORELLIUM_DEVICE_APPIUM_UDID}...')
        case _:
            print('ERROR: Please provide zero or pass in the Corellium device services IP.')
            sys.exit(1)

    run_app_automation()
