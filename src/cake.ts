import path = require('path');
import tl = require('azure-pipelines-task-lib/task.js');
import { ToolRunner } from 'azure-pipelines-task-lib/toolrunner.js';

async function run() {
    // Disables telemetry and first time experience
    tl.setVariable("DOTNET_CLI_TELEMETRY_OPTOUT", '1');
    tl.setVariable("DOTNET_SKIP_FIRST_TIME_EXPERIENCE", '1');

    // Input Variables from Task
    const $script = tl.getInput('script', true) || 'build.cake';
    const $target = tl.getInput('target', true) || 'Default';
    let $verbosity = tl.getInput('verbosity', true) || 'Normal';
    const $arguments = tl.getInput('arguments') || '';
    const $toolFeedUrl = tl.getInput('toolFeedUrl') || '';
    const $bootstrap = tl.getBoolInput('bootstrap') || false;
    const $version = tl.getInput('version') || '';

    // Local Variables
    const rootPath = path.dirname(path.resolve($script));
    const $toolPath = path.join(rootPath, 'tools');
    const cakeToolPath = path.join($toolPath, tl.getPlatform() !== tl.Platform.Windows ? 'dotnet-cake' : 'dotnet-cake.exe');

    const systemDiagnosticsRequested = tl.getVariable('system.debug');
    if(systemDiagnosticsRequested) {
        $verbosity = 'Diagnostic';
    }

    console.log('=====================================================');
    console.log(`Root = ${rootPath}`);
    console.log(`Tools = ${$toolPath}`);
    console.log(`Cake Tool Path = ${cakeToolPath}`);
    console.log(`Package Feed = ${$toolFeedUrl}`);
    if(systemDiagnosticsRequested) {
        console.log(`running with system diagnostics`);
    }
    console.log('=====================================================');

    // Check if there's a tools directory.
    if (!tl.exist($toolPath)) {
        console.log('Creating tools directory...');
        tl.mkdirP($toolPath);
        if (!tl.exist($toolPath)) {
            throw new Error('Could not create tools directory.');
        }
    }

    // Install Cake Tool
    if (!tl.exist(cakeToolPath)) {
        if ($version !== null && $version !== undefined && $version !== '') {
            console.log(`Installing Cake (v${$version})...`);
            await tl.exec('dotnet', `tool install --tool-path "${$toolPath}/" --version "${$version}" Cake.Tool`)
        }
        else {
            console.log('Installing Cake Tool (Latest)...');
            await tl.exec('dotnet', `tool install --tool-path "${$toolPath}/" Cake.Tool`)
        }

        // Make sure it was properly downloaded.
        if (!tl.exist(cakeToolPath)) {
            throw new Error(`Could not find dotnet-cake at ${cakeToolPath}`);
        }
    }

    // Bootstrap the script
    if ($bootstrap === true) {
        console.log('Bootstrapping build script...');
        const bootstrapExitCode = await tl.exec(cakeToolPath, `"${$script}" --bootstrap`);
        if (bootstrapExitCode !== 0) {
            throw new Error(`Failed to bootstrap the build script. Exit code: ${bootstrapExitCode}`);
        }
    }

    // Start Cake
    console.log('Executing build script...');
    const exitCode = await tl.exec(cakeToolPath, `"${$script}" --target="${$target}" --verbosity="${$verbosity}" --paths_tools="${$toolPath}" ${$arguments}`);
    if (exitCode !== 0) {
        throw new Error(`Failed to execute the build script. Exit code: ${exitCode}`);
    }
}

run()
    .then(() => tl.setResult(tl.TaskResult.Succeeded, ''))
    .catch((error) => tl.setResult(tl.TaskResult.Failed, !!error.message ? error.message : error));
