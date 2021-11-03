const path = require('path');

const core = require('@actions/core');
const github = require('@actions/github');
const tc = require('@actions/tool-cache');
const exec = require('@actions/exec');
const glob = require('@actions/glob');

const INPUT_PATTERN = core.getInput('pattern');
const INPUT_FOLLOW_SYMBOLIC_LINKS = core.getInput('follow-symbolic-links').toLowerCase() === 'true';
const INPUT_EXTRA_ARGS = core.getInput('extra-args') || '';

const pgFormatterVersion = '5.1'
const pgFormatterUrl = `https://github.com/darold/pgFormatter/archive/refs/tags/v${pgFormatterVersion}.zip`

async function ensurePerlInstalled() {
    await exec.exec('perl', ['-v']);
}

async function downloadPgFormat() {
    // Download archive
    const formatterArchive = await tc.downloadTool(pgFormatterUrl);

    // Unpack the archive
    const extractedDir = process.env['RUNNER_TEMP'];
    await tc.extractZip(formatterArchive, extractedDir);

    const toolRootDir = `pgFormatter-${pgFormatterVersion}`;

    return path.join(extractedDir, toolRootDir);
}

async function createToolCache(sourceDir, tool = 'pg_format', cacheKey = pgFormatterVersion) {
    // Cache tool executable
    const pgFormatCachedDir = await tc.cacheDir(
        sourceDir,
        tool,
        cacheKey
    );

    return path.join(pgFormatCachedDir, tool);
}

async function getFiles(pattern, followSymlinks = true) {
    // Glob for the files to format
    const globber = await glob.create(
        pattern,
        {
            followSymbolicLinks: followSymlinks
        }
    );
    const files = await globber.glob();

    return files;
}

async function run() {
    try {
        await ensurePerlInstalled();

        const srcDir = await downloadPgFormat();
        const cachedToolPath = await createToolCache(srcDir);

        // Set execution permissions
        exec.exec('chmod', ['+x', cachedToolPath], { silent: true });

        const files = await getFiles(INPUT_PATTERN, INPUT_FOLLOW_SYMBOLIC_LINKS)

        // Extra args
        const extraArgs = INPUT_EXTRA_ARGS.split(' ');

        const formatterArgs = ['-i'];

        // Run pgFormatter
        await exec.exec(cachedToolPath, ['--version']);

        if (files.length > 0) {
            for (let filePath in files) {
                core.info(`Processing ${filePath}`);
                await exec.exec(
                    cachedToolPath,
                    formatterArgs
                        .concat(extraArgs)
                        .concat(filePath)
                );
            }
        } else {
            core.warning("The glob patterns did not match any source files");
        }
    } catch (error) {
        core.setFailed(`Something went wrong :( (${error})`);
    }
}

run();
