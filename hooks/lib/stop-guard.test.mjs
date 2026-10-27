import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { appendFileSync, chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, renameSync, rmSync, symlinkSync, writeFileSync, writeSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import test from 'node:test';
import * as guard from './stop-guard.mjs';

const SID = 'sess-1234';
function makeRepo(root) {
  const repo = join(root, 'repo');
  mkdirSync(join(repo, 'docs'), { recursive: true });
  execFileSync('git', ['init', '-q', '-b', 'main', repo]);
  execFileSync('git', ['-C', repo, 'config', 'user.email', 't@example.com']);
  execFileSync('git', ['-C', repo, 'config', 'user.name', 't']);
  writeFileSync(join(repo, 'docs', 'plan.md'), '# Plan\n\n### Task 1: one\n\n### Task 2: two\n\n### Task 3: three\n');
  execFileSync('git', ['-C', repo, 'add', 'docs/plan.md']);
  execFileSync('git', ['-C', repo, 'commit', '-q', '-m', 'plan']);
  return repo;
}
function env() { const root = mkdtempSync(join(tmpdir(), 'sg-')); return { root, cache: join(root, 'cache'), repo: makeRepo(root) }; }
function workspaceFor(e, name = 'plan-abcdef12', backend = 'state', key = guard.cloneKey(e.repo)) {
  const ws = join(e.cache, 'hyperpowers', backend, key, 'plans', name);
  mkdirSync(ws, { recursive: true });
  return ws;
}
function ledger(ws, e, { sid = SID, tasksDone = [], extra = [], at = e.repo } = {}) {
  const lines = ['# SDD ledger — plan: docs/plan.md', `session ${sid}: mode worktree on main at ${at} started 2026-10-23T00:00:00Z`];
  for (const n of tasksDone) lines.push(`Task ${n}: complete (commits 1111111..2222222, review clean)`);
  lines.push(...extra);
  writeFileSync(join(ws, 'progress.md'), lines.join('\n') + '\n');
}
function receipt(e, name, sid = SID) {
  const r = join(e.cache, 'hyperpowers', 'receipts', name); mkdirSync(r, { recursive: true });
  writeFileSync(join(r, 'progress.md'), `# SDD ledger — plan: docs/plan.md\nsession ${sid}: mode worktree on main at ${e.repo} started x\n`);
  return r;
}
const mirrorOf = (e, sid = SID) => join(e.cache, 'hyperpowers', 'stop-guard', `${sid}.jsonl`);
const readLines = (p) => readFileSync(p, 'utf8').trim().split('\n').filter(Boolean).map((l) => JSON.parse(l));
const line = (ts, decision, reason, extra = {}) => ({ ts, session: SID, decision, reason, plan: 'docs/plan.md', open: 1, total: 3, live: [], refusals: 0, stop_hook_active: false, elapsed_ms: 1, ...extra });
const writeLog = (p, lines) => { mkdirSync(join(p, '..'), { recursive: true }); writeFileSync(p, lines.map((l) => JSON.stringify(l)).join('\n') + '\n'); };

test('discover: no ledger and no receipt is none', () => {
  const e = env();
  assert.deepEqual(guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }), { kind: 'none' });
});
test('discover: one ledger carrying the session selects its workspace', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e); ledger(workspaceFor(e, 'other-00000000'), e, { sid: 'someone-else' });
  const d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache });
  assert.equal(d.kind, 'ledger'); assert.equal(d.workspace, ws); assert.equal(d.ledger, join(ws, 'progress.md'));
});
test('discover: two ledgers carrying the session are ambiguous', () => {
  const e = env(); ledger(workspaceFor(e, 'a-11111111'), e); ledger(workspaceFor(e, 'b-22222222'), e);
  const d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache });
  assert.equal(d.kind, 'ambiguous'); assert.equal(d.matches.length, 2); assert.equal(d.candidates, 2);
});
test('discover: 65 candidate ledgers are ambiguous before any is read', () => {
  const e = env();
  for (let i = 0; i < 65; i++) ledger(workspaceFor(e, `p${i}-0000000${i}`), e, { sid: 'other' });
  const d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache });
  assert.equal(d.kind, 'ambiguous'); assert.equal(d.candidates, 65); assert.deepEqual(d.matches, []);
});
test('discover: a receipt carrying the session is found when no ledger does; a staging counts only with FINISHED', () => {
  const e = env();
  const staging = receipt(e, '.staging-plan-abcdef12-20261023T000001Z');
  assert.equal(guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }).kind, 'none');
  writeFileSync(join(staging, 'FINISHED'), '');
  assert.equal(guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }).receipt, staging);
  rmSync(staging, { recursive: true });
  const r = receipt(e, 'plan-abcdef12-20261023T000000Z');
  const d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache });
  assert.equal(d.kind, 'receipt'); assert.equal(d.receipt, r);
});
test('discover: with more than 64 receipts the newest 64 are read and an older match is invisible', () => {
  const e = env();
  const old = receipt(e, 'plan-aaaaaaaa-20200101T000000Z');
  execFileSync('touch', ['-t', '202001010000', join(old, 'progress.md')]);
  for (let i = 0; i < 64; i++) receipt(e, `p${i}-bbbbbbbb-20261023T0000${String(i).padStart(2, '0')}Z`, 'other');
  assert.equal(guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }).kind, 'none');
});
test('discover: the plain cache is searched too, and a cwd outside any repository searches every key', () => {
  const e = env(); const ws = workspaceFor(e, 'plan-abcdef12', 'sdd'); ledger(ws, e);
  assert.equal(guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }).workspace, ws);
  assert.equal(guard.discover({ sessionId: SID, cwd: tmpdir(), cacheRoot: e.cache }).workspace, ws);
});
test('planState: open and total from the plan and the ledger; the plan resolves through the session line', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e, { tasksDone: [1, 2] });
  assert.deepEqual(guard.planState({ workspace: ws, cwd: e.repo, sessionId: SID }), { plan: 'docs/plan.md', open: 1, total: 3 });
  assert.deepEqual(guard.planState({ workspace: ws, cwd: tmpdir(), sessionId: SID }), { plan: 'docs/plan.md', open: 1, total: 3 });
  writeFileSync(join(ws, 'progress.md'), readFileSync(join(ws, 'progress.md'), 'utf8') + 'note: xTask 3: complete is prose, not a completion\n');
  assert.equal(guard.planState({ workspace: ws, cwd: e.repo, sessionId: SID }).open, 1);
});
test('planState: a missing plan, or a ledger without the session line, is unreadable', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e, { sid: 'other' });
  assert.equal(guard.planState({ workspace: ws, cwd: tmpdir(), sessionId: SID }).unreadable, true);
  ledger(ws, e); rmSync(join(e.repo, 'docs', 'plan.md'));
  assert.equal(guard.planState({ workspace: ws, cwd: e.repo, sessionId: SID }).unreadable, true);
});
test('planState: a session tasks line does not hide the session line naming the toplevel', () => {
  const e = env(); const ws = workspaceFor(e);
  writeFileSync(join(ws, 'progress.md'), ['# SDD ledger — plan: docs/plan.md', `session ${SID}: tasks 1,2`,
    `session ${SID}: mode worktree on main at ${e.repo} started 2026-10-23T00:00:00Z`, ''].join('\n'));
  assert.deepEqual(guard.planState({ workspace: ws, cwd: tmpdir(), sessionId: SID }), { plan: 'docs/plan.md', open: 3, total: 3 });
});
test('ledgerRecords: an unterminated last line and a #fragment line are not records', () => {
  assert.deepEqual(guard.ledgerRecords(''), []);
  assert.deepEqual(guard.ledgerRecords('a\nb\n'), ['a', 'b']);
  assert.deepEqual(guard.ledgerRecords('a\nb'), ['a']);
  assert.deepEqual(guard.ledgerRecords('a\tb\t#fragment\nc\n'), ['c']);
});
test('planState: a fragment of a completion line does not count as a completion', () => {
  const e = env(); const ws = workspaceFor(e);
  writeFileSync(join(ws, 'progress.md'), ['# SDD ledger — plan: docs/plan.md',
    `session ${SID}: mode worktree on main at ${e.repo} started 2026-10-23T00:00:00Z`,
    'Task 1: complete (commits 1111111..2222222, review clean)',
    'Task 3: complete (commits 3333333..4444444, review clean)\t#fragment',
    'Task 2: complete (commits 1111111..'].join('\n'));
  assert.deepEqual(guard.planState({ workspace: ws, cwd: e.repo, sessionId: SID }), { plan: 'docs/plan.md', open: 2, total: 3 });
});
test('discovery and the hand-back check read records too, never write fragments', () => {
  const e = env(); const ws = workspaceFor(e);
  writeFileSync(join(ws, 'progress.md'), `# SDD ledger — plan: docs/plan.md\nsession ${SID}: mode worktree on main at ${e.repo} started`);
  assert.equal(guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }).kind, 'none');
  const text = `handback ${SID} 2026-10-23T10:00:05.000Z: fragmented\t#fragment\nhandback ${SID} 2026-10-23T10:00:06.000Z: unterminated`;
  assert.equal(guard.handbackThisTurn(text, SID, '2026-10-23T10:00:00.000Z'), false);
  assert.equal(guard.handbackThisTurn(text + '\n', SID, '2026-10-23T10:00:00.000Z'), true);
});
test('liveJobs: running and lost-unswept are live; allocated, exited, lost, stopped and a job with an exit file are not', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  for (const [name, state] of [['b', 'running'], ['a', 'lost-unswept'], ['c', 'allocated'], ['d', 'exited'], ['e', 'lost'], ['f', 'stopped'], ['g', 'running']]) {
    mkdirSync(join(ws, 'jobs', `${name}-x-0001`), { recursive: true });
    writeFileSync(join(ws, 'jobs', `${name}-x-0001`, 'meta.json'), JSON.stringify({ name, state }));
  }
  writeFileSync(join(ws, 'jobs', 'g-x-0001', 'exit'), '0\n');
  mkdirSync(join(ws, 'jobs', '.new-abc123')); // an allocation in progress: no meta.json yet, not a job
  assert.deepEqual(guard.liveJobs(ws), { live: ['a', 'b'], unreadable: [] });
  mkdirSync(join(ws, 'jobs', 'h-x-0001')); writeFileSync(join(ws, 'jobs', 'h-x-0001', 'meta.json'), '{not json');
  assert.deepEqual(guard.liveJobs(ws), { live: ['a', 'b'], unreadable: ['h-x-0001'] });
});
test('handbackThisTurn: later than the prompt counts; the same millisecond, earlier, or another session does not', () => {
  const text = `handback ${SID} 2026-10-23T10:00:05.000Z: a question only you can answer\nhandback other 2026-10-23T10:00:09.000Z: x\n`;
  assert.equal(guard.handbackThisTurn(text, SID, '2026-10-23T10:00:04.999Z'), true);
  assert.equal(guard.handbackThisTurn(text, SID, '2026-10-23T10:00:05.000Z'), false);
  assert.equal(guard.handbackThisTurn(text, SID, '2026-10-23T10:00:05.500Z'), false);
  assert.equal(guard.handbackThisTurn(text, 'other', '2026-10-23T10:00:08.000Z'), true);
  assert.equal(guard.handbackThisTurn(text, 'nobody', '2026-10-23T10:00:00.000Z'), false);
});
test('refusalsBefore: consecutive blocks of the plan log since the last allow in either log', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  const wl = join(ws, 'stop-guard.jsonl'); const ml = mirrorOf(e);
  const args = { workspaceLog: wl, mirrorLog: ml, sessionId: SID };
  // no log yet is the first Stop of a plan, not a log that cannot be read
  assert.deepEqual(guard.refusalsBefore(args), { refusals: 0, unreadable: null });
  const b1 = line('2026-10-23T10:00:00.100Z', 'block', 'open-tasks', { refusals: 1 }); const b2 = line('2026-10-23T10:01:00.100Z', 'block', 'open-tasks', { refusals: 2 });
  writeLog(wl, [b1, b2]); writeLog(ml, [b1, b2]);
  assert.equal(guard.refusalsBefore(args).refusals, 2);
  // a mirror-only allow (ambiguous) after the blocks resets the count
  writeLog(ml, [b1, b2, line('2026-10-23T10:02:00.000Z', 'allow', 'ambiguous', { plan: null })]);
  assert.equal(guard.refusalsBefore(args).refusals, 0);
  // a hook-error line written by the wrapper carries a coarser timestamp that sorts before the block it follows: file order wins
  writeLog(ml, [b1, b2, { ts: '2026-10-23T10:01:00Z', session: SID, decision: 'allow', reason: 'hook-error', detail: 'module exit 1' }]);
  assert.equal(guard.refusalsBefore(args).refusals, 0);
  // a line only in the plan log is placed by its timestamp
  writeLog(ml, [b1]); writeLog(wl, [b1, b2]);
  assert.equal(guard.refusalsBefore(args).refusals, 2);
  // blocks found only in the mirror belong to another plan: neither counted nor a reset
  writeLog(wl, []); writeLog(ml, [line('2026-10-23T09:00:00.000Z', 'block', 'open-tasks', { plan: 'docs/earlier.md', refusals: 1 }), line('2026-10-23T09:01:00.000Z', 'block', 'open-tasks', { plan: 'docs/earlier.md', refusals: 2 })]);
  assert.equal(guard.refusalsBefore(args).refusals, 0);
  // an unreadable mirror leaves the plan log to answer
  writeLog(wl, [b1, b2]); chmodSync(ml, 0o000);
  assert.deepEqual(guard.refusalsBefore(args), { refusals: 2, unreadable: null });
  chmodSync(ml, 0o644);
});
test('refusalsBefore: an authoritative log that cannot be read or parsed is reported, never counted as no refusals', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  const wl = join(ws, 'stop-guard.jsonl'); const ml = mirrorOf(e);
  const args = { workspaceLog: wl, mirrorLog: ml, sessionId: SID };
  const b1 = line('2026-10-23T10:00:00.100Z', 'block', 'open-tasks', { refusals: 1 }); const b2 = line('2026-10-23T10:01:00.100Z', 'block', 'open-tasks', { refusals: 2 });
  // write-only: the blocks are there, the cap cannot see them
  writeLog(wl, [b1, b2]); writeLog(ml, []); chmodSync(wl, 0o200);
  assert.match(guard.refusalsBefore(args).unreadable, /EACCES/);
  chmodSync(wl, 0o644);
  // a whole line that is not JSON is damage, not absence
  writeLog(wl, [b1]); appendFileSync(wl, 'not json at all\n');
  assert.match(guard.refusalsBefore(args).unreadable, /malformed/);
  // the same damage in the mirror alone leaves the plan log to answer
  writeLog(wl, [b1, b2]); writeLog(ml, [b1]); appendFileSync(ml, 'not json at all\n');
  assert.deepEqual(guard.refusalsBefore(args), { refusals: 2, unreadable: null });
  // a half-written last line is a torn write, the same remains the ledger drops
  writeLog(wl, [b1, b2]); appendFileSync(wl, '{"ts":"2026-10-23T10:02');
  assert.deepEqual(guard.refusalsBefore(args), { refusals: 2, unreadable: null });
});
test('refusalsBefore: another session filling the shared plan log does not evict this session refusals', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  const wl = join(ws, 'stop-guard.jsonl'); const ml = mirrorOf(e);
  const b1 = line('2026-10-23T10:00:00.100Z', 'block', 'open-tasks', { refusals: 1 }); const b2 = line('2026-10-23T10:01:00.100Z', 'block', 'open-tasks', { refusals: 2 });
  const theirs = [];
  for (let i = 0; i < 200; i++) theirs.push({ ...line(`2026-10-23T11:${String(i % 60).padStart(2, '0')}:00.000Z`, 'block', 'open-tasks'), session: 'other-session' });
  writeLog(wl, [b1, b2, ...theirs]); writeLog(ml, [b1, b2, ...theirs]);
  assert.deepEqual(guard.refusalsBefore({ workspaceLog: wl, mirrorLog: ml, sessionId: SID }), { refusals: 2, unreadable: null });
});
test('appendLine: a half-written line is fenced off, never glued to the next record', () => {
  const e = env(); const ws = workspaceFor(e);
  const wl = join(ws, 'stop-guard.jsonl');
  const whole = line('2026-10-23T10:00:00.100Z', 'block', 'open-tasks', { refusals: 1 });
  writeLog(wl, [whole]); appendFileSync(wl, '{"ts":"2026-10-23T10:01:00.100Z","sess');
  assert.equal(guard.appendLine(wl, line('2026-10-23T10:02:00.100Z', 'allow', 'handback-text')), true);
  const text = readFileSync(wl, 'utf8');
  assert.match(text, /","sess\t#fragment\n/);
  const records = guard.ledgerRecords(text).map((l) => JSON.parse(l));
  assert.equal(records.length, 2); assert.equal(records[1].reason, 'handback-text');
  assert.deepEqual(guard.refusalsBefore({ workspaceLog: wl, mirrorLog: join(ws, 'absent.jsonl'), sessionId: SID }), { refusals: 0, unreadable: null });
});
test('recordDecision: a workspace removed under the hook is a failed log, not a workspace recreated after finish', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  const wl = join(ws, 'stop-guard.jsonl'); const ml = mirrorOf(e); const marker = join(ws, '.mirror-failed');
  rmSync(ws, { recursive: true });
  const r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:00:00.000Z', 'block', 'open-tasks', { refusals: 1 }) });
  assert.equal(r.loggedAs, 'log-failed'); assert.equal(r.line.decision, 'allow'); assert.equal(r.line.reason, 'log-failed');
  assert.equal(existsSync(ws), false); assert.equal(readLines(ml).at(-1).reason, 'log-failed');
  // the directory back without its ledger is a workspace finish has let go of too
  mkdirSync(ws, { recursive: true });
  assert.equal(guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:01:00.000Z', 'block', 'open-tasks', { refusals: 1 }) }).loggedAs, 'log-failed');
  assert.equal(existsSync(wl), false);
});
test('recordDecision: a symlink planted at either log is not written through', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  const wl = join(ws, 'stop-guard.jsonl'); const ml = mirrorOf(e); const marker = join(ws, '.mirror-failed');
  const prey = join(e.root, 'prey.txt'); writeFileSync(prey, 'untouched\n');
  mkdirSync(join(ml, '..'), { recursive: true }); writeFileSync(ml, '');
  symlinkSync(prey, wl);
  let r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:00:00.000Z', 'block', 'open-tasks', { refusals: 1 }) });
  assert.equal(r.loggedAs, 'log-failed'); assert.equal(readFileSync(prey, 'utf8'), 'untouched\n');
  assert.equal(readLines(ml).at(-1).reason, 'log-failed');
  // and the mirror: the plan log keeps the line, the marker records the gap
  rmSync(wl); rmSync(ml); symlinkSync(prey, ml);
  r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:01:00.000Z', 'block', 'open-tasks', { refusals: 1 }) });
  assert.equal(r.loggedAs, 'authoritative'); assert.equal(readFileSync(prey, 'utf8'), 'untouched\n');
  assert.equal(readLines(wl).length, 1); assert.equal(existsSync(marker), true);
});
test('discover: a removal tomb and an import staging are not candidate workspaces', () => {
  const e = env(); const plans = join(e.cache, 'hyperpowers', 'state', guard.cloneKey(e.repo), 'plans');
  for (const name of ['.removing-plan-abcdef12-4321', 'plan-abcdef12.import-4321', 'plan-abcdef12.importing-4321']) {
    mkdirSync(join(plans, name), { recursive: true }); ledger(join(plans, name), e);
  }
  assert.equal(guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }).kind, 'none');
  const ws = workspaceFor(e); ledger(ws, e);
  const d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache });
  assert.equal(d.kind, 'ledger'); assert.equal(d.workspace, ws);
});
test('discover: a plain-cache workspace imported into the state cache is one ledger, not two', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  const plain = join(e.cache, 'hyperpowers', 'sdd', guard.cloneKey(e.repo), 'plans');
  mkdirSync(plain, { recursive: true }); symlinkSync(ws, join(plain, 'plan-abcdef12'));
  const d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache });
  assert.equal(d.kind, 'ledger'); assert.equal(d.workspace, ws);
});
test('discover: a candidate that cannot be read is an ambiguity, not an absence', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  chmodSync(join(ws, 'progress.md'), 0o000);
  const d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache });
  chmodSync(join(ws, 'progress.md'), 0o644);
  assert.equal(d.kind, 'ambiguous'); assert.equal(d.candidates, 1); assert.deepEqual(d.matches, []);
  assert.deepEqual(d.unreadable, [join(ws, 'progress.md')]);
});
test('discover: one match beside a candidate that cannot be read proves nothing, so it is ambiguous', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  const other = workspaceFor(e, 'other-00000000'); ledger(other, e, { sid: 'someone-else' });
  chmodSync(join(other, 'progress.md'), 0o000);
  const d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache });
  chmodSync(join(other, 'progress.md'), 0o644);
  assert.equal(d.kind, 'ambiguous'); assert.equal(d.candidates, 2);
  assert.deepEqual(d.matches, [join(ws, 'progress.md')]);
  assert.deepEqual(d.unreadable, [join(other, 'progress.md')]);
});
test('appendLine: a write that lands short is a failed write, not a record', () => {
  const e = env(); const ws = workspaceFor(e);
  const wl = join(ws, 'stop-guard.jsonl'); const ml = mirrorOf(e); const marker = join(ws, '.mirror-failed');
  ledger(ws, e);
  guard.testHooks.write = (fd, buf) => writeSync(fd, buf.subarray(0, buf.length - 5));
  try {
    const r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:00:00.000Z', 'block', 'open-tasks', { refusals: 1 }) });
    assert.equal(r.loggedAs, 'none'); // the mirror is written through the same short seam
    assert.equal(guard.appendLine(wl, line('2026-10-23T10:01:00.000Z', 'allow', 'handback-text')), false);
  } finally { delete guard.testHooks.write; }
  // the torn bytes are fenced off, so the cap reads no refusal from them
  assert.deepEqual(guard.refusalsBefore({ workspaceLog: wl, mirrorLog: ml, sessionId: SID }), { refusals: 0, unreadable: null });
  const r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:02:00.000Z', 'block', 'open-tasks', { refusals: 1 }) });
  assert.equal(r.loggedAs, 'authoritative');
  assert.deepEqual(guard.refusalsBefore({ workspaceLog: wl, mirrorLog: ml, sessionId: SID }), { refusals: 1, unreadable: null });
});
test('recordDecision: a finish that moves the workspace between the open and the write gets no authoritative record', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  const wl = join(ws, 'stop-guard.jsonl'); const ml = mirrorOf(e); const marker = join(ws, '.mirror-failed');
  const tomb = join(dirname(ws), '.removing-plan-abcdef12-4321');
  guard.testHooks.beforeWrite = (p) => { if (p === wl) renameSync(ws, tomb); };
  let r;
  try {
    r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:00:00.000Z', 'block', 'open-tasks', { refusals: 1 }) });
  } finally { delete guard.testHooks.beforeWrite; }
  assert.equal(r.loggedAs, 'log-failed'); assert.equal(r.line.decision, 'allow');
  assert.equal(existsSync(ws), false); // the canonical path stays gone, finish keeps its removal
  assert.equal(readLines(ml).at(-1).reason, 'log-failed');
  // the line that did land is in the tomb, which finish deletes or restores whole
  assert.equal(readLines(join(tomb, 'stop-guard.jsonl')).length, 1);
});
test('recordDecision: the plan log first, then the mirror; failures become log-failed, mirror_failed, or nothing', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  const wl = join(ws, 'stop-guard.jsonl'); const ml = mirrorOf(e); const marker = join(ws, '.mirror-failed');
  let r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:00:00.000Z', 'block', 'open-tasks', { refusals: 1 }) });
  assert.equal(r.loggedAs, 'authoritative'); assert.equal(readLines(wl).length, 1); assert.deepEqual(readLines(ml), readLines(wl));
  // the mirror unwritable: the plan log has the line, the marker is left, the next line carries mirror_failed and clears it
  chmodSync(ml, 0o444);
  r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:01:00.000Z', 'block', 'open-tasks', { refusals: 2 }) });
  assert.equal(r.loggedAs, 'authoritative'); assert.equal(existsSync(marker), true); assert.equal(readLines(wl).length, 2); assert.equal(readLines(ml).length, 1);
  chmodSync(ml, 0o644);
  r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:02:00.000Z', 'allow', 'handback-text') });
  assert.equal(r.line.mirror_failed, true); assert.equal(existsSync(marker), false); assert.equal(readLines(ml).at(-1).mirror_failed, true);
  // the plan log unwritable: one log-failed allow in the mirror and nothing else, whatever the decision was
  chmodSync(wl, 0o444);
  const before = readLines(wl).length; const beforeMirror = readLines(ml).length;
  r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:03:00.000Z', 'block', 'open-tasks', { refusals: 1 }) });
  assert.equal(r.loggedAs, 'log-failed'); assert.equal(r.line.decision, 'allow'); assert.equal(r.line.reason, 'log-failed'); assert.equal(r.line.refusals, 0);
  assert.equal(readLines(wl).length, before); assert.equal(readLines(ml).length, beforeMirror + 1); assert.equal(readLines(ml).at(-1).reason, 'log-failed');
  // both unwritable: nothing recorded, the allow stands
  chmodSync(ml, 0o444);
  r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:04:00.000Z', 'block', 'open-tasks', { refusals: 1 }) });
  assert.equal(r.loggedAs, 'none'); assert.equal(r.line.decision, 'allow'); assert.equal(readLines(ml).length, beforeMirror + 1);
  chmodSync(ml, 0o644); chmodSync(wl, 0o644);
  // no workspace (ambiguous, receipt): the mirror only
  r = guard.recordDecision({ workspaceLog: null, mirrorLog: ml, marker: null, line: line('2026-10-23T10:05:00.000Z', 'allow', 'no-ledger', { plan: null, receipt: '/r' }) });
  assert.equal(r.loggedAs, 'mirror-only'); assert.equal(readLines(ml).at(-1).receipt, '/r');
});
test('recordDecision: a pending mirror_failed marker survives a double write failure and is reported by the next line that reaches a log', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  const wl = join(ws, 'stop-guard.jsonl'); const ml = mirrorOf(e); const marker = join(ws, '.mirror-failed');
  writeFileSync(marker, ''); writeLog(wl, []); writeLog(ml, []); chmodSync(wl, 0o444); chmodSync(ml, 0o444);
  let r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:00:00.000Z', 'block', 'open-tasks', { refusals: 1 }) });
  assert.equal(r.loggedAs, 'none'); assert.equal(existsSync(marker), true);
  chmodSync(wl, 0o644); chmodSync(ml, 0o644);
  r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:01:00.000Z', 'allow', 'handback-text') });
  assert.equal(r.line.mirror_failed, true); assert.equal(existsSync(marker), false); assert.equal(readLines(wl).at(-1).mirror_failed, true); assert.equal(readLines(ml).at(-1).mirror_failed, true);
});
test('discover: a workspace directory the hook cannot search is an ambiguity, not an absence', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  let d;
  chmodSync(ws, 0o000);
  try { d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }); } finally { chmodSync(ws, 0o755); }
  assert.equal(d.kind, 'ambiguous'); assert.deepEqual(d.matches, []);
  assert.deepEqual(d.unreadable, [join(ws, 'progress.md')]);
});
test('liveJobs: a job directory the hook cannot read is unreadable, not an allocation still in progress', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  for (const name of ['a', 'b']) {
    mkdirSync(join(ws, 'jobs', `${name}-x-0001`), { recursive: true });
    writeFileSync(join(ws, 'jobs', `${name}-x-0001`, 'meta.json'), JSON.stringify({ name, state: 'running' }));
  }
  const shut = join(ws, 'jobs', 'b-x-0001');
  chmodSync(shut, 0o000);
  try { assert.deepEqual(guard.liveJobs(ws), { live: ['a'], unreadable: ['b-x-0001'] }); } finally { chmodSync(shut, 0o755); }
});
test('recordDecision: a symlink on the mirror path sends no decision outside the cache', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  const wl = join(ws, 'stop-guard.jsonl'); const ml = mirrorOf(e); const marker = join(ws, '.mirror-failed');
  const outside = join(e.root, 'outside'); mkdirSync(outside);
  mkdirSync(join(e.cache, 'hyperpowers'), { recursive: true });
  symlinkSync(outside, join(e.cache, 'hyperpowers', 'stop-guard'));
  let r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:00:00.000Z', 'block', 'open-tasks', { refusals: 1 }) });
  assert.equal(r.loggedAs, 'authoritative'); assert.equal(existsSync(marker), true);
  assert.deepEqual(readdirSync(outside), []);
  // with no plan log to fall back on, the brief's double failure: nothing recorded
  r = guard.recordDecision({ workspaceLog: null, mirrorLog: ml, marker: null, line: line('2026-10-23T10:01:00.000Z', 'allow', 'ambiguous', { plan: null }) });
  assert.equal(r.loggedAs, 'none');
  assert.deepEqual(readdirSync(outside), []);
});
test('cloneKey: null outside a repository, stable inside one', () => {
  const e = env();
  assert.equal(guard.cloneKey(tmpdir()), null);
  assert.match(guard.cloneKey(e.repo), /^[0-9a-f]{40}$/);
});
test('discover: a receipt the hook cannot search is an ambiguity, not an absence', () => {
  const e = env(); const r = receipt(e, 'plan-abcdef12-20261023T000000Z');
  let d;
  chmodSync(r, 0o000);
  try { d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }); } finally { chmodSync(r, 0o755); }
  assert.equal(d.kind, 'ambiguous'); assert.deepEqual(d.matches, []);
  assert.deepEqual(d.unreadable, [join(r, 'progress.md')]);
  // a staging that cannot be searched cannot be classified either: whether it
  // is a receipt at all is what is unknown, so the directory is what is named
  const staging = receipt(e, '.staging-plan-abcdef12-20261023T000001Z');
  chmodSync(staging, 0o000);
  try { d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }); } finally { chmodSync(staging, 0o755); }
  assert.equal(d.kind, 'ambiguous'); assert.deepEqual(d.unreadable, [staging]);
});
test('discover: a receipts directory the hook cannot list is an ambiguity, not an absence', () => {
  const e = env(); const receipts = dirname(receipt(e, 'plan-abcdef12-20261023T000000Z'));
  let d;
  chmodSync(receipts, 0o000);
  try { d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }); } finally { chmodSync(receipts, 0o755); }
  assert.equal(d.kind, 'ambiguous'); assert.deepEqual(d.matches, []);
  assert.deepEqual(d.unreadable, [receipts]);
});
test('discover: one matching receipt beside one that cannot be read proves nothing, so it is ambiguous', () => {
  const e = env(); receipt(e, 'plan-abcdef12-20261023T000000Z');
  const other = receipt(e, 'other-bbbbbbbb-20261023T000001Z', 'someone-else');
  let d;
  chmodSync(join(other, 'progress.md'), 0o000);
  try { d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }); } finally { chmodSync(join(other, 'progress.md'), 0o644); }
  assert.equal(d.kind, 'ambiguous'); assert.deepEqual(d.matches, []);
  assert.deepEqual(d.unreadable, [join(other, 'progress.md')]);
});
