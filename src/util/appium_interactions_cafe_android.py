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
from selenium.common.exceptions import (
    NoSuchElementException,
    StaleElementReferenceException,
    TimeoutException,
    WebDriverException,
)
from selenium.webdriver.support.expected_conditions import (
    element_to_be_clickable,
    text_to_be_present_in_element,
    visibility_of_element_located,
)
from selenium.webdriver.support.ui import WebDriverWait

class AppiumHelper:
    """Wrapper around Appium driver + WebDriverWait to avoid passing them through the helper functions."""

    def __init__(self, driver: webdriver.Remote, wait: WebDriverWait):
        self.driver = driver
        self.wait = wait


    def save_screenshot(self, filename: str = "screenshot.png"):
        '''Capture a screenshot and save to working directory'''
        screenshot_path: str = os.path.join(os.getcwd(), filename)
        log_stdout(f"Appium - Saving screenshot as {filename}.")
        self.driver.save_screenshot(screenshot_path)
        log_stdout("Appium - Saved screenshot.")


    def set_then_wait_until_element_value(self, by, value, expected_value):
        '''Find an element, send keys, then wait until element value'''
        try:
            found_element = self.driver.find_element(by=by, value=value)
            found_element.send_keys(expected_value)
            self.wait_until_element_value(by=by, value=value, expected_value=expected_value)
        except TimeoutException as e:
            print(f"Timeout: Element not clickable after {APPIUM_DRIVER_EXPLICITLY_WAIT} seconds.")
            print(f"TimeoutException: {e}")
            sys.exit(1)


    def wait_until_clickable(self, by, value):
        '''Wait until an element is clickable then return the element'''
        try:
            locator = (by, value)
            return self.wait.until(element_to_be_clickable(locator))
        except TimeoutException as e:
            print("Timeout: Element not clickable after "
                  f"{APPIUM_DRIVER_EXPLICITLY_WAIT} seconds.")
            print(f"TimeoutException: {e}")
            sys.exit(1)


    def wait_until_visible(self, by, value):
        '''Wait until an element is visible then return the element'''
        try:
            locator = (by, value)
            return self.wait.until(visibility_of_element_located(locator))
        except TimeoutException as e:
            print("Timeout: Element not visible after "
                  f"{APPIUM_DRIVER_EXPLICITLY_WAIT} seconds.")
            print(f"TimeoutException: {e}")
            sys.exit(1)


    def wait_until_element_value(self, by, value, expected_value):
        '''Wait until text is present in an element value then return the elemeent'''
        try:
            locator = (by, value)
            return self.wait.until(text_to_be_present_in_element(locator, expected_value))
        except TimeoutException as e:
            print(f"Timeout: Element value '{expected_value}' not present after "
                  f"{APPIUM_DRIVER_EXPLICITLY_WAIT} seconds.")
            print(f"TimeoutException: {e}")
            sys.exit(1)

# =====================================
# ==== BEGIN CONSTANTS DEFINITIONS ====
# =====================================

# ==== CORELLIUM DEVICE ====
DEFAULT_SERVICES_IP = '10.11.1.1'
DEFAULT_ADB_PORT = '5001'

# ==== TARGET APP ====
TARGET_APP_PACKAGE = 'com.corellium.cafe'
TARGET_APP_ACTIVITY = '.ui.activities.MainActivity'
TARGET_APP_LOGIN_PAGE_SCREENSHOT_FILENAME = os.getenv('CORELLIUM_CAFE_LOGIN_PAGE_SCREENSHOT_FILENAME', 'cafe_login_page.png')
TARGET_APP_BLOG_PAGE_SCREENSHOT_FILENAME = os.getenv('CORELLIUM_CAFE_BLOG_PAGE_SCREENSHOT_FILENAME', 'cafe_blog_page.png')
TARGET_APP_CUSTOMER_PAGE_SCREENSHOT_FILENAME = os.getenv('CORELLIUM_CAFE_CUSTOMER_PAGE_SCREENSHOT_FILENAME', 'cafe_custmer_page.png')
TARGET_APP_PAYMENT_PAGE_SCREENSHOT_FILENAME = os.getenv('CORELLIUM_CAFE_PAYMENT_PAGE_SCREENSHOT_FILENAME', 'cafe_payment_page.png')

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

def interact_with_app(helper: AppiumHelper):
    '''Interact with the target app using Appium commands.'''

    log_stdout("Appium - Interact with login page.")
    helper.set_then_wait_until_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/emailEditText", expected_value="Hello@corellium.com")
    helper.set_then_wait_until_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/passwordEditText", expected_value="Password123")
    el3 = helper.wait_until_clickable(by=AppiumBy.ID, value="com.corellium.cafe:id/loginButton")
    el3.click()
    helper.save_screenshot(TARGET_APP_LOGIN_PAGE_SCREENSHOT_FILENAME)
    el4 = helper.wait_until_clickable(by=AppiumBy.ID, value="com.corellium.cafe:id/guestButton")
    el4.click()

    log_stdout("Appium - Open blog page.")
    el5 = helper.wait_until_clickable(by=AppiumBy.ACCESSIBILITY_ID, value="Open")
    el5.click()
    el6 = helper.wait_until_clickable(by=AppiumBy.ANDROID_UIAUTOMATOR, value="new UiSelector().text(\"Blog\")")
    el6.click()
    el7 = helper.wait_until_clickable(by=AppiumBy.ID, value="com.corellium.cafe:id/bvBlog")
    el7.click()

    log_stdout('Appium - Wait for blog page to load.')
    helper.wait_until_visible(by=AppiumBy.CLASS_NAME, value="android.widget.EditText")
    helper.set_then_wait_until_element_value(by=AppiumBy.CLASS_NAME, value="android.widget.EditText", expected_value="Testing")
    helper.save_screenshot(TARGET_APP_BLOG_PAGE_SCREENSHOT_FILENAME)

    log_stdout("Appium - Return to home page.")
    el9 = helper.wait_until_clickable(by=AppiumBy.ACCESSIBILITY_ID, value="Open")
    el9.click()
    el10 = helper.wait_until_clickable(by=AppiumBy.ANDROID_UIAUTOMATOR, value="new UiSelector().text(\"Home\")")
    el10.click()

    log_stdout("Appium - Add the first coffee option to cart.")
    el11 = helper.wait_until_clickable(by=AppiumBy.ANDROID_UIAUTOMATOR, value="new UiSelector().resourceId(\"com.corellium.cafe:id/ivdrink\").instance(0)")
    el11.click()
    el12 = helper.wait_until_clickable(by=AppiumBy.ID, value="com.corellium.cafe:id/fbAdd")
    el12.click()

    log_stdout("Appium - Open cart and begin checkout.")
    el13 = helper.wait_until_clickable(by=AppiumBy.ID, value="com.corellium.cafe:id/abmCart")
    el13.click()
    el14 = helper.wait_until_clickable(by=AppiumBy.ID, value="com.corellium.cafe:id/tvCheckout")
    el14.click()

    log_stdout("Appium - Fill in customner info.")
    helper.set_then_wait_until_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/firstnameEditText", expected_value="Firstname")
    helper.set_then_wait_until_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/lastnameEditText", expected_value="Lastname")
    helper.set_then_wait_until_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/phoneEditText", expected_value="3216540987")
    helper.save_screenshot(TARGET_APP_CUSTOMER_PAGE_SCREENSHOT_FILENAME)
    log_stdout("Appium - Submit customner info.")
    el18 = helper.wait_until_clickable(by=AppiumBy.ID, value="com.corellium.cafe:id/submitButton")
    el18.click()

    log_stdout("Appium - Fill in payment info.")
    helper.set_then_wait_until_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/etCCNumber", expected_value="2345678901234567")
    helper.set_then_wait_until_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/etExpiration", expected_value="1234")
    helper.set_then_wait_until_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/etCVV", expected_value="135")
    helper.set_then_wait_until_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/etPostalCode", expected_value="24680")
    helper.save_screenshot(TARGET_APP_PAYMENT_PAGE_SCREENSHOT_FILENAME)
    log_stdout("Appium - Submit payment info.")
    el23 = helper.wait_until_clickable(by=AppiumBy.ID, value="com.corellium.cafe:id/bvReviewOrder")
    el23.click()

    log_stdout("Appium - Enter invalid promo code.")
    helper.set_then_wait_until_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/etPromoCode", expected_value="65432")
    el25 = helper.wait_until_clickable(by=AppiumBy.ID, value="com.corellium.cafe:id/bvPromoCode")
    el25.click()

    log_stdout("Appium - Submit order.")
    el26 = helper.wait_until_clickable(by=AppiumBy.ID, value="com.corellium.cafe:id/bvSubmitOrder")
    el26.click()
    el27 = helper.wait_until_clickable(by=AppiumBy.ID, value="android:id/button1")
    el27.click()


def log_stdout(message: str):
    '''Print message to stdout with current timestamp'''
    current_datetime = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
    print(f"[-] {current_datetime} INFO: {message}")


def run_app_automation(udid: str):
    '''Launch the app and interact using Appium commands.'''
    options = UiAutomator2Options()
    options.set_capability('platformName', 'Android')
    options.set_capability('appium:automationName', 'UiAutomator2')
    options.set_capability('appium:udid', udid)
    options.set_capability('appium:appPackage', TARGET_APP_PACKAGE)
    options.set_capability('appium:appActivity', TARGET_APP_ACTIVITY)
    options.set_capability('appium:noReset', True)
    options.adb_exec_timeout = 40000

    try:
        log_stdout("Loading target app in Appium session.")
        driver = webdriver.Remote(APPIUM_SERVER_SOCKET, options=options)
        log_stdout("Successfully loaded target app.")
        driver.implicitly_wait(APPIUM_DRIVER_IMPLICITLY_WAIT * 1000)
        driver_wait = WebDriverWait(driver, APPIUM_DRIVER_EXPLICITLY_WAIT, ignored_exceptions=[StaleElementReferenceException])
        helper = AppiumHelper(driver, driver_wait)
        log_stdout("Starting app interactions.")
        interact_with_app(helper)
        log_stdout("Finished app interactions.")

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

    except WebDriverException as e:
        print('Base webdriver exception.')
        print(f"WebDriverException: {e}")
        sys.exit(1)

    finally:
        log_stdout("Closing appium session.")
        driver.quit()
        log_stdout("Closed appium session.")


if __name__ == "__main__":
    match len(sys.argv):
        case 1:
            corellium_device_appium_udid = f'{DEFAULT_SERVICES_IP}:{DEFAULT_ADB_PORT}'
            log_stdout(f'Defaulting to Corellium virtual device at {DEFAULT_SERVICES_IP}.')
        case 2:
            TARGET_DEVICE_SERVICES_IP = sys.argv[1]
            corellium_device_appium_udid = f'{TARGET_DEVICE_SERVICES_IP}:{DEFAULT_ADB_PORT}'
            log_stdout(f'Using Corellium virtual device at {corellium_device_appium_udid}.')
        case _:
            print('ERROR: Please provide zero arguments or pass in the Corellium device services IP.')
            sys.exit(1)

    run_app_automation(corellium_device_appium_udid)
