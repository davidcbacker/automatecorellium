"""
Automate Corellium virtual device interactions using Appium on Corellium Cafe Android app.
"""

import os
import signal
import sys
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


class AppiumConfig:
    '''Class to read constants from a json file'''

    def __init__(self, data: dict):
        self.corellium = data["corellium"]
        self.target_app = data["target_app"]
        self.appium_server = data["appium_server"]
        self.timeouts = data["timeouts"]


class AppiumHelper:
    '''Wrapper around appium.webdriver and selenium.WebDriverWait to improve readability and reduce repeated code in interact_with_app().'''

    def __init__(self, config: AppiumAndroudConfig, driver: webdriver.Remote):
        self.driver = driver
        self.wait = WebDriverWait(
            driver=driver,
            timeout=config.timeouts['explicit_wait'],
            ignored_exceptions=[StaleElementReferenceException]
        )


    def save_screenshot(self, filename: str = "screenshot.png"):
        '''Capture a screenshot and save to working directory'''
        screenshot_path: str = os.path.join(os.getcwd(), filename)
        log_stdout(f"Appium - Saving screenshot as {filename}.")
        self.driver.save_screenshot(screenshot_path)
        log_stdout("Appium - Saved screenshot.")


    def set_element_value(self, by, value, desired_value):
        '''Find an element, send keys, then wait until element value'''
        try:
            element = self.driver.find_element(by=by, value=value)
            element.send_keys(desired_value)
            self.wait_until_element_value(by=by, value=value, desired_value=desired_value)
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


    def wait_until_element_value(self, by, value, desired_value):
        '''Wait until text is present in an element value then return the elemeent'''
        try:
            locator = (by, value)
            return self.wait.until(text_to_be_present_in_element(locator, text_=desired_value))
        except TimeoutException as e:
            print(f"Timeout: Element value '{desired_value}' not present after "
                  f"{APPIUM_DRIVER_EXPLICITLY_WAIT} seconds.")
            print(f"TimeoutException: {e}")
            sys.exit(1)


# =====================================
# ==== BEGIN CONSTANTS DEFINITIONS ====
# =====================================

# ==== TARGET APP ====
TARGET_APP_PACKAGE: str = 'com.corellium.cafe'
TARGET_APP_ACTIVITY: str = '.ui.activities.MainActivity'
TARGET_APP_LOGIN_PAGE_SCREENSHOT_FILENAME: str = os.getenv(
    key='CORELLIUM_CAFE_LOGIN_PAGE_SCREENSHOT_FILENAME',
    default='cafe_login_page.png'
)
TARGET_APP_BLOG_PAGE_SCREENSHOT_FILENAME: str = os.getenv(
    key='CORELLIUM_CAFE_BLOG_PAGE_SCREENSHOT_FILENAME',
    default='cafe_blog_page.png'
)
TARGET_APP_CUSTOMER_PAGE_SCREENSHOT_FILENAME: str = os.getenv(
    key='CORELLIUM_CAFE_CUSTOMER_PAGE_SCREENSHOT_FILENAME',
    default='cafe_customer_page.png'
)
TARGET_APP_PAYMENT_PAGE_SCREENSHOT_FILENAME: str = os.getenv(
    key='CORELLIUM_CAFE_PAYMENT_PAGE_SCREENSHOT_FILENAME',
    default='cafe_payment_page.png'
)

# ==== APPIUM SERVER ====

# ==== APPIUM DRIVER ====
APPIUM_DRIVER_IMPLICITLY_WAIT: int = 5 # seconds
APPIUM_DRIVER_EXPLICITLY_WAIT: int = 20 # seconds

# ==== APPIUM AUTOMATION TIMEOUT ====
APPIUM_AUTOMATION_ALARM_TIMEOUT: int = 90 # seconds


# =====================================
# ===== END CONSTANTS DEFINITIONS =====
# =====================================

def interact_with_app(config: AppiumAndroidConfig, helper: AppiumHelper):
    '''Interact with the target app using Appium commands.'''

    log_stdout("Appium - Interact with login page.")
    helper.set_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/emailEditText", desired_value="Hello@corellium.com")
    helper.set_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/passwordEditText", desired_value="Password123")
    el3 = helper.wait_until_clickable(by=AppiumBy.ID, value="com.corellium.cafe:id/loginButton")
    el3.click()
    helper.save_screenshot(filename=config.screenshots['asdf'])
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
    log_stdout('Appium - Interact with blog page.')
    helper.set_element_value(by=AppiumBy.CLASS_NAME, value="android.widget.EditText", desired_value="Testing")
    helper.save_screenshot(filename=config.screenshots['asdf'])

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

    log_stdout("Appium - Fill in customer info.")
    helper.set_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/firstnameEditText", desired_value="Firstname")
    helper.set_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/lastnameEditText", desired_value="Lastname")
    helper.set_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/phoneEditText", desired_value="3216540987")
    helper.save_screenshot(filename=config.screenshots['asdf'])
    log_stdout("Appium - Submit customer info.")
    el18 = helper.wait_until_clickable(by=AppiumBy.ID, value="com.corellium.cafe:id/submitButton")
    el18.click()

    log_stdout("Appium - Fill in payment info.")
    helper.set_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/etCCNumber", desired_value="2345678901234567")
    helper.set_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/etExpiration", desired_value="1234")
    helper.set_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/etCVV", desired_value="135")
    helper.set_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/etPostalCode", desired_value="24680")
    helper.save_screenshot(filename=config.screenshots['asdf'])
    log_stdout("Appium - Submit payment info.")
    el23 = helper.wait_until_clickable(by=AppiumBy.ID, value="com.corellium.cafe:id/bvReviewOrder")
    el23.click()

    log_stdout("Appium - Enter invalid promo code.")
    helper.set_element_value(by=AppiumBy.ID, value="com.corellium.cafe:id/etPromoCode", desired_value="65432")
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


class AlarmTimeoutException(Exception):
    '''Exception raised when a SIGALRM signal triggers a timeout during Appium automation.'''


def alarm_timeout_handler(signum, frame):
    '''Signal handler for SIGALRM that raises an AlarmTimeoutException.'''
    raise AlarmTimeoutException("Appium automation timed out.")


def run_app_automation(config: AppiumAndroidConfig, udid: str):
    '''Launch the app and interact using Appium commands.'''

    APPIUM_SERVER_IP: str = config.appium['server_ip']
    APPIUM_SERVER_PORT: str = config.appium['port']
    APPIUM_SERVER_SOCKET: str = f'http://{APPIUM_SERVER_IP}:{APPIUM_SERVER_PORT}'

    options = UiAutomator2Options()
    options.set_capability('platformName', 'Android')
    options.set_capability('appium:automationName', 'UiAutomator2')
    options.set_capability('appium:udid', udid)
    options.set_capability('appium:appPackage', config.target_app['package_name'])
    options.set_capability('appium:appActivity', config.target_app['activity'])
    options.set_capability('appium:noReset', True)
    options.adb_exec_timeout = 40000

    signal.signal(signal.SIGALRM, alarm_timeout_handler)
    log_stdout(f"Setting Appium alarm timeout for {config.timeouts['asdf']} seconds.")
    signal.alarm(config.timeouts['asdf'])

    try:
        log_stdout("Loading target app in Appium session.")
        driver = webdriver.Remote(command_executor=APPIUM_SERVER_SOCKET, options=options)
        log_stdout("Successfully loaded target app.")
        driver.implicitly_wait(time_to_wait=config.timeouts['implicit_wait'])
        log_stdout("Starting app interactions.")
        interact_with_app(helper=AppiumHelper(config=config, driver=driver))
        log_stdout("Finished app interactions.")

    except AlarmTimeoutException as e:
        print(f"Appium automation timed out after {config.timeouts['asdf']} seconds.", file=sys.stderr)
        print(f"AlarmTimeoutException: {e}", file=sys.stderr)
        sys.exit(1)

    except NoSuchElementException as e:
        print("Thrown when element could not be found.", file=sys.stderr)
        print("If you encounter this exception, you may want to check the following:", file=sys.stderr)
        print("  * Check your selector used in your find_by...", file=sys.stderr)
        print("  * Element may not yet be on the screen at the time of the find operation,", file=sys.stderr)
        print("    write a wait wrapper to wait for an element to appear.", file=sys.stderr)
        print(f"NoSuchElementException: {e}", file=sys.stderr)
        sys.exit(1)

    except StaleElementReferenceException as e:
        print('Thrown when a reference to an element is now "stale".', file=sys.stderr)
        print("Possible causes of StaleElementReferenceException include, but not limited to:", file=sys.stderr)
        print("  * You are no longer on the same page, or the page may have refreshed since the element", file=sys.stderr)
        print("    was located.", file=sys.stderr)
        print("  * The element may have been removed and re-added to the screen, since it was located.", file=sys.stderr)
        print("    Such as an element being relocated.", file=sys.stderr)
        print("  * Element may have been inside an iframe or another context which was refreshed.", file=sys.stderr)
        print(f"StaleElementReferenceException: {e}", file=sys.stderr)
        sys.exit(1)

    except WebDriverException as e:
        print('Base webdriver exception.', file=sys.stderr)
        print(f"WebDriverException: {e}", file=sys.stderr)
        sys.exit(1)

    finally:
        signal.alarm(0)
        log_stdout("Closing appium session.")
        driver.quit()
        log_stdout("Closed appium session.")


if __name__ == "__main__":
    config = AppiumAndroidConfig(config)
    match len(sys.argv):
        case 1:
            TARGET_DEVICE_SERVICES_IP = config.corellium['default_services_ip']
            corellium_device_appium_udid = f'{TARGET_DEVICE_SERVICES_IP}:{config.corellium['default_adb_port']}'
            log_stdout(f'Defaulting to Corellium virtual device at {TARGET_DEVICE_SERVICES_IP}.')
        case 2:
            TARGET_DEVICE_SERVICES_IP = sys.argv[1]
            corellium_device_appium_udid = f'{TARGET_DEVICE_SERVICES_IP}:{config.corellium['default_adb_port']}'
            log_stdout(f'Using Corellium virtual device at {corellium_device_appium_udid}.')
        case _:
            print('ERROR: Please provide zero arguments or pass in the Corellium device services IP.', file=sys.stderr)
            sys.exit(1)
    run_app_automation(config, corellium_device_appium_udid)
