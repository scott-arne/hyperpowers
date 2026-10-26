// The SDD stop guard: refuses a turn end it can prove premature (a plan ledger
// found for this session, nothing handed back, nothing tracked live), twice in
// a row per plan, logging every decision. Fails open on every doubt.
// Design: docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md (Design §1).
import { execFileSync } from 'node:child_process';
import { appendFileSync, closeSync, existsSync, fstatSync, mkdirSync, openSync, readFileSync, readSync, readdirSync, realpathSync, rmSync, statSync, writeFileSync } from 'node:fs';
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
// through this.
export function ledgerRecords(text) {
  const lines = String(text ?? '').split('\n');
  lines.pop(); // the empty tail of a terminated file, or an unterminated write
  return lines.filter((l) => !l.endsWith(FRAGMENT));
}

function ledgersUnder(plansDir) {
  const out = [];
  if (!existsSync(plansDir)) return out;
  for (const ws of readdirSync(plansDir)) { const p = join(plansDir, ws, 'progress.md'); if (existsSync(p)) out.push(p); }
  return out;
}
function newestFirst(paths) {
  return paths.map((p) => { try { return { p, m: statSync(p).mtimeMs }; } catch { return null; } }).filter(Boolean).sort((a, b) => b.m - a.m).map((x) => x.p);
}
function carriesSession(path, sessionId) {
  try { return ledgerRecords(readFileSync(path, 'utf8')).some((l) => l.startsWith(`session ${sessionId}:`)); } catch { return false; }
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
  candidates = newestFirst(candidates);
  const matches = candidates.filter((p) => carriesSession(p, sessionId));
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

// The last `max` lines of a log that belong to this session, in file order.
export function tailLines(path, sessionId, max = 200) {
  try {
    return readFileSync(path, 'utf8').split('\n').filter(Boolean).slice(-max)
      .map((l) => { try { return JSON.parse(l); } catch { return null; } })
      .filter((l) => l && l.session === sessionId);
  } catch { return []; }
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
// neither counts nor resets.
export function refusalsBefore({ workspaceLog, mirrorLog, sessionId }) {
  const merged = mergedDecisions(tailLines(workspaceLog, sessionId), tailLines(mirrorLog, sessionId));
  let n = 0;
  for (let i = merged.length - 1; i >= 0; i--) {
    if (merged[i].decision === 'allow') break;
    if (merged[i].decision === 'block' && merged[i].inPlanLog) n++;
  }
  return n;
}

// One JSON line, built whole, appended with one write.
export function appendLine(path, line) {
  try { mkdirSync(dirname(path), { recursive: true }); appendFileSync(path, JSON.stringify(line) + '\n'); return true; } catch { return false; }
}
// The plan log first, then its copy in the mirror. A failed plan-log write
// turns the decision into a log-failed allow that goes to the mirror alone;
// a failed mirror write leaves a marker so the next line carries
// mirror_failed. Returns the line as recorded and where it went.
export function recordDecision({ workspaceLog, mirrorLog, marker, line }) {
  const out = { ...line };
  const pending = Boolean(marker && existsSync(marker));
  if (pending) out.mirror_failed = true;
  // The marker is cleared only once a line carrying mirror_failed reached a
  // log; a decision that reaches neither leaves it for the next one.
  const clear = () => { if (pending) { try { rmSync(marker); } catch { /* the next line repeats it */ } } };
  if (!workspaceLog) { const ok = appendLine(mirrorLog, out); if (ok) clear(); return { line: out, loggedAs: ok ? 'mirror-only' : 'none' }; }
  if (!appendLine(workspaceLog, out)) {
    const failed = { ...out, decision: 'allow', reason: 'log-failed', refusals: 0 };
    const ok = appendLine(mirrorLog, failed); if (ok) clear();
    return { line: failed, loggedAs: ok ? 'log-failed' : 'none' };
  }
  clear();
  if (!appendLine(mirrorLog, out) && marker) { try { writeFileSync(marker, ''); } catch { /* best effort */ } }
  return { line: out, loggedAs: 'authoritative' };
}
// Task 7 appends asksOrBlocks, the messages, decideStop and main; Task 8 the
// transcript reader. closeSync, fstatSync, openSync and readSync are theirs.
void closeSync; void fstatSync; void openSync; void readSync;
