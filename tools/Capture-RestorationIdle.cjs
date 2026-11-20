// Capture the authored idle poses from the actual desktop compositor.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require(process.env.EPICAST_PLAYWRIGHT || 'playwright');

const root = path.resolve(__dirname, '..');
const preview = path.join(root, 'prototypes/feather-cels');
const output = path.resolve(process.argv[2] || path.join(root, 'artifacts/restoration-idle-build'));

async function capture() {
    const browser = await chromium.launch({
        headless: true,
        executablePath: process.env.EPICAST_CHROMIUM || undefined,
    });
    try {
        const page = await browser.newPage();
        const errors = [];
        page.on('pageerror', error => errors.push(String(error)));
        page.on('requestfailed', request => errors.push(request.url()));
        await page.route('http://epicast.test/**', async route => {
            const relative = decodeURIComponent(new URL(route.request().url()).pathname).slice(1);
            const file = path.resolve(preview, relative);
            if (!file.startsWith(preview + path.sep)) {
                await route.abort();
                return;
            }
            await route.fulfill({ path: file });
        });
        // This four-second atlas samples the approved base Idle cycle.
        await page.goto('http://epicast.test/index.html?motion=base');
        await page.waitForFunction(() => !document.querySelector('#channel').disabled);
        const capture = await page.evaluate(() => {
            playing = false;
            playback.reset();
            state = "Idle";
            refresh();
            const fps = 8;
            const step = 1000 / fps;
            const period = 4000;
            const frames = [];
            const sizes = [master.naturalWidth, master.naturalHeight];
            for (let time = 0; time <= period; time += step) {
                idleTime = time;
                ambientTime = time;
                treantTime = time;
                crownTime = time % crownIdle.period;
                drawScene(ctx, framePose("Idle", time, crown.frameAt(crownTime), 0));
                frames.push(crest.toDataURL('image/png').split(',')[1]);
            }
            return { fps, period, canvas: [crest.width, crest.height], master: sizes, margin: sideMargin, frames };
        });
        const { frames, ...info } = capture;
        assert.deepEqual(errors, []);
        assert.equal(frames.length, 33);
        assert.equal(frames[0], frames.at(-1), "The authored idle tracks must close their loop");
        assert.equal(new Set(frames.slice(0, -1)).size, 32, "Unexpected repeated idle poses");
        await fs.mkdir(output, {recursive: true});
        for (const [index, frame] of frames.slice(0, -1).entries()) {
            await fs.writeFile(path.join(output, `pose-${String(index).padStart(2, '0')}.png`), Buffer.from(frame, 'base64'));
        }
        await fs.writeFile(path.join(output, 'capture.json'), JSON.stringify(info, null, 2) + '\n');
        console.log(`Captured 32 registered idle poses at 8 FPS in ${output}`);
    } finally {
        await browser.close();
    }
}
capture().catch(error => { console.error(error); process.exitCode = 1; });
