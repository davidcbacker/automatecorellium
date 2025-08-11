import { Corellium } from "@corellium/corellium-api";

const CORELLIUM_API_ENDPOINT = process.env.CORELLIUM_API_ENDPOINT;
const CORELLIUM_API_TOKEN = process.env.CORELLIUM_API_TOKEN;
const MATRIX_INSTANCE_ID = process.env.MATRIX_INSTANCE_ID;
if (!CORELLIUM_API_ENDPOINT || !CORELLIUM_API_TOKEN || !MATRIX_INSTANCE_ID) {
    handleError('Error: Environment variables CORELLIUM_API_ENDPOINT, CORELLIUM_API_TOKEN, and MATRIX_INSTANCE_ID must be set.');
}
const CORELLIUM_API_ENDPOINT_ORIGIN = new URL(CORELLIUM_API_ENDPOINT).origin.toString();
const INSTANCE_STATE_ON = 'on';

function handleError(error, message = '') {
    (message)
        ? console.error('ERROR:', message, error)
        : console.error('ERROR:', error);
    process.exit(1);
}

async function execCommandOnInstance(agent, command) {
    try {
        console.log(`Executing command on instance: ${command}`);
        const result = await agent.shellExec(command);
        if (!result.success) {
            console.error(result);
            throw new Error(`Command execution failed: ${command}`);
        }
        console.log(result.output);
    } catch (error) {
        console.error('ERROR in execCommandOnInstance:', error);
    }
}

async function main() {
    try {
        console.log(`Starting the script at ${new Date().toISOString()}.`);
        const zipInputArtifactsDir = '/tmp/artifacts/';
        const zipInputAssessmentsDir = '/tmp/assessment.*/';
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

        await execCommandOnInstance(agent, 'apt -qq install -y zip');
        await execCommandOnInstance(agent, `zip -r ${zipOutputPath} ${zipInputArtifactsDir} ${zipInputAssessmentsDir}`);
        await execCommandOnInstance(agent, `ls -l ${zipOutputPath}`);
        await execCommandOnInstance(agent, `sha256sum ${zipOutputPath}`);

        console.log('Script completed successfully.');
        process.exit(0);
    } catch (error) {
        handleError(error, 'An error occurred during script execution.');
    }
}

main();
