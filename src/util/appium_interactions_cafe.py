"""
Automate Corellium virtual device interactions using Appium on Corellium Cafe Android app.
"""

import sys
from appium import webdriver
from appium.options.android import UiAutomator2Options
from appium.webdriver.common.appiumby import AppiumBy

# ==== CONSTANTS: CORELLIUM DEVICE ====
DEFAULT_SERVICES_IP = '10.11.1.1'
DEFAULT_ADB_PORT = '5001'

# ==== CONSTANTS: TARGET APP ====
TARGET_APP_PACKAGE = 'com.corellium.cafe'
TARGET_APP_ACTIVITY = '.ui.activities.MainActivity'

# ==== CONSTANTS: APPIUM SERVER ====
APPIUM_SERVER_IP = '127.0.0.1'
APPIUM_SERVER_PORT = '4723'
APPIUM_SERVER_SOCKET = f'http://{APPIUM_SERVER_IP}:{APPIUM_SERVER_PORT}'

def run_app_automation():
    '''Launch the app and interact using Appium commands.'''
    options = UiAutomator2Options()
    options.set_capability('platformName', 'Android')
    options.set_capability('appium:automationName', 'UiAutomator2')
    options.set_capability('appium:udid', corellium_device_appium_udid)
    options.set_capability('appium:appPackage', TARGET_APP_PACKAGE)
    options.set_capability('appium:appActivity', TARGET_APP_ACTIVITY)
    options.set_capability('appium:noReset', True)

    try:
        print("Starting session...")
        driver = webdriver.Remote(APPIUM_SERVER_SOCKET, options=options)
        driver.implicitly_wait(5000)
        print("Successfully loaded target app.")

        # ==== COPY-PASTE THE EXACT APPIUM INSPECTOR RECORDING SEQUENCE ====

        el1 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/emailEditText")
        el1.send_keys("Username123")

        el2 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/passwordEditText")
        el2.send_keys("Password123")

        el3 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/loginButton")
        el3.click()

        el4 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/guestButton")
        el4.click()

        el5 = driver.find_element(by=AppiumBy.ANDROID_UIAUTOMATOR, value="new UiSelector().resourceId(\"com.corellium.cafe:id/ivdrink\").instance(0)")
        el5.click()

        el6 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/fbAdd")
        el6.click()

        el7 = driver.find_element(by=AppiumBy.ACCESSIBILITY_ID, value="Cart")
        el7.click()

        el8 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/tvCheckout")
        el8.click()

        el9 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/firstnameEditText")
        el9.send_keys("Myfirstname")

        el10 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/lastnameEditText")
        el10.send_keys("Mylastname")

        el11 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/phoneEditText")
        el11.send_keys("3216540987")

        el12 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/submitButton")
        el12.click()

        el13 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/etCCNumber")
        el13.send_keys("2345678901234567")

        el14 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/etExpiration")
        el14.send_keys("1234")

        el15 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/etCVV")
        el15.send_keys("135")

        el16 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/etPostalCode")
        el16.send_keys("65432")

        el17 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/bvReviewOrder")
        el17.click()

        el18 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/etPromoCode")
        el18.send_keys("65432")

        el19 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/bvPromoCode")
        el19.click()

        el20 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/bvSubmitOrder")
        el20.click()

        el21 = driver.find_element(by=AppiumBy.ID, value="android:id/button1")
        el21.click()

        # ==== END OF COPY-PASTE SECTION ====

        print("All steps executed on Corellium Android device.")

    except Exception as e:
        print(f"TEST FAILED: {e}")
        raise
    finally:
        print("Closing appium session.")
        driver.quit()

if __name__ == "__main__":
    match len(sys.argv):
        case 1:
            corellium_device_appium_udid = f'{DEFAULT_SERVICES_IP}:{DEFAULT_ADB_PORT}'
            print(f'Defaulting to Corellium device at {DEFAULT_SERVICES_IP}.')
        case 2:
            TARGET_DEVICE_SERVICES_IP = sys.argv[1]
            corellium_device_appium_udid = f'{TARGET_DEVICE_SERVICES_IP}:{DEFAULT_ADB_PORT}'
            print(f'Running app test on device at {corellium_device_appium_udid}...')
        case _:
            print('ERROR: Please provide zero or pass in the Corellium device services IP.')
            sys.exit(1)

    run_app_automation()
