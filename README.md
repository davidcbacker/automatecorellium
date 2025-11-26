# automatecorellium

## CI Health Checks

See the current CI pass/fail status of dynamic and static checks.

### Most recent commit

[![Check changes to master](https://github.com/davidcbacker/automatecorellium/actions/workflows/changes.yaml/badge.svg?event=push&branch=master)](https://github.com/davidcbacker/automatecorellium/actions/workflows/changes.yaml?query=event%3Apush+branch%3Amaster)

### Scheduled runs

[![Corellium MATRIX with Appium](https://github.com/davidcbacker/automatecorellium/actions/workflows/matrix_with_appium.yaml/badge.svg?event=schedule&branch=master)](https://github.com/davidcbacker/automatecorellium/actions/workflows/matrix_with_appium.yaml?query=event%3Aschedule+branch%3Amaster)
[![Run Frida on Corellium](https://github.com/davidcbacker/automatecorellium/actions/workflows/frida.yaml/badge.svg?event=schedule&branch=master)]([https://github.com/davidcbacker/automatecorellium/actions/workflows/frida.yaml](https://github.com/davidcbacker/automatecorellium/actions/workflows/matrix_with_appium.yaml?query=event%3Aschedule+branch%3Amaster))

### Scheduled start, stop, and delete runs

[![Start Corellium devices](https://github.com/davidcbacker/automatecorellium/actions/workflows/start_devices.yaml/badge.svg?event=schedule&branch=master)](https://github.com/davidcbacker/automatecorellium/actions/workflows/start_devices.yaml?query=event%3Aschedule+branch%3Amaster)
[![Stop Corellium devices](https://github.com/davidcbacker/automatecorellium/actions/workflows/stop_devices.yaml/badge.svg?event=schedule&branch=master)](https://github.com/davidcbacker/automatecorellium/actions/workflows/stop_devices.yaml?query=event%3Aschedule+branch%3Amaster)
[![Delete Corellium devices](https://github.com/davidcbacker/automatecorellium/actions/workflows/delete_devices.yaml/badge.svg?event=schedule&branch=master)](https://github.com/davidcbacker/automatecorellium/actions/workflows/delete_devices.yaml?query=event%3Aschedule+branch%3Amaster)

## Setup Instructions

1. Add the appropriate `yaml` files and copy `functions.sh` to your GitHub repository
2. Set the `CORELLIUM_API_ENDPOINT` secrets to the domain for your server
   - For example, `https://exampledomain.enterprise.corellium.com` or `https://corellium.examplecompany.com`
3. Set the `CORELLIUM_API_TOKEN` secret ([our API Token documentation](https://support.corellium.com/administration/api-token))
