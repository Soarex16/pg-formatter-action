const path = require('path');

const core = require('@actions/core');
const github = require('@actions/github');
const tc = require('@actions/tool-cache');
const exec = require('@actions/exec');
const glob = require('@actions/glob');

const INPUT_PATTERN = core.getInput('pattern');
const INPUT_FOLLOW_SYMBOLIC_LINKS = core.getInput('follow-symbolic-links').toLowerCase() === 'true';
const INPUT_EXTRA_ARGS = core.getInput('extra-args') || '';

const pgFormatterVersion = 'https://github.com/darold/pgFormatter/archive/refs/tags/v5.1.zip'
const pgFormatterUrl = 'https://github.com/darold/pgFormatter/archive/refs/tags/v5.1.zip'

async function ensurePerlInstalled() {
    await exec.exec('perl', ['-v']);
}

async function downloadPgFormatter() {
    // Download archive
    const formatterArchive = await tc.downloadTool(pgFormatterUrl);

    // Unpack the archive
    const extractedDir = process.env['RUNNER_TEMP'];
    await tc.extractZip(formatterArchive, extractedDir);

    return extractedDir;
}

async function createToolCache(sourceDir, tool = 'pg_format', cacheKey = pgFormatterVersion) {
    // Cache tool executable
    const pgFormatCachedDir = await tc.cacheDir(
        sourceDir,
        tool,
        cacheKey
    );
    const pgFormatterCachedPath = path.join(pgFormatCachedDir, tool)

    return path.join(pgFormatterCachedPath, tool);
}

async function getFiles(patterns = [], followSymlinks = true) {
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

        const srcDir = await downloadPgFormatter();
        const cachedToolPath = await createToolCache(srcDir);

        // Set execution permissions
        exec.exec('ls', [cachedToolPath]);
        exec.exec('chmod', ['+x', cachedToolPath], { silent: true });

        const files = await getFiles(INPUT_PATTERN, INPUT_FOLLOW_SYMBOLIC_LINKS)

        // Extra args
        const extraArgs = INPUT_EXTRA_ARGS.split(' ');

        let formatterArgs = ['-i'];

        // Run pgFormatter
        await exec.exec(cachedToolPath, ['--version']);

        if (files.length > 0) {
            for (let filePath in files) {
                core.info(`Processing ${filePath}`);
                await exec.exec(
                    cachedToolPath,
                    formatterArgs['-i']
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
