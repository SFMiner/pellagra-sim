// Browser check for the exported Pellagra Mystery. Adapted from SimKit's addons/simkit/deploy/web_smoke.js,
// which is written for SimKit's own demo menu and cannot be run on another game unchanged (the addon copy
// is left untouched). Uses the same harness.html from the addon as the same-origin iframe stand-in.
// Run it with tests/web/run_web_smoke.ps1, which serves the export and sets PORT and NODE_PATH.
//   node web_smoke.js <folder for screenshots>
// Checks: boot line, no console or page errors, no SCRIPT ERROR, not blank, nothing moves before input,
// keyboard reaches the controls, the language button works and sets the page language, announcements
// reach the live region in the chosen language, Escape and Tab-past-the-end each send one
// sims:leave-game, Start runs and Pause freezes, class settings, small frames, DPR 1.5, standalone tab.
const { chromium } = require('playwright');
const port = process.env.PORT || '8823';
const shots = process.argv[2] || '.';
const root = `http://127.0.0.1:${port}`;
const BOOT = 'pellagra-mystery: boot ok';
let failures = 0;
function check(ok, label) { console.log((ok ? 'PASS ' : 'FAIL ') + label); if (!ok) { failures++; } }
function watch(page) {
	const logs = [], errors = [];
	// The harness page has no favicon, so the browser's own request for one fails: that is not the game.
	page.on('console', m => { logs.push(m.text()); if (m.type() === 'error' && !(m.location().url || '').endsWith('/favicon.ico')) { errors.push(m.text() + ' [' + (m.location().url || '') + ']'); } });
	page.on('pageerror', e => errors.push(String(e)));
	page.on('response', r => { if (r.status() >= 400) { logs.push('HTTP ' + r.status() + ' ' + r.url()); } });
	return { logs, errors };
}
async function waitBoot(page, logs) {
	const t0 = Date.now();
	while (!logs.some(l => l.includes(BOOT)) && Date.now() - t0 < 90000) { await page.waitForTimeout(250); }
	await page.waitForTimeout(700);
}
async function boot(browser, query, w, h, dpr) {
	const ctx = await browser.newContext({ viewport: { width: w + 20, height: h + 60 }, deviceScaleFactor: dpr || 1 });
	const page = await ctx.newPage();
	// Headless Chrome would otherwise try to speak.
	await page.addInitScript(() => { if (window.speechSynthesis) { window.speechSynthesis.speak = function () {}; } });
	const w2 = watch(page);
	await page.goto(`${root}/harness.html?q=${encodeURIComponent(query)}&w=${w}&h=${h}`);
	await waitBoot(page, w2.logs);
	return { ctx, page, logs: w2.logs, errors: w2.errors };
}
function clean(s) { return s.errors.length === 0 && !s.logs.some(l => l.includes('SCRIPT ERROR')); }
function why(s) { return s.errors.length ? ': ' + s.errors.join(' | ') : (s.logs.filter(l => l.includes('SCRIPT ERROR')).join(' | ')); }
const gameFrame = page => page.frames().find(f => f !== page.mainFrame());
const live = page => gameFrame(page).evaluate(() => document.getElementById('sk-status').textContent);
(async () => {
	const browser = await chromium.launch({ channel: 'chrome', args: ['--no-sandbox', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
	console.log('browser: ' + browser.version());

	// 1. Boot inside the iframe at the site's frame size
	let s = await boot(browser, '', 1180, 500);
	check(s.logs.some(l => l.includes(BOOT)), `boots in the iframe (console shows "${BOOT}")`);
	check(clean(s), 'no console errors, page errors or SCRIPT ERROR while booting' + why(s));
	const iframeEl = await s.page.$('#game');
	const a = await iframeEl.screenshot();
	await s.page.waitForTimeout(3000);
	const b = await iframeEl.screenshot();
	check(Buffer.compare(a, b) === 0, 'nothing changes for 3 s without input (no auto-play)');
	check(a.length > 20000, 'the canvas is not blank (screenshot is ' + a.length + ' bytes)');
	await iframeEl.screenshot({ path: `${shots}/web-en-1180x500.png` });
	check(await gameFrame(s.page).evaluate(() => document.documentElement.lang) === 'en', 'the page language starts as English');

	// 2. Keyboard: Tab to the language button (6th control), switch to Spanish
	await s.page.click('#game', { position: { x: 500, y: 300 } });
	for (let i = 0; i < 6; i++) { await s.page.keyboard.press('Tab'); await s.page.waitForTimeout(120); }
	await s.page.keyboard.press('Enter');
	await s.page.waitForTimeout(900);
	check(await gameFrame(s.page).evaluate(() => document.documentElement.lang) === 'es', 'Tab x6 + Enter presses the language button: the page language is now Spanish');
	let said = await live(s.page);
	check(said === 'Idioma: español', 'the live region received "' + said + '"');
	check((await gameFrame(s.page).evaluate(() => document.getElementById('canvas').getAttribute('aria-label'))).includes('simulación'), 'the canvas label is Spanish');
	await iframeEl.screenshot({ path: `${shots}/web-es-1180x500.png` });
	const es1 = await iframeEl.screenshot();
	check(Buffer.compare(a, es1) !== 0, 'the picture changed to Spanish text');

	// 3. Space starts (hotkey, focus released first), Space again pauses and everything holds still
	await s.page.keyboard.press('Shift+Tab');            // Reiniciar
	await s.page.keyboard.press('Shift+Tab');            // Paso
	await s.page.keyboard.press('Shift+Tab');            // Iniciar
	await s.page.keyboard.press('Enter');
	await s.page.waitForTimeout(600);
	said = await live(s.page);
	check(said === 'En marcha', 'SimKit\'s own "Running" announcement arrived translated: "' + said + '"');
	await s.page.waitForTimeout(3500);
	const c = await iframeEl.screenshot();
	await s.page.waitForTimeout(1200);
	const d = await iframeEl.screenshot();
	check(Buffer.compare(c, d) !== 0, 'after Start the simulation visibly runs');
	await iframeEl.screenshot({ path: `${shots}/web-es-running.png` });
	await s.page.keyboard.press('Enter');                // Pausar
	await s.page.waitForTimeout(300);
	said = await live(s.page);
	check(said === 'En pausa', 'SimKit\'s own "Paused" announcement arrived translated: "' + said + '"');
	await s.page.waitForTimeout(900);
	said = await live(s.page);
	check(said.startsWith('Célula:'), 'pausing announces a Spanish summary of the cell: "' + said + '"');
	const e1 = await iframeEl.screenshot();
	await s.page.waitForTimeout(2500);
	const e2 = await iframeEl.screenshot();
	check(Buffer.compare(e1, e2) === 0, 'after Pause the frame is pixel-identical for 2.5 s');

	// 4. Leaving: Escape sends exactly one message and focus lands on the host page
	let leaves = await s.page.evaluate(() => window.leaveCount);
	await s.page.keyboard.press('Escape');
	await s.page.waitForTimeout(400);
	check((await s.page.evaluate(() => window.leaveCount)) === leaves + 1, 'Escape with no panel open sends exactly one sims:leave-game');
	check(await s.page.evaluate(() => document.activeElement && document.activeElement.id === 'fs'), 'focus lands on the host page (Full screen button)');
	await s.page.click('#game', { position: { x: 500, y: 300 } });
	await s.page.keyboard.press('Shift+Tab');            // last control
	await s.page.waitForTimeout(200);
	leaves = await s.page.evaluate(() => window.leaveCount);
	await s.page.keyboard.press('Tab');                  // past the end
	await s.page.waitForTimeout(400);
	check((await s.page.evaluate(() => window.leaveCount)) === leaves + 1, 'Tab past the last control sends exactly one sims:leave-game');
	check(clean(s), 'still no errors after running, pausing and leaving' + why(s));
	await s.ctx.close();

	// 5. A panel: Help opens with the keyboard, Escape closes it without leaving
	s = await boot(browser, '', 1180, 500);
	await s.page.click('#game', { position: { x: 500, y: 300 } });
	for (let i = 0; i < 9; i++) { await s.page.keyboard.press('Tab'); await s.page.waitForTimeout(100); }   // ... Food, Evidence, Help
	await s.page.keyboard.press('Enter');
	await s.page.waitForTimeout(700);
	said = await live(s.page);
	check(said === 'Help opened', 'Tab x9 + Enter opens Help: "' + said + '"');
	await (await s.page.$('#game')).screenshot({ path: `${shots}/web-help.png` });
	leaves = await s.page.evaluate(() => window.leaveCount);
	await s.page.keyboard.press('Escape');
	await s.page.waitForTimeout(400);
	said = await live(s.page);
	check(said === 'Panel closed' && (await s.page.evaluate(() => window.leaveCount)) === leaves, 'Escape closes the panel and does not leave: "' + said + '"');
	check(clean(s), 'no errors with panels' + why(s));
	await s.ctx.close();

	// 6. Class settings in the address
	s = await boot(browser, 'view=population&food=degermed&processing=fortified&detail=advanced&prompts=on', 1180, 500);
	check(s.logs.some(l => l.includes(BOOT)) && clean(s), 'boots with class settings' + why(s));
	await (await s.page.$('#game')).screenshot({ path: `${shots}/web-class-settings.png` });
	await s.ctx.close();
	s = await boot(browser, 'food=banana&view=&junk=%00%3Cscript%3E&particles=off&motion=reduced', 1180, 500);
	check(s.logs.some(l => l.includes(BOOT)) && clean(s), 'boots with bad class settings (they are ignored)' + why(s));
	await s.ctx.close();

	// 7. Other frame sizes, and 150% display scaling
	for (const [w, h, dpr] of [[1180, 360, 1], [1180, 500, 1.5], [590, 250, 1], [380, 640, 2]]) {
		s = await boot(browser, '', w, h, dpr);
		check(s.logs.some(l => l.includes(BOOT)) && clean(s), `boots at ${w}x${h} (DPR ${dpr}) without errors` + why(s));
		await (await s.page.$('#game')).screenshot({ path: `${shots}/web-${w}x${h}-dpr${dpr}.png` });
		await s.ctx.close();
	}

	// 8. Standalone tab (no iframe): boots, runs, and Escape does not break anything
	const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
	const page = await ctx.newPage();
	const w3 = watch(page);
	await page.goto(`${root}/game/index.html`);
	await waitBoot(page, w3.logs);
	check(w3.logs.some(l => l.includes(BOOT)), 'boots standalone in its own tab');
	await page.click('#canvas', { position: { x: 400, y: 400 } });
	await page.keyboard.press('Space');
	await page.waitForTimeout(2500);
	await page.keyboard.press('Escape');
	await page.waitForTimeout(300);
	await page.screenshot({ path: `${shots}/web-standalone.png` });
	check(w3.errors.length === 0 && !w3.logs.some(l => l.includes('SCRIPT ERROR')), 'standalone: no errors after Space and Escape' + (w3.errors.length ? ': ' + w3.errors.join(' | ') : ''));
	await ctx.close();

	await browser.close();
	console.log(failures === 0 ? 'ALL BROWSER CHECKS PASSED' : failures + ' BROWSER CHECK(S) FAILED');
	process.exit(failures === 0 ? 0 : 1);
})();
