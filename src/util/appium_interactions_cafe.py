"""
Automate Corellium virtual device interactions using Appium on Corellium Cafe Android app.
"""

import os
import sys
import time
from datetime import datetime, timezone
from appium import webdriver
from appium.options.android import UiAutomator2Options
from appium.webdriver.common.appiumby import AppiumBy
from selenium.common.exceptions import NoSuchElementException, StaleElementReferenceException, TimeoutException
from selenium.webdriver.support.expected_conditions import element_to_be_clickable
from selenium.webdriver.support.ui import WebDriverWait

# =====================================
# ==== BEGIN CONSTANTS DEFINITIONS ====
# =====================================

# ==== CORELLIUM DEVICE ====
DEFAULT_SERVICES_IP = '10.11.1.1'
DEFAULT_ADB_PORT = '5001'

# ==== TARGET APP ====
TARGET_APP_PACKAGE = 'com.corellium.cafe'
TARGET_APP_ACTIVITY = '.ui.activities.MainActivity'
TARGET_APP_BLOG_PAGE_SCREENSHOT_FILENAME = os.getenv('CORELLIUM_CAFE_BLOG_PAGE_SCREENSHOT_FILENAME')
TARGET_APP_CUSTOMER_INFO_SCREENSHOT_FILENAME = os.getenv('CORELLIUM_CAFE_CUSTOMER_INFO_SCREENSHOT_FILENAME')
TARGET_APP_PAYMENT_INFO_SCREENSHOT_FILENAME = os.getenv('CORELLIUM_CAFE_PAYMENT_INFO_SCREENSHOT_FILENAME')

# ==== APPIUM SERVER ====
APPIUM_SERVER_IP = '127.0.0.1'
APPIUM_SERVER_PORT = '4723'
APPIUM_SERVER_SOCKET = f'http://{APPIUM_SERVER_IP}:{APPIUM_SERVER_PORT}'

# ==== APPIUM DRIVER ====
APPIUM_DRIVER_IMPLICITLY_WAIT=5 # seconds
APPIUM_DRIVER_EXPLICITLY_WAIT=20 # seconds

# =====================================
# ===== END CONSTANTS DEFINITIONS =====
# =====================================

def interact_with_app(driver: webdriver.Remote, driver_wait: WebDriverWait):
    '''Interact with the target app using Appium commands.'''

    log_stdout("Appium - Interact with login page.")

    el1 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/emailEditText")
    el1.send_keys("Username123")

    el2 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/passwordEditText")
    el2.send_keys("Password123")

    el3 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/loginButton")
    el3.click()

    el4 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/guestButton")
    el4.click()

    log_stdout("Appium - Open blog page.")

    el5 = driver.find_element(by=AppiumBy.ACCESSIBILITY_ID, value="Open")
    el5.click()

    el6 = driver.find_element(by=AppiumBy.ANDROID_UIAUTOMATOR, value="new UiSelector().text(\"Blog\")")
    el6.click()

    el7 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/bvBlog")
    el7.click()

    page_load_sleep_time_seconds=5
    log_stdout(f"Waiting {page_load_sleep_time_seconds} seconds for blog page to load.")
    time.sleep(page_load_sleep_time_seconds)
    # instead of sleep, figure out a way to confirm that the blog page loaded with find_element or wait_until_clickable
    # el8 = driver.find_element(by=AppiumBy.ANDROID_UIAUTOMATOR, value="new UiSelector().text(\"The Corellium Resource Library \")")
    # log_stdout('DEBUG CLICKING ON BLOG PAGE HEADER')
    # el8.click()

    save_screenshot(driver, TARGET_APP_BLOG_PAGE_SCREENSHOT_FILENAME)

    log_stdout("Appium - Return to home page.")

    el9 = driver.find_element(by=AppiumBy.ACCESSIBILITY_ID, value="Open")
    el9.click()

    el10 = driver.find_element(by=AppiumBy.ANDROID_UIAUTOMATOR, value="new UiSelector().text(\"Home\")")
    el10.click()

    log_stdout("Appium - Add the first coffee option to cart.")

    el11 = driver.find_element(by=AppiumBy.ANDROID_UIAUTOMATOR, value="new UiSelector().resourceId(\"com.corellium.cafe:id/ivdrink\").instance(0)")
    el11.click()

    el12 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/fbAdd")
    el12.click()

    log_stdout("Appium - Open cart and begin checkout.")

    el13 = wait_until_clickable(by=AppiumBy.ACCESSIBILITY_ID, value="Cart", wait=driver_wait)
    el13.click()

    el14 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/tvCheckout")
    el14.click()

    log_stdout("Appium - Fill in customner info.")

    el15 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/firstnameEditText")
    el15.send_keys("Myfirstname")

    el16 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/lastnameEditText")
    el16.send_keys("Mylastname")

    el17 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/phoneEditText")
    el17.send_keys("3216540987")

    time.sleep(page_load_sleep_time_seconds)
    save_screenshot(driver, TARGET_APP_CUSTOMER_INFO_SCREENSHOT_FILENAME)

    el18 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/submitButton")
    el18.click()

    log_stdout("Appium - Fill in payment info.")

    el19 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/etCCNumber")
    el19.send_keys("2345678901234567")

    el20 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/etExpiration")
    el20.send_keys("1234")

    el21 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/etCVV")
    el21.send_keys("135")

    el22 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/etPostalCode")
    el22.send_keys("65432")

    time.sleep(page_load_sleep_time_seconds)
    save_screenshot(driver, TARGET_APP_PAYMENT_INFO_SCREENSHOT_FILENAME)

    el23 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/bvReviewOrder")
    el23.click()

    log_stdout("Appium - Enter fake promo code.")

    el24 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/etPromoCode")
    el24.send_keys("65432")

    el25 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/bvPromoCode")
    el25.click()

    log_stdout("Appium - Submit order.")

    el26 = driver.find_element(by=AppiumBy.ID, value="com.corellium.cafe:id/bvSubmitOrder")
    el26.click()

    el27 = driver.find_element(by=AppiumBy.ID, value="android:id/button1")
    el27.click()

def wait_until_clickable(by, value, wait):
    '''Wait for a webdriver locator to be clickable'''
    try:
        element_locator = (by, value)
        clickable_element = wait.until(element_to_be_clickable(element_locator))
        return clickable_element
    except TimeoutException as e:
        print("Thrown when a command does not complete in enough time.")
        print(f"Element not clickable after {APPIUM_DRIVER_EXPLICITLY_WAIT} seconds.")
        print(f"TimeoutException: {e}")
        sys.exit(1)

def log_stdout(message: str):
    '''Print message to stdout with current timestamp'''
    current_datetime = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
    print(f"[-] {current_datetime} INFO: {message}")

def save_screenshot(driver: webdriver.Remote, filename: str):
    '''Capture a screenshot and save to working directory'''
    screenshot_path: str = os.path.join(os.getcwd(), filename)
    log_stdout(f"Appium - Screenshot path is {screenshot_path}.")
    driver.save_screenshot(screenshot_path)
    log_stdout("Appium - Saved screenshot.")

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
        log_stdout("Loading target app in Appium session.")
        driver = webdriver.Remote(APPIUM_SERVER_SOCKET, options=options)
        log_stdout("Successfully loaded target app.")
        driver.implicitly_wait(APPIUM_DRIVER_IMPLICITLY_WAIT * 1000)
        driver_wait = WebDriverWait(driver, APPIUM_DRIVER_EXPLICITLY_WAIT, ignored_exceptions=[StaleElementReferenceException])
        log_stdout("Starting app interactions on virtual device.")
        interact_with_app(driver, driver_wait)
        log_stdout("Finished app interactions on virtual device.")

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
        log_stdout("Closing appium session.")
        driver.quit()
        log_stdout("Closed appium session.")

if __name__ == "__main__":
    match len(sys.argv):
        case 1:
            corellium_device_appium_udid = f'{DEFAULT_SERVICES_IP}:{DEFAULT_ADB_PORT}'
            log_stdout(f'Defaulting to Corellium device at {DEFAULT_SERVICES_IP}.')
        case 2:
            TARGET_DEVICE_SERVICES_IP = sys.argv[1]
            corellium_device_appium_udid = f'{TARGET_DEVICE_SERVICES_IP}:{DEFAULT_ADB_PORT}'
            log_stdout(f'Using Corellium device at {corellium_device_appium_udid}.')
        case _:
            print('ERROR: Please provide zero arguments or pass in the Corellium device services IP.')
            sys.exit(1)

    run_app_automation(corellium_device_appium_udid)
