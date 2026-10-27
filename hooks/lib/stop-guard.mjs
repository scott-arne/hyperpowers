// The SDD stop guard: refuses a turn end it can prove premature (a plan ledger
// found for this session, nothing handed back, nothing tracked live), twice in
// a row per plan, logging every decision. Fails open on every doubt.
// Design: docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md (Design §1).
import { execFileSync } from 'node:child_process';
import { closeSync, constants, existsSync, fstatSync, mkdirSync, openSync, readFileSync, readSync, readdirSync, realpathSync, rmSync, statSync, writeSync } from 'node:fs';
import { dirname, join } from 'node:path';

export const CANDIDATE_CAP = 64;
export const REFUSAL_CAP = 2;
export const TAIL_CAP = 16 * 1024 * 1024;
export const TAIL_CHUNK = 512 * 1024;
export const LIVE_JOB_STATES = new Set(['running', 'lost-unswept']);
const COMPLETE = (n) => new RegExp(`(^|[^A-Za-z0-9])Task ${n}: complete`);
const TASK_HEADING = /^### Task (\d+):/gm;
const HANDBACK = /^handback (\S+) (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z): /;
const FRAGMENT = '\t#fragment';

function git(cwd, args, input) {
  try { return execFileSync('git', ['-C', cwd, ...args], { encoding: 'utf8', input, stdio: [input === undefined ? 'ignore' : 'pipe', 'pipe', 'ignore'] }).trim(); } catch { return null; }
}
// sdd-common.sh hp_common_dir and hp_key: the physical common git directory,
// hashed with the repository's own hash-object. Null outside a repository.
export function cloneKey(cwd) {
  if (!cwd || !existsSync(cwd)) return null;
  let d = git(cwd, ['rev-parse', '--path-format=absolute', '--git-common-dir']);
  if (!d || d.includes('\n') || !existsSync(d)) {
    d = git(cwd, ['rev-parse', '--git-common-dir']);
    if (!d) return null;
    if (!d.startsWith('/')) d = join(realpathSync(cwd), d);
  }
  if (!existsSync(d)) return null;
  return git(cwd, ['hash-object', '--stdin'], realpathSync(d)) || null;
}

// sdd-common.sh hp_ledger_records: the ledger's lines that are records. The
// shared writer never truncates, so a write that failed part-way leaves an
// unterminated last line and the next write ends it with a tab-"#fragment"
// marker. Neither is a record, even when its prefix reads like one, and every
// reader here — discovery, the completion count, the hand-back check — goes
// through this. The decision logs this module appends to keep the same
// convention, so a torn append there is dropped rather than parsed.
export function ledgerRecords(text) {
  const lines = String(text ?? '').split('\n');
  lines.pop(); // the empty tail of a terminated file, or an unterminated write
  return lines.filter((l) => !l.endsWith(FRAGMENT));
}

// sdd-state's lifecycle copies live beside the workspaces, each with a full
// ledger: finish's tomb `.removing-<ws>-<pid>` and import's `<ws>.import-<pid>`
// staging and `<ws>.importing-<pid>` backup. The spec's candidates are the
// `plans/*/progress.md` glob, which a dot cannot start; the two import names
// are excluded by name, because a copy of this session's ledger would read as
// a second plan and make every Stop ambiguous.
const LIFECYCLE_COPY = /\.import(ing)?-[0-9]+$/;
function ledgersUnder(plansDir) {
  const out = [];
  if (!existsSync(plansDir)) return out;
  for (const ws of readdirSync(plansDir)) {
    if (ws.startsWith('.') || LIFECYCLE_COPY.test(ws)) continue;
    const p = join(plansDir, ws, 'progress.md');
    if (existsSync(p)) out.push(p);
  }
  return out;
}
// Newest by modification time, ties in discovery order (state before plain).
// A candidate that vanished is gone; any other stat failure is uncertainty
// the caller reports.
function newestFirst(paths, unreadable) {
  return paths
    .map((p, i) => { try { return { p, i, m: statSync(p).mtimeMs }; } catch (err) { if (unreadable && err?.code !== 'ENOENT') unreadable.push(p); return null; } })
    .filter(Boolean).sort((a, b) => b.m - a.m || a.i - b.i).map((x) => x.p);
}
// A candidate that cannot be read is uncertainty, not absence: it is recorded
// so discovery can say so instead of answering "no ledger" for a plan this
// session may well own.
function carriesSession(path, sessionId, unreadable) {
  try { return ledgerRecords(readFileSync(path, 'utf8')).some((l) => l.startsWith(`session ${sessionId}:`)); } catch (err) { if (unreadable && err?.code !== 'ENOENT') unreadable.push(path); return false; }
}
// Step A. Candidates are the ledgers under this clone's key (every key when
// cwd is outside a repository), newest first; more than the cap is ambiguous
// before any is read. Receipts are the fallback for a session whose plan has
// finished: only the newest 64 are read, because a receipt this session wrote
// is by construction among them and reading every receipt on a long-lived
// host would turn every session's Stop into a logged ambiguity.
export function discover({ sessionId, cwd, cacheRoot }) {
  const hp = join(cacheRoot, 'hyperpowers');
  const key = cloneKey(cwd);
  let candidates = [];
  for (const backend of ['state', 'sdd']) {
    const root = join(hp, backend);
    if (key) candidates.push(...ledgersUnder(join(root, key, 'plans')));
    else if (existsSync(root)) for (const k of readdirSync(root)) candidates.push(...ledgersUnder(join(root, k, 'plans')));
  }
  if (candidates.length > CANDIDATE_CAP) return { kind: 'ambiguous', candidates: candidates.length, matches: [] };
  const unreadable = [];
  candidates = newestFirst(candidates, unreadable);
  // An imported workspace leaves the plain cache path a symlink to the state
  // path (sdd-state's import), so one ledger can answer twice; the same file
  // is one match, under the path discovery reached first.
  const matches = [];
  const seen = new Set();
  for (const p of candidates) {
    if (!carriesSession(p, sessionId, unreadable)) continue;
    let real; try { real = realpathSync(p); } catch { real = p; }
    if (seen.has(real)) continue;
    seen.add(real);
    matches.push(p);
  }
  // A candidate that could not be read may carry this session too, so one
  // readable match does not make the plan unique: say ambiguous and let main
  // allow. Uniqueness is a claim about every candidate, not about the ones
  // that answered.
  if (unreadable.length) return { kind: 'ambiguous', candidates: candidates.length, matches, unreadable };
  if (matches.length === 1) return { kind: 'ledger', workspace: dirname(matches[0]), ledger: matches[0] };
  if (matches.length > 1) return { kind: 'ambiguous', candidates: candidates.length, matches };
  const receipts = join(hp, 'receipts');
  if (existsSync(receipts)) {
    // A dot-prefixed staging is a receipt only once finish marked it FINISHED
    // (its final rename failed after the workspace was removed, Task 5).
    const all = readdirSync(receipts).filter((r) => !r.startsWith('.') || existsSync(join(receipts, r, 'FINISHED'))).map((r) => join(receipts, r, 'progress.md')).filter((p) => existsSync(p));
    const hit = newestFirst(all).slice(0, CANDIDATE_CAP).find((p) => carriesSession(p, sessionId));
    if (hit) return { kind: 'receipt', receipt: dirname(hit) };
  }
  return { kind: 'none' };
}

// Step B. The plan path from the ledger's first line, resolved against the
// toplevel this session's line records, then against cwd's toplevel.
export function planState({ workspace, cwd, sessionId }) {
  let records;
  try { records = ledgerRecords(readFileSync(join(workspace, 'progress.md'), 'utf8')); } catch { return { plan: null, unreadable: true }; }
  const m = (records[0] || '').match(/^# SDD ledger — plan: (.+)$/);
  if (!m) return { plan: null, unreadable: true };
  const rel = m[1].trim();
  const roots = [];
  for (const l of records) {
    // A session can also have a `session <sid>: tasks N,M` line, which names
    // no toplevel: the mode line is the one to read.
    if (!l.startsWith(`session ${sessionId}:`)) continue;
    const at = l.match(/ at (\S+) started /);
    if (at) { roots.push(at[1]); break; }
  }
  const top = git(cwd, ['rev-parse', '--show-toplevel']);
  if (top) roots.push(top);
  let planText = null;
  for (const r of roots) {
    const p = rel.startsWith('/') ? rel : join(r, rel);
    try { planText = readFileSync(p, 'utf8'); break; } catch { /* the next root */ }
  }
  if (planText === null) return { plan: rel, unreadable: true };
  const tasks = [...new Set([...planText.matchAll(TASK_HEADING)].map((x) => Number(x[1])))];
  const done = tasks.filter((n) => { const re = COMPLETE(n); return records.some((l) => re.test(l)); }).length;
  return { plan: rel, total: tasks.length, open: tasks.length - done };
}

// A job is live while its supervisor runs or while a lost job awaits its
// sweep (lost-unswept, plan deviation 2); an exit file ends it whatever the
// state says, so a supervisor that died between writing exit and meta.json
// does not pin the session.
// A record that exists but cannot be read is uncertainty, not absence: it is
// returned as unreadable and main allows on it (hook-error with the detail).
export function liveJobs(workspace) {
  const jobs = join(workspace, 'jobs');
  const out = { live: [], unreadable: [] };
  if (!existsSync(jobs)) return out;
  for (const d of readdirSync(jobs)) {
    const metaPath = join(jobs, d, 'meta.json');
    if (d.startsWith('.') || !existsSync(metaPath)) continue; // an allocation still in progress is not a job yet
    try {
      const m = JSON.parse(readFileSync(metaPath, 'utf8'));
      if (LIVE_JOB_STATES.has(m.state) && !existsSync(join(jobs, d, 'exit'))) out.live.push(String(m.name || d));
    } catch { out.unreadable.push(d); }
  }
  out.live.sort(); out.unreadable.sort();
  return out;
}

export function handbackThisTurn(ledgerText, sessionId, promptTs) {
  const prompt = Date.parse(promptTs);
  if (Number.isNaN(prompt)) return false;
  for (const l of ledgerRecords(ledgerText)) {
    const m = l.match(HANDBACK);
    if (m && m[1] === sessionId && Date.parse(m[2]) > prompt) return true;
  }
  return false;
}

// The last `max` lines of a log that belong to this session, in file order,
// and what the read could not account for. The window is applied after the
// session filter: another session's decisions on a shared plan log must not
// push this session's refusals out of view. A log that is not there yet is
// the first Stop of a plan and reads as empty; a log that cannot be read, or
// that holds a whole line which is not JSON, is damage the caller reports
// (the cap cannot be enforced from a record it cannot see). A torn last line
// is dropped as the ledger drops its fragments, not counted as damage.
export function tailLines(path, sessionId, max = 200) {
  if (!path) return { lines: [], unreadable: null };
  let text;
  try { text = readFileSync(path, 'utf8'); } catch (err) { return { lines: [], unreadable: err?.code === 'ENOENT' ? null : `${err?.code || err}` }; }
  const lines = [];
  let malformed = 0;
  for (const l of ledgerRecords(text)) {
    if (!l) continue;
    let record;
    try { record = JSON.parse(l); } catch { malformed++; continue; }
    if (record && record.session === sessionId) lines.push(record);
  }
  return { lines: lines.slice(-max), unreadable: malformed ? `${malformed} malformed line(s)` : null };
}
const keyOf = (l) => `${l.ts}|${l.session}`;
// The cap's view of the record: the mirror in file order (the order decisions
// were made, which a wrapper line's second-resolution timestamp would
// misplace), with lines found only in the plan log inserted by timestamp.
// Each entry says whether the plan log holds it.
export function mergedDecisions(planLines, mirrorLines) {
  const inPlan = new Set(planLines.map(keyOf));
  const inMirror = new Set(mirrorLines.map(keyOf));
  const merged = mirrorLines.map((l) => ({ ...l, inPlanLog: inPlan.has(keyOf(l)) }));
  for (const a of planLines) {
    if (inMirror.has(keyOf(a))) continue;
    let i = merged.length;
    while (i > 0 && String(merged[i - 1].ts) > String(a.ts)) i--;
    merged.splice(i, 0, { ...a, inPlanLog: true });
  }
  return merged;
}
// Consecutive refusals of this plan since the last allow in either log. A
// block the mirror alone holds belongs to another plan of the session and
// neither counts nor resets. `unreadable` is set when the authoritative log
// itself could not be accounted for, so main allows (hook-error) instead of
// refusing against a count it cannot trust; an unreadable mirror leaves the
// authoritative log to answer, as the design says.
export function refusalsBefore({ workspaceLog, mirrorLog, sessionId }) {
  const plan = tailLines(workspaceLog, sessionId);
  const mirror = tailLines(mirrorLog, sessionId);
  const merged = mergedDecisions(plan.lines, mirror.lines);
  let n = 0;
  for (let i = merged.length - 1; i >= 0; i--) {
    if (merged[i].decision === 'allow') break;
    if (merged[i].decision === 'block' && merged[i].inPlanLog) n++;
  }
  return { refusals: n, unreadable: plan.unreadable };
}

// Test seams, inert unless a test installs one: `beforeWrite(path)` runs
// between the open and the write (the suite moves the workspace there, the
// race against finish this module must survive) and `write(fd, buffer)`
// replaces the write call (the suite makes it land short). Nothing in the
// hook's own paths reads them.
export const testHooks = {};

// One JSON line, built whole, appended with one write to a file opened
// without following a symlink: a link planted at a log must not send
// decisions somewhere else, the reason hp_ledger_append opens O_NOFOLLOW too.
// `mkdirs` is for the mirror alone and `confirmPath` for the authoritative
// log — see recordDecision.
// A write that failed part-way leaves an unterminated line; this ends it with
// the ledger's own fragment marker rather than gluing the next record to it,
// and a write that lands short is a failure, not a record: the bytes that did
// land are a fragment the next append fences off.
export function appendLine(path, line, { mkdirs = false, confirmPath = false } = {}) {
  let fd = -1;
  try {
    if (mkdirs) mkdirSync(dirname(path), { recursive: true });
    fd = openSync(path, constants.O_RDWR | constants.O_APPEND | constants.O_CREAT | constants.O_NOFOLLOW, 0o644);
    let repair = '';
    const before = fstatSync(fd);
    if (before.size > 0) {
      const last = Buffer.alloc(1);
      if (readSync(fd, last, 0, 1, before.size - 1) === 1 && last[0] !== 0x0a) repair = FRAGMENT + '\n';
    }
    if (testHooks.beforeWrite) testHooks.beforeWrite(path);
    const buf = Buffer.from(repair + JSON.stringify(line) + '\n');
    if ((testHooks.write || writeSync)(fd, buf) !== buf.length) return false;
    // The open and the write are a window: another session's finish can
    // rename the workspace aside in it, and the line then lands in the tomb.
    // The path must still be the file just written for the record to count.
    if (confirmPath) {
      const now = statSync(path);
      const written = fstatSync(fd);
      if (now.ino !== written.ino || now.dev !== written.dev) return false;
    }
    return true;
  } catch { return false; } finally {
    if (fd >= 0) { try { closeSync(fd); } catch { /* the write is what mattered */ } }
  }
}
// The marker, created without following a symlink either. Its existence is
// the whole message, so it carries nothing.
function markerSet(path) {
  let fd = -1;
  try { fd = openSync(path, constants.O_WRONLY | constants.O_CREAT | constants.O_NOFOLLOW, 0o644); return true; } catch { return false; } finally {
    if (fd >= 0) { try { closeSync(fd); } catch { /* created is created */ } }
  }
}
// The plan log first, then its copy in the mirror. A failed plan-log write
// turns the decision into a log-failed allow that goes to the mirror alone;
// a failed mirror write leaves a marker so the next line carries
// mirror_failed. Returns the line as recorded and where it went.
// The mirror's directory is created on demand; the workspace's never is, and
// the workspace must still hold its ledger before and after the line is
// written. A Stop racing another session's finish would otherwise recreate
// the workspace it just removed, and finish reports that as an error a human
// has to resolve. When the line landed but the workspace went away under it,
// the decision is log-failed: the stray line carries this line's `ts`, so the
// mirror's log-failed allow is the record the merge keeps.
export function recordDecision({ workspaceLog, mirrorLog, marker, line }) {
  const out = { ...line };
  const pending = Boolean(marker && existsSync(marker));
  if (pending) out.mirror_failed = true;
  // The marker is cleared only once a line carrying mirror_failed reached a
  // log; a decision that reaches neither leaves it for the next one.
  const clear = () => { if (pending) { try { rmSync(marker); } catch { /* the next line repeats it */ } } };
  const toMirror = (l) => appendLine(mirrorLog, l, { mkdirs: true });
  if (!workspaceLog) { const ok = toMirror(out); if (ok) clear(); return { line: out, loggedAs: ok ? 'mirror-only' : 'none' }; }
  const live = () => existsSync(join(dirname(workspaceLog), 'progress.md'));
  if (!live() || !appendLine(workspaceLog, out, { confirmPath: true }) || !live()) {
    const failed = { ...out, decision: 'allow', reason: 'log-failed', refusals: 0 };
    const ok = toMirror(failed); if (ok) clear();
    return { line: failed, loggedAs: ok ? 'log-failed' : 'none' };
  }
  clear();
  if (!toMirror(out) && marker) markerSet(marker);
  return { line: out, loggedAs: 'authoritative' };
}
