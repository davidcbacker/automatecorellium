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
