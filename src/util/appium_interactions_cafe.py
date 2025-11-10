"""
Automate Corellium virtual device interactions using Appium on Corellium Cafe Android app.
"""

import time
import os
import sys
from appium import webdriver
from appium.options.android import UiAutomator2Options
from appium.webdriver.common.appiumby import AppiumBy
from selenium.common.exceptions import NoSuchElementException, StaleElementReferenceException

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

def run_app_automation(udid: str):
    '''Launch the app and interact using Appium commands.'''
    options = UiAutomator2Options()
    options.set_capability('platformName', 'Android')
    options.set_capability('appium:automationName', 'UiAutomator2')
    options.set_capability('appium:udid', udid)
    options.set_capability('appium:appPackage', TARGET_APP_PACKAGE)
    options.set_capability('appium:appActivity', TARGET_APP_ACTIVITY)
    options.set_capability('appium:noReset', True)

    try:
        print("Starting session at: ", time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()))
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

        print('DEBUG OPENING MENU')

        el5 = driver.find_element(by=AppiumBy.ACCESSIBILITY_ID, value="Open")
        el5.click()

        print('DEBUG CLICKING ON BLOG MENU ITEM')

        el6 = driver.find_element(by=AppiumBy.ANDROID_UIAUTOMATOR, value="new UiSelector().text(\"Blog\")")
        el6.click()

        print('DEBUG CLICKING ON BLOG BUTTON ON BLOG PAGE')

        el7 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/bvBlog")
        el7.click()

        print('DEBUG WAITING FOR BLOG PAGE TO LOAD')
        time.sleep(10)

        screenshot_path: str = os.path.join(os.getcwd(), "corellium_cafe_blog_page.png")
        print(f"Saving screenshot to {screenshot_path}")
        driver.save_screenshot(screenshot_path)

        el8 = driver.find_element(by=AppiumBy.ANDROID_UIAUTOMATOR, value="new UiSelector().text(\"The Corellium Resource Library \")")
        print('DEBUG CLICKING ON BLOG PAGE HEADER')
        el8.click()

        print('DEBUG OPENING MENU AGAIN')

        el9 = driver.find_element(by=AppiumBy.ACCESSIBILITY_ID, value="Open")
        el9.click()

        print('DEBUG CLICKING ON HOME MENU ITEM')

        el10 = driver.find_element(by=AppiumBy.ANDROID_UIAUTOMATOR, value="new UiSelector().text(\"Home\")")
        el10.click()

        print('DEBUG SUCCESS - BLOG IS FINISHED CONTINUING NOW WITH SCRIPT ')

        el11 = driver.find_element(by=AppiumBy.ANDROID_UIAUTOMATOR, value="new UiSelector().resourceId(\"com.corellium.cafe:id/ivdrink\").instance(0)")
        el11.click()

        el12 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/fbAdd")
        el12.click()

        el13 = driver.find_element(by=AppiumBy.ACCESSIBILITY_ID, value="Cart")
        el13.click()

        el14 = driver.find_element(by=AppiumBy.ANDROID_UIAUTOMATOR, value="new UiSelector().resourceId(\"com.corellium.cafe:id/ivdrink\").instance(0)")
        el14.click()

        el15 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/fbAdd")
        el15.click()

        el16 = driver.find_element(by=AppiumBy.ACCESSIBILITY_ID, value="Cart")
        el16.click()

        el17 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/tvCheckout")
        el17.click()

        el18 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/firstnameEditText")
        el18.send_keys("Myfirstname")

        el19 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/lastnameEditText")
        el19.send_keys("Mylastname")

        el20 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/phoneEditText")
        el20.send_keys("3216540987")

        el21 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/submitButton")
        el21.click()

        el22 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/etCCNumber")
        el22.send_keys("2345678901234567")

        el23 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/etExpiration")
        el23.send_keys("1234")

        el24 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/etCVV")
        el24.send_keys("135")

        el25 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/etPostalCode")
        el25.send_keys("65432")

        el26 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/bvReviewOrder")
        el26.click()

        el27 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/etPromoCode")
        el27.send_keys("65432")

        el28 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/bvPromoCode")
        el28.click()

        el29 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/bvSubmitOrder")
        el29.click()

        el30 = driver.find_element(by=AppiumBy.ID, value="android:id/button1")
        el30.click()

        # ==== END OF COPY-PASTE SECTION ====

        print("All steps executed on Corellium Android device.")

    except NoSuchElementException as e:
        print("Thrown when element could not be found.")
        print("If you encounter this exception, you may want to check the following:")
        print("  * Check your selector used in your find_by...")
        print("  * Element may not yet be on the screen at the time of the find operation,")
        print("    write a wait wrapper to wait for an element to appear.")
        print(f"NoSuchElementException: {e}")
        sys.exit(1)

    except StaleElementReferenceException as e:
        print('Thrown when a reference to an element is now "stale".')
        print("Possible causes of StaleElementReferenceException include, but not limited to:")
        print("  * You are no longer on the same page, or the page may have refreshed since the element")
        print("    was located.")
        print("  * The element may have been removed and re-added to the screen, since it was located.")
        print("    Such as an element being relocated.")
        print("  * Element may have been inside an iframe or another context which was refreshed.")
        print(f"StaleElementReferenceException: {e}")
        sys.exit(1)

    finally:
        print("Closing appium session at: ", time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()))
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

    run_app_automation(corellium_device_appium_udid)
