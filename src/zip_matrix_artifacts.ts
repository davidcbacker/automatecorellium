const { Corellium } = require("@corellium/corellium-api");

const CORELLIUM_API_ENDPOINT = process.env.CORELLIUM_API_ENDPOINT;
const CORELLIUM_API_TOKEN = process.env.CORELLIUM_API_TOKEN;
const MATRIX_INSTANCE_ID = process.env.MATRIX_INSTANCE_ID;
if (!CORELLIUM_API_ENDPOINT || !CORELLIUM_API_TOKEN || !MATRIX_INSTANCE_ID) {
    handleError('Error: Environment variables CORELLIUM_API_ENDPOINT, CORELLIUM_API_TOKEN, and MATRIX_INSTANCE_ID must be set.');
}
const CORELLIUM_API_ENDPOINT_ORIGIN = new URL(CORELLIUM_API_ENDPOINT).origin.toString();

// Define the time constants
const SLEEP_TIME_SECONDS = 60;

// Define the constants for instance states and task states
const INSTANCE_STATE_OFF = 'off';
const INSTANCE_STATE_ON = 'on';
const INSTANCE_STATE_BOOTING = 'booting';
const INSTANCE_STATE_CREATING = 'creating';
const INSTANCE_STATE_REBOOTING = 'rebooting';
const INSTANCE_TASK_STATE_NONE = 'none';

function handleError(error, message = '') {
    if (message) {
        console.error('ERROR:', message);
        if (error) {
            console.error(error);
        }
    } else {
        console.error('ERROR:', error);
    }
    process.exit(1);
}

async function main() {
    try {
        console.log(`Starting the script at ${new Date().toISOString()}.`);
        const zipInputDir = '/tmp/artifacts/';
        const zipOutputPath = '/tmp/matrix_artifacts.zip';

        const corellium = new Corellium({
            endpoint: CORELLIUM_API_ENDPOINT_ORIGIN,
            apiToken: CORELLIUM_API_TOKEN,
        });
        try {
            await corellium.login();
            console.log('Logged in to Corellium successfully.');
        } catch (loginError) {
            handleError(loginError, 'Failed to log in to Corellium. Please check your credentials and endpoint.');
        }

        const instance = await corellium.getInstance(MATRIX_INSTANCE_ID);
        if (!instance) {
            handleError(`Instance with ID ${MATRIX_INSTANCE_ID} not found.`);
        } else if (instance.state !== INSTANCE_STATE_ON) {
            handleError(`Instance with ID ${MATRIX_INSTANCE_ID} is not in the ON state.`);
        }

        const agent = await instance.agent();
        if (!agent) {
            handleError(`Agent for instance with ID ${MATRIX_INSTANCE_ID} not found.`);
        }
        await agent.ready();
        console.log(`Agent for instance ${MATRIX_INSTANCE_ID} is ready.`);

        let installDepsResult = await agent.shellExec('apt -qq install -y zip');
        if (!installDepsResult.success) {
            console.log(installDepsResult);
            handleError('install deps command failed.');
        }
        console.log(installDepsResult.output);

        let zipArtifactsResult = await agent.shellExec(`zip -r ${zipOutputPath} ${zipInputDir}`);
        if (!zipArtifactsResult.success) {
            console.log(zipArtifactsResult);
            handleError('zip command failed.');
        }
        console.log(zipArtifactsResult.output);

        let lsShellExecResult = await agent.shellExec(`ls -l ${zipOutputPath}`);
        if (!lsShellExecResult.success) {
            console.log(lsShellExecResult);
            handleError('ls command failed.');
        }
        console.log(lsShellExecResult.output);

        console.log('Script completed successfully.');
        process.exit(0);
    } catch (error) {
        handleError(error, 'An error occurred during script execution.');
    }
}

main();
