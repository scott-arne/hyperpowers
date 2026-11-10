import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import * as dg from './dispatch-guard.mjs';
import { cloneKey, discover } from './stop-guard.mjs';

// Fixtures in the shape of stop-guard.test.mjs: a repository with a plan, a
// state workspace under its clone key, a ledger that carries the session.
const SID = 'sess-5678';
const PLAN = 'docs/plan.md';
function makeRepo(root) {
  const repo = join(root, 'repo');
  mkdirSync(join(repo, 'docs'), { recursive: true });
  execFileSync('git', ['init', '-q', '-b', 'main', repo]);
  execFileSync('git', ['-C', repo, 'config', 'user.email', 't@example.com']);
  execFileSync('git', ['-C', repo, 'config', 'user.name', 't']);
  writeFileSync(join(repo, 'docs', 'plan.md'), '# Plan\n\n### Task 1: one\n');
  execFileSync('git', ['-C', repo, 'add', 'docs/plan.md']);
  execFileSync('git', ['-C', repo, 'commit', '-q', '-m', 'plan']);
  return repo;
}
function env() { const root = mkdtempSync(join(tmpdir(), 'dg-')); return { root, cache: join(root, 'cache'), repo: makeRepo(root) }; }
function workspaceFor(e, name = 'plan-abcdef12') {
  const ws = join(e.cache, 'hyperpowers', 'state', cloneKey(e.repo), 'plans', name);
  mkdirSync(ws, { recursive: true });
  return ws;
}
function ledger(ws, e, { sid = SID, header = `# SDD ledger — plan: ${PLAN}` } = {}) {
  const p = join(ws, 'progress.md');
  writeFileSync(p, [header, `session ${sid}: mode worktree on main at ${e.repo} started 2026-11-10T00:00:00Z`].join('\n') + '\n');
  return p;
}
function receipt(e, name = 'plan-abcdef12', sid = SID) {
  const r = join(e.cache, 'hyperpowers', 'receipts', name); mkdirSync(r, { recursive: true });
  writeFileSync(join(r, 'progress.md'), `# SDD ledger — plan: ${PLAN}\nsession ${sid}: mode worktree on main at ${e.repo} started x\n`);
}

// Transcript records in the shapes the field transcripts hold.
const T0 = Date.parse('2026-11-10T10:00:00.000Z');
const at = (s) => new Date(T0 + s * 1000).toISOString();
const call = (t, id, name, input, extra = {}) => ({ type: 'assistant', timestamp: at(t), isSidechain: false, message: { role: 'assistant', content: [{ type: 'tool_use', id, name, input }] }, ...extra });
const result = (t, id, toolUseResult, extra = {}) => ({ type: 'user', timestamp: at(t), isSidechain: false, message: { role: 'user', content: [{ type: 'tool_result', tool_use_id: id, content: [{ type: 'text', text: 'ok' }] }] }, toolUseResult, ...extra });
const SYNC = (agentId) => ({ status: 'completed', agentId, content: [{ type: 'text', text: 'done' }], totalDurationMs: 1000 });
const ASYNC = (agentId) => ({ isAsync: true, status: 'async_launched', agentId, description: 'reviewer' });
const jsonl = (recs) => recs.map((r) => JSON.stringify(r)).join('\n') + '\n';
const newestFirst = (recs) => recs.map((r) => JSON.stringify(r)).reverse();
function transcript(e, recs, name = 't.jsonl') { const p = join(e.root, name); writeFileSync(p, jsonl(recs)); return p; }
// A foreground implementer that came back synchronously: outside fork mode, owning a1 (named impl-1).
const syncSession = () => [call(1, 'tu1', 'Agent', { description: 'Implement Task 1', prompt: 'brief', run_in_background: false, name: 'impl-1' }), result(2, 'tu1', SYNC('a1'))];
// Fork mode: the dispatch came back async_launched, whatever the call passed.
const forkSession = (bg) => [call(1, 'tu1', 'Agent', { description: 'Implement Task 1', prompt: 'brief', run_in_background: bg }), result(2, 'tu1', ASYNC('a1'))];

const BG = { description: 'Review Task 1', prompt: 'review brief', run_in_background: true };
const RESUME = { to: 'a1', message: 'fix the findings', summary: 'fix round' };
const SILENT_R = { stdout: '', exitCode: 0 };
const payload = (e, tool, toolInput, extra = {}) => JSON.stringify({ session_id: SID, transcript_path: e.transcript, cwd: e.repo, permission_mode: 'default', hook_event_name: 'PreToolUse', tool_name: tool, tool_input: toolInput, tool_use_id: 'toolu_new', ...extra });
function planned(recs = syncSession()) { const e = env(); ledger(workspaceFor(e), e); e.transcript = transcript(e, recs); return e; }
const run = (e, tool, input, extra = {}, deps = {}) => dg.main(payload(e, tool, input, extra), { XDG_CACHE_HOME: e.cache }, deps);
const logOf = (e, sid = SID) => join(e.cache, 'hyperpowers', 'dispatch-guard', `${sid}.jsonl`);
const logLines = (e, sid = SID) => readFileSync(logOf(e, sid), 'utf8').trim().split('\n').map((l) => JSON.parse(l));

// The refusal texts, copied from the spec independently of the module.
const SKILL = fileURLToPath(new URL('../../skills/subagent-driven-development/SKILL.md', import.meta.url));
const BG_TEXT = (plan) => `SDD plan ${plan} is in progress in this session. On this harness every subagent is dispatched in the foreground (run_in_background: false): the turn stays open while it works, which is what the editor shows as the session working. Dispatch this one again with run_in_background: false. If you have not Read ${SKILL} in full since the last compaction, Read it now.`;
const SM_TEXT = (plan) => `SDD plan ${plan} is in progress in this session. On this harness a SendMessage resume runs in the background and the turn ends while the subagent works. Dispatch a fresh subagent in the foreground (run_in_background: false) with the brief path, the report-file path, and what you meant to send; for a fix round, the open findings verbatim on the original implementer's model. The report file records what the earlier subagent did. If you have not Read ${SKILL} in full since the last compaction, Read it now.`;
const deny = (text) => JSON.stringify({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: text } });

test('screen: a payload that is not an object, or has no usable session id, is silent', () => {
  for (const input of [null, [], 'x', 3]) assert.deepEqual(dg.screen(input), { done: true });
  for (const session_id of [undefined, '', '../x', 'a/b', 'a b', 7]) assert.deepEqual(dg.screen({ session_id, tool_name: 'SendMessage', tool_input: RESUME }), { done: true });
});
test('screen: a subagent call (agent_id present) is silent', () => {
  assert.deepEqual(dg.screen({ session_id: SID, agent_id: 'a9', tool_name: 'Agent', tool_input: BG }), { done: true });
  assert.deepEqual(dg.screen({ session_id: SID, agent_id: 'a9', tool_name: 'SendMessage', tool_input: RESUME }), { done: true });
});
test('screen: a tool other than Agent or SendMessage is silent', () => {
  for (const tool_name of ['Bash', 'Task', 'Read', undefined]) assert.deepEqual(dg.screen({ session_id: SID, tool_name, tool_input: BG }), { done: true });
});
test('screen: an Agent call whose run_in_background is not true is silent (step 2)', () => {
  for (const v of [false, 'false', undefined, null, 1, 'yes']) assert.deepEqual(dg.screen({ session_id: SID, tool_name: 'Agent', tool_input: { prompt: 'p', run_in_background: v } }), { done: true });
  assert.deepEqual(dg.screen({ session_id: SID, tool_name: 'Agent' }), { done: true });
});
test('screen: an Agent call with run_in_background true or "true" goes on', () => {
  for (const v of [true, 'true']) {
    const toolInput = { prompt: 'p', run_in_background: v };
    assert.deepEqual(dg.screen({ session_id: SID, tool_name: 'Agent', tool_input: toolInput }), { done: false, sessionId: SID, tool: 'Agent', toolInput });
  }
});
test('screen: a background Agent call whose prompt carries the extractor sentence is silent, logged as extractor', () => {
  const prompt = `Decision notes.\n\n    ${dg.EXTRACTOR_SENTENCE}. You do\n    not judge the decisions.`;
  assert.deepEqual(dg.screen({ session_id: SID, tool_name: 'Agent', tool_input: { prompt, run_in_background: true } }), { done: true, log: 'extractor', sessionId: SID, tool: 'Agent' });
});
test('screen: every controller SendMessage goes on, with its tool_input', () => {
  assert.deepEqual(dg.screen({ session_id: SID, tool_name: 'SendMessage', tool_input: RESUME }), { done: false, sessionId: SID, tool: 'SendMessage', toolInput: RESUME });
});
test('the extractor sentence opens the decision-notes template', () => {
  const tpl = readFileSync(fileURLToPath(new URL('../../skills/finishing-a-development-branch/decision-notes-prompt.md', import.meta.url)), 'utf8');
  assert.equal(dg.EXTRACTOR_SENTENCE, 'You write implementation notes for a list of design decisions');
  assert.ok(tpl.includes(dg.EXTRACTOR_SENTENCE));
});

test('planOf: the plan path from the ledger header', () => {
  const e = env();
  assert.deepEqual(dg.planOf(ledger(workspaceFor(e), e), SID), { plan: PLAN });
});
test('planOf: an unreadable ledger is an error naming the cause', () => {
  const e = env();
  assert.deepEqual(dg.planOf(join(e.root, 'missing.md'), SID), { error: 'ledger unreadable: ENOENT' });
  assert.deepEqual(dg.planOf(e.root, SID), { error: 'ledger unreadable: EISDIR' });
});
test('planOf: a missing or malformed header is an error', () => {
  const e = env(); const ws = workspaceFor(e);
  for (const header of ['# SDD ledger - plan: docs/plan.md', 'session x: y', '# SDD ledger — plan: ']) {
    assert.deepEqual(dg.planOf(ledger(ws, e, { header }), SID), { error: 'ledger header missing or malformed' });
  }
});
test('planOf: a ledger that no longer carries this session is an error', () => {
  const e = env();
  assert.deepEqual(dg.planOf(ledger(workspaceFor(e), e, { sid: 'someone-else' }), SID), { error: 'ledger no longer carries this session' });
});

test('transcriptFacts: a synchronous Agent result puts the session outside fork mode and records its id and name', () => {
  const f = dg.transcriptFacts(newestFirst(syncSession()));
  assert.equal(f.sync, true); assert.equal(f.capped, false);
  assert.deepEqual([...f.ownIds].sort(), ['a1', 'impl-1']);
});
test('transcriptFacts: in fork mode no result is synchronous, whatever the calls passed', () => {
  for (const bg of [true, 'true', false, 'false', undefined]) {
    const f = dg.transcriptFacts(newestFirst(forkSession(bg)));
    assert.equal(f.sync, false); assert.deepEqual([...f.ownIds], ['a1']);
  }
});
test('transcriptFacts: a session with no Agent result yet has no facts', () => {
  const f = dg.transcriptFacts(newestFirst([call(1, 'tu1', 'Agent', BG)]));
  assert.equal(f.sync, false); assert.equal(f.ownIds.size, 0);
});
test('transcriptFacts: isAsync false with status completed is synchronous; Task, the older tool name, counts', () => {
  const recs = [call(1, 'tu1', 'Task', { prompt: 'p' }), result(2, 'tu1', { ...SYNC('a2'), isAsync: false })];
  const f = dg.transcriptFacts(newestFirst(recs));
  assert.equal(f.sync, true); assert.deepEqual([...f.ownIds], ['a2']);
});
test('transcriptFacts: sidechain records do not count', () => {
  const f = dg.transcriptFacts(newestFirst(syncSession().map((r) => ({ ...r, isSidechain: true }))));
  assert.equal(f.sync, false); assert.equal(f.ownIds.size, 0);
});
test('transcriptFacts: a result whose call is not an Agent call does not count', () => {
  const recs = [call(1, 'tu1', 'SendMessage', RESUME), result(2, 'tu1', { success: true, message: 'Resuming agent a1', resumedAgentId: 'a1', status: 'completed', agentId: 'a1' })];
  const f = dg.transcriptFacts(newestFirst(recs));
  assert.equal(f.sync, false); assert.equal(f.ownIds.size, 0);
});
test('transcriptFacts: malformed and non-record lines are skipped', () => {
  const f = dg.transcriptFacts(['not json', '[1]', '"s"', '', 'null', ...newestFirst(syncSession())]);
  assert.equal(f.sync, true);
});
test('transcriptFacts: the reader\'s null sentinel marks the tail capped', () => {
  const f = dg.transcriptFacts([...newestFirst(syncSession()), null]);
  assert.equal(f.capped, true); assert.equal(f.sync, true);
});

test('readTranscriptFacts: no path or an absent transcript is an error', () => {
  const e = env();
  assert.deepEqual(dg.readTranscriptFacts(''), { error: 'no transcript path' });
  assert.deepEqual(dg.readTranscriptFacts(join(e.root, 'none.jsonl')), { error: 'transcript unreadable: ENOENT' });
});

const LEDGER = { kind: 'ledger', workspace: '/w', ledger: '/w/progress.md' };
const facts = (ids, sync, capped = false) => ({ ownIds: new Set(ids), sync, capped });
const decide = (tool, toolInput, f, extra = {}) => dg.decideDispatch({ tool, toolInput, discovery: LEDGER, plan: { plan: PLAN }, facts: f, ...extra });

test('decideDispatch: no ledger, a receipt, or an ambiguous match passes', () => {
  assert.deepEqual(dg.decideDispatch({ tool: 'Agent', toolInput: BG, discovery: { kind: 'none' } }), { decision: 'allow', reason: 'no-plan' });
  assert.deepEqual(dg.decideDispatch({ tool: 'Agent', toolInput: BG, discovery: { kind: 'receipt', receipt: '/r' } }), { decision: 'allow', reason: 'no-plan' });
  assert.deepEqual(dg.decideDispatch({ tool: 'SendMessage', toolInput: RESUME, discovery: { kind: 'ambiguous', candidates: 2, matches: [] } }), { decision: 'allow', reason: 'ambiguous' });
  assert.deepEqual(dg.decideDispatch({ tool: 'SendMessage', toolInput: RESUME }), { decision: 'allow', reason: 'no-plan' });
});
test('decideDispatch: a ledger or transcript read error passes as hook-error with its detail', () => {
  assert.deepEqual(decide('Agent', BG, facts(['a1'], true), { plan: { error: 'ledger header missing or malformed' } }), { decision: 'allow', reason: 'hook-error', detail: 'ledger header missing or malformed' });
  assert.deepEqual(decide('Agent', BG, { error: 'transcript unreadable: ENOENT' }), { decision: 'allow', reason: 'hook-error', detail: 'transcript unreadable: ENOENT' });
});
test('decideDispatch: a background Agent call (step 6)', () => {
  assert.deepEqual(decide('Agent', BG, facts(['a1'], true)), { decision: 'deny', reason: 'background-agent' });
  assert.deepEqual(decide('Agent', BG, facts(['a1'], true, true)), { decision: 'deny', reason: 'background-agent' });
  assert.deepEqual(decide('Agent', BG, facts(['a1'], false)), { decision: 'allow', reason: 'fork-mode' });
  assert.deepEqual(decide('Agent', BG, facts([], false)), { decision: 'allow', reason: 'fork-mode' });
  assert.deepEqual(decide('Agent', BG, facts([], false, true)), { decision: 'allow', reason: 'transcript-capped' });
});
test('decideDispatch: a SendMessage, in the spec\'s order (step 7)', () => {
  assert.deepEqual(decide('SendMessage', RESUME, facts(['a1'], true)), { decision: 'deny', reason: 'sendmessage-resume' });
  assert.deepEqual(decide('SendMessage', { to: 'impl-1', message: 'm' }, facts(['a1', 'impl-1'], true)), { decision: 'deny', reason: 'sendmessage-resume' });
  assert.deepEqual(decide('SendMessage', RESUME, facts(['a1'], true, true)), { decision: 'deny', reason: 'sendmessage-resume' });
  assert.deepEqual(decide('SendMessage', RESUME, facts(['a1'], false, true)), { decision: 'allow', reason: 'transcript-capped' });
  assert.deepEqual(decide('SendMessage', { to: 'x', message: 'm' }, facts(['a1'], true, true)), { decision: 'allow', reason: 'transcript-capped' });
  assert.deepEqual(decide('SendMessage', { to: 'x', message: 'm' }, facts(['a1'], true)), { decision: 'allow', reason: 'not-own-agent' });
  assert.deepEqual(decide('SendMessage', { to: 'x', message: 'm' }, facts([], false)), { decision: 'allow', reason: 'not-own-agent' });
  assert.deepEqual(decide('SendMessage', { message: 'm' }, facts(['a1'], true)), { decision: 'allow', reason: 'not-own-agent' });
  assert.deepEqual(decide('SendMessage', RESUME, facts(['a1'], false)), { decision: 'allow', reason: 'fork-mode' });
});
test('a capped tail with the facts inside it refuses; with them outside it, transcript-capped', () => {
  const e = env(); const opts = { capBytes: 64 * 1024, chunkBytes: 16 * 1024 };
  const filler = Array.from({ length: 40 }, (_, i) => call(10 + i, `f${i}`, 'Read', { file_path: 'x'.repeat(4000) }));
  const inside = dg.readTranscriptFacts(transcript(e, [...filler, ...syncSession()], 'inside.jsonl'), opts);
  assert.equal(inside.capped, true); assert.equal(inside.sync, true);
  assert.deepEqual(decide('Agent', BG, inside), { decision: 'deny', reason: 'background-agent' });
  assert.deepEqual(decide('SendMessage', RESUME, inside), { decision: 'deny', reason: 'sendmessage-resume' });
  const outside = dg.readTranscriptFacts(transcript(e, [...syncSession(), ...filler], 'outside.jsonl'), opts);
  assert.equal(outside.capped, true); assert.equal(outside.sync, false);
  assert.deepEqual(decide('Agent', BG, outside), { decision: 'allow', reason: 'transcript-capped' });
  assert.deepEqual(decide('SendMessage', RESUME, outside), { decision: 'allow', reason: 'transcript-capped' });
});

test('refusalText: both texts, verbatim from the spec, naming the absolute SKILL.md path', () => {
  assert.equal(dg.refusalText('background-agent', PLAN), BG_TEXT(PLAN));
  assert.equal(dg.refusalText('sendmessage-resume', PLAN), SM_TEXT(PLAN));
  assert.equal(dg.SKILL_PATH, SKILL); assert.ok(existsSync(dg.SKILL_PATH));
});

test('main: a background Agent call outside fork mode is refused with the exact deny and logged', () => {
  const e = planned();
  assert.deepEqual(run(e, 'Agent', BG), { stdout: deny(BG_TEXT(PLAN)), exitCode: 0 });
  const [l] = logLines(e);
  assert.deepEqual(Object.keys(l), ['ts', 'session', 'tool', 'tool_use_id', 'decision', 'reason', 'plan', 'elapsed_ms']);
  assert.equal(l.session, SID); assert.equal(l.tool, 'Agent'); assert.equal(l.tool_use_id, 'toolu_new');
  assert.equal(l.decision, 'deny'); assert.equal(l.reason, 'background-agent'); assert.equal(l.plan, PLAN);
  assert.ok(!Number.isNaN(Date.parse(l.ts))); assert.equal(typeof l.elapsed_ms, 'number');
});
test('main: a SendMessage to the session\'s own subagent is refused and logged with to', () => {
  const e = planned();
  assert.deepEqual(run(e, 'SendMessage', RESUME), { stdout: deny(SM_TEXT(PLAN)), exitCode: 0 });
  const [l] = logLines(e);
  assert.deepEqual(Object.keys(l), ['ts', 'session', 'tool', 'tool_use_id', 'decision', 'reason', 'plan', 'to', 'elapsed_ms']);
  assert.equal(l.to, 'a1'); assert.equal(l.reason, 'sendmessage-resume'); assert.equal(l.decision, 'deny');
});
test('main: a foreground Agent call never reaches the gathering code and writes nothing', () => {
  const e = planned(); let gathered = 0; const gather = () => { gathered++; return {}; };
  for (const input of [{ prompt: 'p', run_in_background: false }, { prompt: 'p' }]) assert.deepEqual(run(e, 'Agent', input, {}, { gather }), SILENT_R);
  assert.equal(gathered, 0);
  assert.equal(existsSync(join(e.cache, 'hyperpowers', 'dispatch-guard')), false);
  run(e, 'SendMessage', RESUME, {}, { gather });
  assert.equal(gathered, 1);
});
test('main: a subagent\'s call is silent and writes nothing', () => {
  const e = planned();
  assert.deepEqual(run(e, 'Agent', BG, { agent_id: 'a9' }), SILENT_R);
  assert.deepEqual(run(e, 'SendMessage', RESUME, { agent_id: 'a9' }), SILENT_R);
  assert.equal(existsSync(logOf(e)), false);
});
test('main: the extractor\'s background dispatch passes, logged as extractor', () => {
  const e = planned();
  assert.deepEqual(run(e, 'Agent', { prompt: `${dg.EXTRACTOR_SENTENCE}. You do not judge.`, run_in_background: true }), SILENT_R);
  const [l] = logLines(e);
  assert.equal(l.decision, 'allow'); assert.equal(l.reason, 'extractor'); assert.equal(l.plan, null);
});
test('main: no ledger, a receipt alone, and two ledgers pass', () => {
  const none = env(); none.transcript = transcript(none, syncSession());
  assert.deepEqual(run(none, 'Agent', BG), SILENT_R); assert.equal(logLines(none)[0].reason, 'no-plan');
  const rec = env(); rec.transcript = transcript(rec, syncSession()); receipt(rec);
  assert.deepEqual(run(rec, 'SendMessage', RESUME), SILENT_R); assert.equal(logLines(rec)[0].reason, 'no-plan');
  const two = env(); two.transcript = transcript(two, syncSession()); ledger(workspaceFor(two, 'a-11111111'), two); ledger(workspaceFor(two, 'b-22222222'), two);
  assert.deepEqual(run(two, 'Agent', BG), SILENT_R); assert.equal(logLines(two)[0].reason, 'ambiguous');
});
test('main: a fork-mode session passes both calls, whatever its calls passed', () => {
  for (const bg of [true, 'true']) {
    const e = planned(forkSession(bg));
    assert.deepEqual(run(e, 'Agent', { ...BG, run_in_background: bg }), SILENT_R);
    assert.deepEqual(run(e, 'SendMessage', RESUME), SILENT_R);
    assert.deepEqual(logLines(e).map((l) => l.reason), ['fork-mode', 'fork-mode']);
  }
});
test('main: a session with no Agent result yet passes both calls', () => {
  const e = planned([call(1, 'tu1', 'Agent', BG)]);
  assert.deepEqual(run(e, 'Agent', BG), SILENT_R);
  assert.deepEqual(run(e, 'SendMessage', RESUME), SILENT_R);
  assert.deepEqual(logLines(e).map((l) => l.reason), ['fork-mode', 'not-own-agent']);
});
test('main: a SendMessage to anything that is not this session\'s subagent passes as not-own-agent', () => {
  const e = planned();
  assert.deepEqual(run(e, 'SendMessage', { to: 'other-session', message: 'hi' }), SILENT_R);
  const [l] = logLines(e); assert.equal(l.reason, 'not-own-agent'); assert.equal(l.to, 'other-session');
});
test('main: an unreadable transcript passes as hook-error', () => {
  const e = planned(); e.transcript = join(e.root, 'gone.jsonl');
  assert.deepEqual(run(e, 'Agent', BG), SILENT_R);
  const [l] = logLines(e); assert.equal(l.reason, 'hook-error'); assert.equal(l.detail, 'transcript unreadable: ENOENT'); assert.equal(l.plan, PLAN);
});
test('main: a malformed ledger header passes as hook-error', () => {
  const e = env(); ledger(workspaceFor(e), e, { header: '# not a ledger header' }); e.transcript = transcript(e, syncSession());
  assert.deepEqual(run(e, 'Agent', BG), SILENT_R);
  const [l] = logLines(e); assert.equal(l.reason, 'hook-error'); assert.equal(l.detail, 'ledger header missing or malformed'); assert.equal(l.plan, null);
});
test('main: a ledger replaced between discovery and the read passes as hook-error', () => {
  const e = planned(); const ws = workspaceFor(e);
  const gather = (args) => dg.gatherFacts(args, { discoverFn: (a) => { const d = discover(a); ledger(ws, e, { sid: 'someone-else' }); return d; } });
  assert.deepEqual(run(e, 'SendMessage', RESUME, {}, { gather }), SILENT_R);
  const [l] = logLines(e); assert.equal(l.reason, 'hook-error'); assert.equal(l.detail, 'ledger no longer carries this session');
});
test('main: malformed stdin is silent', () => {
  assert.deepEqual(dg.main('not json', {}), SILENT_R);
  assert.deepEqual(dg.main('', {}), SILENT_R);
  assert.deepEqual(dg.main('[]', {}), SILENT_R);
});
test('main: no path prints an allow', () => {
  const outs = [];
  const e = planned(); outs.push(run(e, 'Agent', BG).stdout, run(e, 'SendMessage', RESUME).stdout, run(e, 'Agent', { prompt: 'p' }).stdout, run(e, 'SendMessage', { to: 'x', message: 'm' }).stdout);
  const f = planned(forkSession(true)); outs.push(run(f, 'Agent', BG).stdout, run(f, 'SendMessage', RESUME).stdout);
  for (const out of outs) {
    if (out === '') continue;
    assert.equal(JSON.parse(out).hookSpecificOutput.permissionDecision, 'deny');
  }
  assert.equal(outs.filter((o) => o !== '').length, 2);
});
test('main: DISPATCH_GUARD_FAULT=throw throws after the decision', () => {
  const e = planned();
  assert.throws(() => dg.main(payload(e, 'Agent', BG), { XDG_CACHE_HOME: e.cache, DISPATCH_GUARD_FAULT: 'throw' }), /injected fault/);
});
test('main: a symlink at the log path is not followed, and the refusal still prints', () => {
  const e = planned();
  mkdirSync(join(e.cache, 'hyperpowers', 'dispatch-guard'), { recursive: true });
  const target = join(e.root, 'elsewhere.jsonl'); writeFileSync(target, '');
  symlinkSync(target, logOf(e));
  assert.deepEqual(run(e, 'Agent', BG), { stdout: deny(BG_TEXT(PLAN)), exitCode: 0 });
  assert.equal(readFileSync(target, 'utf8'), '');
});
