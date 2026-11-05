// The SDD stop guard: refuses a turn end it can prove premature (a plan ledger
// found for this session, nothing handed back, nothing tracked live), twice in
// a row per plan, logging every decision. Fails open on every doubt.
// Design: docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md (Design §1).
import { execFileSync } from 'node:child_process';
import { closeSync, constants, existsSync, fstatSync, lstatSync, mkdirSync, openSync, readFileSync, readSync, readdirSync, realpathSync, rmSync, statSync, writeSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';
import { pathToFileURL } from 'node:url';

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
// Absent or uncertain, never "no": a path the hook is not allowed to look at
// is recorded rather than dropped, because the plan it hides may be this
// session's. Only ENOENT and ENOTDIR are absence: ENOTDIR means a component of
// the path is a plain file (sdd-state's `<key>.backend`, a stray file in the
// cache), so no ledger can live beneath it.
const absent = (err) => err?.code === 'ENOENT' || err?.code === 'ENOTDIR';
function ledgersUnder(plansDir, unreadable) {
  const out = [];
  let names;
  try { names = readdirSync(plansDir); } catch (err) { if (!absent(err)) unreadable.push(plansDir); return out; }
  for (const ws of names) {
    if (ws.startsWith('.') || LIFECYCLE_COPY.test(ws)) continue;
    const p = join(plansDir, ws, 'progress.md');
    try { if (statSync(p).isFile()) out.push(p); } catch (err) { if (!absent(err)) unreadable.push(p); }
  }
  return out;
}
// Newest by modification time, ties in discovery order (state before plain).
// A candidate that vanished is gone; any other stat failure is uncertainty
// the caller reports.
function newestFirst(paths, unreadable) {
  return paths
    .map((p, i) => { try { return { p, i, m: statSync(p).mtimeMs }; } catch (err) { if (unreadable && !absent(err)) unreadable.push(p); return null; } })
    .filter(Boolean).sort((a, b) => b.m - a.m || a.i - b.i).map((x) => x.p);
}
// A candidate that cannot be read is uncertainty, not absence: it is recorded
// so discovery can say so instead of answering "no ledger" for a plan this
// session may well own.
function carriesSession(path, sessionId, unreadable) {
  try { return ledgerRecords(readFileSync(path, 'utf8')).some((l) => l.startsWith(`session ${sessionId}:`)); } catch (err) { if (unreadable && !absent(err)) unreadable.push(path); return false; }
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
  const unreadable = [];
  let candidates = [];
  for (const backend of ['state', 'sdd']) {
    const root = join(hp, backend);
    if (key) { candidates.push(...ledgersUnder(join(root, key, 'plans'), unreadable)); continue; }
    let keys = [];
    try { keys = readdirSync(root); } catch (err) { if (!absent(err)) unreadable.push(root); }
    for (const k of keys) candidates.push(...ledgersUnder(join(root, k, 'plans'), unreadable));
  }
  if (candidates.length > CANDIDATE_CAP) return { kind: 'ambiguous', candidates: candidates.length, matches: [] };
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
  // The fallback answers under the same rule: a receipt the hook is not
  // allowed to look at may be the one this session wrote, so it is recorded
  // and the answer is ambiguous rather than "no record".
  const receipts = join(hp, 'receipts');
  const all = [];
  let entries = [];
  try { entries = readdirSync(receipts); } catch (err) { if (!absent(err)) unreadable.push(receipts); }
  for (const r of entries) {
    const dir = join(receipts, r);
    // A dot-prefixed staging is a receipt only once finish marked it FINISHED
    // (its final rename failed after the workspace was removed, Task 5). When
    // the marker cannot be statted, whether the directory is a receipt at all
    // is the unknown, so the directory itself is what gets recorded.
    if (r.startsWith('.')) {
      try { statSync(join(dir, 'FINISHED')); } catch (err) { if (!absent(err)) unreadable.push(dir); continue; }
    }
    const p = join(dir, 'progress.md');
    try { if (statSync(p).isFile()) all.push(p); } catch (err) { if (!absent(err)) unreadable.push(p); }
  }
  // Every capped candidate is read — filter, not find — because a match that
  // stopped the scan would leave a sibling unaccounted for, and a receipt
  // this session wrote may be the one that went unread.
  const hits = newestFirst(all, unreadable).slice(0, CANDIDATE_CAP).filter((p) => carriesSession(p, sessionId, unreadable));
  if (unreadable.length) return { kind: 'ambiguous', candidates: candidates.length, matches, unreadable };
  if (hits.length) return { kind: 'receipt', receipt: dirname(hits[0]) };
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
  let names;
  try { names = readdirSync(jobs); } catch (err) { if (!absent(err)) out.unreadable.push('jobs'); return out; }
  for (const d of names) {
    if (d.startsWith('.')) continue;
    let text;
    // No meta.json is an allocation still in progress, not a job. A
    // meta.json that cannot be read is a job whose state may well be
    // running, so it is uncertainty, not absence.
    try { text = readFileSync(join(jobs, d, 'meta.json'), 'utf8'); } catch (err) { if (!absent(err)) out.unreadable.push(d); continue; }
    try {
      const m = JSON.parse(text);
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

// <dir> and <levels> directories up, stopping at the filesystem root.
function ancestorOf(dir, levels) {
  let at = dir;
  for (let i = 0; i < levels; i++) { const up = dirname(at); if (up === at) break; at = up; }
  return at;
}
// <dir>'s components below <root>, created one at a time: an existing one
// must be a real directory and never a symlink, because O_NOFOLLOW guards
// only the file's own name and a link planted on the way to it would send
// decisions outside the cache. <root> itself is the caller's configured
// cache, reached through whatever the host's own layout uses (/tmp and a
// home directory are symlinks on macOS), so it is created whole and not
// inspected. False when a component is not a real directory this hook can
// make or keep.
function makeParents(root, dir) {
  const parts = [];
  let at = dir;
  while (at !== root) {
    const up = dirname(at);
    if (up === at) return false; // dir is not under root
    parts.unshift(basename(at));
    at = up;
  }
  try { mkdirSync(root, { recursive: true }); } catch { return false; }
  let cur = root;
  for (const part of parts) {
    cur = join(cur, part);
    let st = null;
    try { st = lstatSync(cur); } catch (err) { if (!absent(err)) return false; }
    if (st) { if (!st.isDirectory()) return false; continue; } // a symlink is not a directory to lstat
    try { mkdirSync(cur); continue; } catch (err) { if (err?.code !== 'EEXIST') return false; }
    try { if (!lstatSync(cur).isDirectory()) return false; } catch { return false; }
  }
  return true;
}

// One JSON line, built whole, appended with one write to a file opened
// without following a symlink: a link planted at a log must not send
// decisions somewhere else, the reason hp_ledger_append opens O_NOFOLLOW too.
// `mkdirsUnder` is for the mirror alone and `confirmPath` for the
// authoritative log — see recordDecision.
// A write that failed part-way leaves an unterminated line; this ends it with
// the ledger's own fragment marker rather than gluing the next record to it,
// and a write that lands short is a failure, not a record: the bytes that did
// land are a fragment the next append fences off.
export function appendLine(path, line, { mkdirsUnder = null, confirmPath = false } = {}) {
  let fd = -1;
  try {
    if (mkdirsUnder && !makeParents(mkdirsUnder, dirname(path))) return false;
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
  // The mirror is <cache>/hyperpowers/stop-guard/<session>.jsonl: the two
  // components under the cache root are this hook's to create, and each must
  // be a real directory for the line to go there.
  const toMirror = (l) => appendLine(mirrorLog, l, { mkdirsUnder: ancestorOf(dirname(mirrorLog), 2) });
  if (!workspaceLog) { const ok = toMirror(out); if (ok) clear(); return { line: out, loggedAs: ok ? 'mirror-only' : 'none' }; }
  const live = () => existsSync(join(dirname(workspaceLog), 'progress.md'));
  if (!live() || !appendLine(workspaceLog, out, { confirmPath: true }) || !live()) {
    // log-failed is a statement about the record, not about the turn, so the
    // decision it displaced goes into `detail`: the plan log never received
    // that reason, and the mirror is the only place left to read it.
    const failed = { ...out, decision: 'allow', reason: 'log-failed', refusals: 0, detail: out.detail ? `${out.reason}: ${out.detail}` : out.reason };
    const ok = toMirror(failed); if (ok) clear();
    return { line: failed, loggedAs: ok ? 'log-failed' : 'none' };
  }
  clear();
  if (!toMirror(out) && marker) markerSet(marker);
  return { line: out, loggedAs: 'authoritative' };
}

// liveness.asks_or_blocks, ported from liveness.py:376-391, with APPROVAL and
// SENTENCE_END from liveness.py:50-58. The hand-labelled sample it was tuned
// against is the node test's table.
// The one deliberate departure from the source's characters: Python's `\b` is
// Unicode-aware (its `\w` is Unicode letters, numbers and underscore) while
// JavaScript's is ASCII-only, so the two boundaries are spelled out. Left as
// `\b`, "éapprove" would read as an approval here and not in the field
// heuristic this hook's decisions are adjudicated against.
const APPROVAL = /(?<![\p{L}\p{N}_])(?:say (?:the word|["']?(?:continue|proceed|go|resume)["']?)|let me know|your call|which (?:option|one|do you)|do you want|would you like|shall i|should i|want me to|approve|for your review|for you to review|when(?:ever)? you(?:'re| are) ready|your go-ahead|decision is yours|is yours to make)(?![\p{L}\p{N}_])/iu;
const SENTENCE_END = /(?<=[.!?])\s+/;
// The second departure, for the same reason as the first. Python's
// re.IGNORECASE folds İ (U+0130) and ı (U+0131) onto ASCII i; JavaScript's
// /iu simple folding does not. Over U+0080 to U+2FFFF these are the only two
// characters the two engines disagree about for the letters these
// alternatives contain — U+017F and U+212A already fold alike — so the copy
// handed to the pattern maps just them. Not toLowerCase, which turns İ into
// i followed by a combining dot and would break the following letter.
const DOTTED_I = /[İı]/g;
export function asksOrBlocks(text) {
  if (text.includes('BLOCKED')) return true;
  const stripped = text.trim();
  if (!stripped) return false;
  const sentences = stripped.split(SENTENCE_END);
  if (sentences[sentences.length - 1].replace(/[ *_`)"']+$/, '').endsWith('?')) return true;
  return APPROVAL.test(sentences.slice(-3).join(' ').replace(DOTTED_I, 'i'));
}

const handbackHint = (sid) => `If you are handing back to your human partner (a question only they can answer, a BLOCKED report, or they asked you to stop), run scripts/sdd-state handback PLAN_FILE --session ${sid} --reason "<why>" and end the turn with that message.`;
export function openTasksMessage(plan, state, sid) {
  return `SDD stop guard: plan ${plan} is not finished (${state}; nothing tracked is live). Take the next step now, in this turn. ${handbackHint(sid)}`;
}
export function liveShellMessage(plan, state, names, sid) {
  const list = names.join(', ');
  return `SDD stop guard: plan ${plan} is not finished (${state}; job(s) ${list} are live). Job(s) ${list} are still running: watch them in the foreground with tracked-job wait, and report a lost-unswept job to your human partner with its pgid. ${handbackHint(sid)}`;
}

// Step D, in the spec's order. log-failed is decided at write time by
// recordDecision, which is why it is absent here.
export function decideStop({ discovery, plan, turn, jobs, jobsUnreadable = [], refusals, refusalsUnreadable = null, sessionId, ledgerText = null }) {
  if (discovery.kind !== 'ledger') {
    if (discovery.kind !== 'ambiguous') return { decision: 'allow', reason: 'no-ledger' };
    // What discovery could not read, by path and nothing more: the entries
    // are of mixed kinds (a candidate's progress.md, a staging directory, a
    // directory it could not list), so the line names them and does not say
    // what they are.
    const paths = discovery.unreadable || [];
    return { decision: 'allow', reason: 'ambiguous', ...(paths.length ? { detail: `unreadable: ${paths.join(', ')}` } : {}) };
  }
  if (!plan || plan.unreadable) return { decision: 'allow', reason: 'no-plan' };
  const state = plan.open > 0 ? `${plan.open} of ${plan.total} tasks open` : `all ${plan.total} tasks complete; the final review and Finish remain`;
  // A job record that cannot be read is not evidence that nothing is live: allow, and say which.
  if (jobsUnreadable.length) return { decision: 'allow', reason: 'hook-error', state, detail: `job meta unreadable: ${jobsUnreadable.join(', ')}` };
  // Nor is a decision log that cannot be read evidence of no refusal: the cap
  // is the only thing standing between a wrong block and a session that can
  // never end, so a count that could not be taken refuses nothing.
  if (refusalsUnreadable) return { decision: 'allow', reason: 'hook-error', state, detail: `decision log unreadable: ${refusalsUnreadable}` };
  if (!turn.ok || turn.tooLong) return { decision: 'allow', reason: 'turn-too-long', state, ...(turn.detail ? { detail: turn.detail } : {}) };
  if ((turn.liveAgents || []).length) return { decision: 'allow', reason: 'live-agent', state };
  // The ledger is reread here for the hand-back line. A read that fails after
  // discovery found the file — a permission change, a transient error, a
  // finish racing this turn — says nothing about whether this turn handed
  // back, and an empty string would say it did not: allow, and name the file.
  let text = ledgerText;
  if (text === null || text === undefined) {
    try { text = readFileSync(discovery.ledger, 'utf8'); } catch { return { decision: 'allow', reason: 'hook-error', state, detail: `ledger unreadable: ${discovery.ledger}` }; }
  }
  if (handbackThisTurn(text, sessionId, turn.promptTs)) return { decision: 'allow', reason: 'handback-line', state };
  if (asksOrBlocks(turn.lastAssistantText || '')) return { decision: 'allow', reason: 'handback-text', state };
  if (refusals >= REFUSAL_CAP) return { decision: 'allow', reason: 'cap', state };
  const live = [...(turn.liveShells || []), ...jobs];
  if (live.length) return { decision: 'block', reason: 'live-shell', state, message: liveShellMessage(plan.plan, state, live, sessionId) };
  return { decision: 'block', reason: 'open-tasks', state, message: openTasksMessage(plan.plan, state, sessionId) };
}

const TASK_NOTICE = '<task-notification>';
const INTERRUPTED = '[Request interrupted';
const NOTIF_ID = /<tool-use-id>([^<]+)<\/tool-use-id>/g;
const LAUNCH_AGENT = 'Async agent launched';
const LAUNCH_BASH = 'Command running in background with ID';
const LAUNCH_BASH_AUTO = 'Command did not complete within its';
const AUTO_MOVED = 'was moved to the background';
const SEND_OK = '{"success":true,"message":"';
const RESUMED = ['Resuming agent ', 'in the background with your message'];
const AGENT_TOOLS = new Set(['Agent', 'Task']);

function textOf(rec) {
  const c = rec?.message?.content;
  if (typeof c === 'string') return c;
  if (Array.isArray(c)) return c.filter((b) => b.type === 'text').map((b) => b.text || '').join('\n');
  return '';
}
function isToolResult(rec) { const c = rec?.message?.content; return Array.isArray(c) && c.some((b) => b.type === 'tool_result'); }
// liveness.idle_marker: 'human' | 'notification' | null
export function idleMarker(rec) {
  if (rec.type !== 'user' || rec.isMeta || isToolResult(rec)) return null;
  if (rec.isCompactSummary || rec.isVisibleInTranscriptOnly) return null;
  const text = textOf(rec).replace(/^\s+/, '');
  if (text.startsWith(TASK_NOTICE)) return 'notification';
  if (!text || text.startsWith(INTERRUPTED)) return null;
  if (rec.origin && rec.origin.kind === 'human') return 'human';
  if (text.startsWith('<')) return null;
  return 'human';
}
export function isHumanPrompt(rec) { return idleMarker(rec) === 'human'; }
function resultText(block) { const c = block.content; if (typeof c === 'string') return c; if (Array.isArray(c)) return c.filter((b) => b.type === 'text').map((b) => b.text || '').join('\n'); return ''; }
const idsIn = (text) => [...text.matchAll(NOTIF_ID)].map((m) => m[1]);
// liveness._completion_ids: every tool-use id a completion notice names. One
// notice can name several, and a notice that arrived while the turn was busy
// is written as a queue-operation record rather than a user message.
function completionIds(rec) {
  if (rec.type === 'queue-operation' && rec.operation === 'enqueue') return typeof rec.content === 'string' ? idsIn(rec.content) : [];
  if (rec.type !== 'user') return [];
  const text = textOf(rec);
  return text.replace(/^\s+/, '').startsWith(TASK_NOTICE) ? idsIn(text) : [];
}
// liveness._launch_kind. A marker counts only at the start of a result from
// its own tool, and a shell launch also needs run_in_background on the call:
// a foreground command that prints or greps the marker text launches nothing.
function launchKind(name, background, text) {
  const head = text.replace(/^\s+/, '');
  if (AGENT_TOOLS.has(name) && head.startsWith(LAUNCH_AGENT)) return 'agent';
  if (name === 'Bash' && background && head.startsWith(LAUNCH_BASH)) return 'shell';
  if (name === 'Bash' && head.startsWith(LAUNCH_BASH_AUTO) && head.includes(AUTO_MOVED)) return 'shell';
  if (name === 'SendMessage' && head.startsWith(SEND_OK) && RESUMED.some((m) => head.includes(m))) return 'agent';
  return null;
}

// Lines of the file from its end, newest first, decoded only once complete:
// bytes are split on 0x0a, which no multibyte UTF-8 sequence contains, so a
// character straddling two chunks is never cut. Yields null when the cap
// stops the read before the file's start.
export function* linesFromEnd(path, capBytes, chunkBytes) {
  const fd = openSync(path, 'r');
  try {
    const size = fstatSync(fd).size;
    let pos = size; let carry = Buffer.alloc(0); let read = 0;
    while (pos > 0 && read < capBytes) {
      // The cap bounds bytes, not chunks: the last chunk is shortened to fit
      // it, so a cap smaller than a chunk or not a multiple of one is exact.
      const len = Math.min(chunkBytes, pos, capBytes - read); pos -= len;
      // A short read would leave the rest of the chunk zero-filled, which
      // would silently lose records; the caller answers unreadable instead.
      const buf = Buffer.alloc(len); if (readSync(fd, buf, 0, len, pos) !== len) throw new Error(`short read at ${pos}`); read += len;
      const data = carry.length ? Buffer.concat([buf, carry]) : buf;
      let end = data.length;
      for (let i = data.length - 1; i >= 0; i--) {
        if (data[i] !== 0x0a) continue;
        if (i + 1 < end) yield data.subarray(i + 1, end).toString('utf8');
        end = i;
      }
      carry = Buffer.from(data.subarray(0, end));
    }
    if (pos === 0) { if (carry.length) yield carry.toString('utf8'); }
    else yield null;
  } finally { closeSync(fd); }
}

// The current turn, read backwards from the transcript's end to the human
// prompt that opened it: the prompt's own timestamp, the last assistant text,
// and the background work launched in the turn that no completion notice has
// cleared.
export function readTurn(transcriptPath, { capBytes = TAIL_CAP, chunkBytes = TAIL_CHUNK } = {}) {
  const none = { ok: false, tooLong: false, promptTs: null, lastAssistantText: '', liveAgents: [], liveShells: [], detail: 'unreadable' };
  if (!transcriptPath || !existsSync(transcriptPath)) return none;
  const turnRecs = []; let tooLong = false; let found = false;
  try {
    for (const l of linesFromEnd(transcriptPath, capBytes, chunkBytes)) {
      if (l === null) { tooLong = true; break; }
      if (!l.trim()) continue;
      // A line in the scanned region that is not a record leaves the turn's
      // own boundary in doubt: carrying on would read the previous turn's
      // prompt as this one's and attribute its hand-back line here. Skipping
      // it is a guess; saying the turn is unreadable is the fail-open answer.
      // A line that parses to a number, a string or a list is no more a
      // record than one that does not parse at all: liveness.load drops both
      // the same way.
      let rec; try { rec = JSON.parse(l); } catch { return { ...none, detail: 'malformed' }; }
      if (rec === null || typeof rec !== 'object' || Array.isArray(rec)) return { ...none, detail: 'malformed' };
      if (rec.isSidechain) continue;
      turnRecs.push(rec);
      if (isHumanPrompt(rec)) { found = true; break; }
    }
  } catch { return none; }
  if (!found) return { ...none, tooLong, detail: tooLong ? 'cap' : 'no-prompt' };
  turnRecs.reverse(); // chronological, starting at the prompt
  // A prompt whose timestamp cannot be parsed is a prompt the hand-back rule
  // cannot be applied to, and an unanswerable hand-back question must not
  // read as "no hand-back": say there was no prompt and let the guard allow.
  const promptTs = turnRecs[0].timestamp;
  if (typeof promptTs !== 'string' || Number.isNaN(Date.parse(promptTs))) return { ...none, detail: 'no-prompt' };
  let lastAssistantText = '';
  const uses = new Map(); const launched = new Map(); const completed = new Set();
  for (const rec of turnRecs) {
    if (rec.type === 'assistant') {
      const t = textOf(rec); if (t) lastAssistantText = t;
      for (const b of rec.message?.content || []) if (b.type === 'tool_use') uses.set(b.id, { name: b.name, input: b.input || {} });
      continue;
    }
    for (const id of completionIds(rec)) completed.add(id);
    if (rec.type !== 'user' || !isToolResult(rec)) continue;
    for (const b of rec.message.content) {
      if (b.type !== 'tool_result') continue;
      const use = uses.get(b.tool_use_id); if (!use) continue;
      const kind = launchKind(use.name, use.input.run_in_background === true, resultText(b));
      if (kind) launched.set(b.tool_use_id, kind);
    }
  }
  const liveAgents = []; const liveShells = [];
  for (const [id, kind] of launched) if (!completed.has(id)) (kind === 'agent' ? liveAgents : liveShells).push(id);
  return { ok: true, tooLong: false, promptTs, lastAssistantText, liveAgents, liveShells };
}

export function main(stdinText, env = process.env) {
  const started = Date.now();
  let input;
  try { input = JSON.parse(stdinText || '{}'); } catch { return { stdout: '', exitCode: 0 }; }
  if (!input || typeof input !== 'object') return { stdout: '', exitCode: 0 };
  // One token, checked before anything else and in particular before the
  // mirror path is composed from it: appendLine creates the directories it is
  // handed, so a session id carrying a slash or a `..` would put this
  // session's decisions outside the mirror. Anything else is not ours.
  const sessionId = String(input.session_id || '');
  if (!sessionId || /[^A-Za-z0-9._-]/.test(sessionId)) return { stdout: '', exitCode: 0 };
  const cwd = String(input.cwd || process.cwd());
  const cacheRoot = env.XDG_CACHE_HOME || join(env.HOME || '', '.cache');
  const mirrorLog = join(cacheRoot, 'hyperpowers', 'stop-guard', `${sessionId}.jsonl`);
  const discovery = discover({ sessionId, cwd, cacheRoot });
  if (discovery.kind === 'none') return { stdout: '', exitCode: 0 };
  const workspace = discovery.kind === 'ledger' ? discovery.workspace : null;
  const workspaceLog = workspace ? join(workspace, 'stop-guard.jsonl') : null;
  const marker = workspace ? join(workspace, '.mirror-failed') : null;
  const plan = workspace ? planState({ workspace, cwd, sessionId }) : null;
  const turn = env.STOP_GUARD_TURN ? JSON.parse(env.STOP_GUARD_TURN) : readTurn(String(input.transcript_path || ''));
  const jobsRead = workspace ? liveJobs(workspace) : { live: [], unreadable: [] };
  const jobs = jobsRead.live;
  const refusalsRead = workspace ? refusalsBefore({ workspaceLog, mirrorLog, sessionId }) : { refusals: 0, unreadable: null };
  const d = decideStop({ discovery, plan, turn, jobs, jobsUnreadable: jobsRead.unreadable, refusals: refusalsRead.refusals, refusalsUnreadable: refusalsRead.unreadable, sessionId });
  if (env.STOP_GUARD_FAULT === 'throw') throw new Error('injected fault');
  const line = {
    ts: new Date().toISOString(), session: sessionId, decision: d.decision, reason: d.reason,
    plan: plan?.plan ?? null, open: plan?.open ?? null, total: plan?.total ?? null,
    live: [...(turn.liveAgents || []), ...(turn.liveShells || []), ...jobs],
    refusals: d.decision === 'block' ? refusalsRead.refusals + 1 : 0,
    stop_hook_active: Boolean(input.stop_hook_active), elapsed_ms: Date.now() - started,
  };
  if (discovery.kind === 'ambiguous') { line.candidates = discovery.candidates; line.matches = discovery.matches; }
  if (discovery.kind === 'receipt') line.receipt = discovery.receipt;
  if (d.detail) line.detail = d.detail;
  const recorded = recordDecision({ workspaceLog, mirrorLog, marker, line });
  if (recorded.line.decision === 'block') return { stdout: JSON.stringify({ decision: 'block', reason: d.message }), exitCode: 0 };
  return { stdout: '', exitCode: 0 };
}

// CLI entry: the only place that reads stdin and writes stdout, so `main`
// stays a pure function of its arguments. An uncaught throw exits 1 with the
// stack on stderr, which the bash wrapper turns into the `hook-error` line.
// node resolves symlinks for the main module's URL but leaves argv alone, so
// the comparison is made on the resolved path, and through pathToFileURL
// rather than interpolation: a plugin root reached through a symlink, or one
// whose path carries a #, ? or %, would otherwise leave this entry dead and
// the guard would allow every stop in silence. An unresolvable path is
// compared as it came.
let mainPath = process.argv[1] || '';
try { if (mainPath) mainPath = realpathSync(mainPath); } catch { /* compare the raw path */ }
if (mainPath && import.meta.url === pathToFileURL(mainPath).href) {
  const text = readFileSync(0, 'utf8');
  const r = main(text, process.env);
  if (r.stdout) process.stdout.write(r.stdout + '\n');
  process.exit(r.exitCode);
}
