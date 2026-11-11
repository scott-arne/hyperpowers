// The SDD dispatch guard, a PreToolUse hook on Claude Code. It refuses the two
// calls that end an SDD controller's turn while a subagent works: an Agent
// dispatch with run_in_background true, and a SendMessage resume of one of the
// session's own subagents. The skill already forbids both outside fork mode,
// but after a compaction the controller no longer has those lines, and an
// editor such as Zed shows the session idle for as long as the background
// subagent runs. The design is
// docs/hyperpowers/specs/2026-11-10-sdd-dispatch-guard-design.md.
//
// The hook refuses or stays silent. A PreToolUse allow would skip the user's
// permission prompts, so no path prints one. Anything it cannot read passes,
// and there is no refusal cap: a refused dispatch always has an allowed
// substitute, the same dispatch in the foreground.
import { readFileSync, realpathSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { TAIL_CAP, TAIL_CHUNK, appendLine, discover, ledgerRecords, linesFromEnd } from './stop-guard.mjs';

// The opening sentence of skills/finishing-a-development-branch/
// decision-notes-prompt.md. The decision extractor is the one background
// dispatch SDD makes on purpose; tests/sdd/test-sdd-contract.sh keeps the
// sentence in the template.
export const EXTRACTOR_SENTENCE = 'You write implementation notes for a list of design decisions';
export const SKILL_PATH = fileURLToPath(new URL('../../skills/subagent-driven-development/SKILL.md', import.meta.url));
// The header planState parses in stop-guard.mjs.
const HEADER = /^# SDD ledger — plan: (.+)$/;
// stop-guard.mjs keeps its own set private. Task is the tool's older name,
// which older transcripts still carry.
const AGENT_TOOLS = new Set(['Agent', 'Task']);
const SILENT = Object.freeze({ stdout: '', exitCode: 0 });

// Steps 1 to 3 of the decision order: the payload alone, no file read. Nearly
// every call is a foreground dispatch, so step 2 has to be cheap.
export function screen(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return { done: true };
  const sessionId = typeof input.session_id === 'string' ? input.session_id : '';
  // One token, as the stop guard requires: the log path is built from it.
  if (!sessionId || /[^A-Za-z0-9._-]/.test(sessionId)) return { done: true };
  if (input.agent_id != null) return { done: true };
  const tool = input.tool_name;
  if (tool !== 'Agent' && tool !== 'SendMessage') return { done: true };
  const toolInput = input.tool_input && typeof input.tool_input === 'object' ? input.tool_input : {};
  if (tool === 'Agent') {
    // A fork-mode controller has been seen passing the string "true".
    const bg = toolInput.run_in_background;
    if (bg !== true && bg !== 'true') return { done: true };
    if (typeof toolInput.prompt === 'string' && toolInput.prompt.includes(EXTRACTOR_SENTENCE)) return { done: true, log: 'extractor', sessionId, tool };
  }
  return { done: false, sessionId, tool, toolInput };
}

// Step 4's read: the plan path from the ledger header. The session's line is
// checked again because sdd-state can replace the ledger between discovery
// and this read.
export function planOf(ledgerPath, sessionId) {
  let records;
  try { records = ledgerRecords(readFileSync(ledgerPath, 'utf8')); } catch (err) { return { error: `ledger unreadable: ${err?.code || 'error'}` }; }
  const m = (records[0] || '').match(HEADER);
  if (!m) return { error: 'ledger header missing or malformed' };
  if (!records.some((l) => l.startsWith(`session ${sessionId}:`))) return { error: 'ledger no longer carries this session' };
  return { plan: m[1] };
}

// Step 5: from main-chain records, the ids of this session's own subagents
// and whether any Agent call came back synchronously, which is the evidence
// that the session is outside fork mode. A call's `name` input counts only
// with a result, so a refused call registers no name. Lines that do not parse
// are skipped: a fact the tail does not show is a pass, never a refusal.
export function transcriptFacts(linesNewestFirst) {
  const recs = []; let capped = false;
  for (const l of linesNewestFirst) {
    if (l === null) { capped = true; break; }
    if (!l.trim()) continue;
    let rec; try { rec = JSON.parse(l); } catch { continue; }
    if (!rec || typeof rec !== 'object' || Array.isArray(rec) || rec.isSidechain) continue;
    recs.push(rec);
  }
  recs.reverse();
  const agentCalls = new Map();
  const ownIds = new Set(); let sync = false;
  for (const rec of recs) {
    const content = rec.message?.content;
    if (!Array.isArray(content)) continue;
    if (rec.type === 'assistant') {
      for (const b of content) if (b?.type === 'tool_use' && AGENT_TOOLS.has(b.name)) agentCalls.set(b.id, b.input && typeof b.input === 'object' ? b.input : {});
      continue;
    }
    if (rec.type !== 'user') continue;
    for (const b of content) {
      if (b?.type !== 'tool_result' || !agentCalls.has(b.tool_use_id)) continue;
      const r = rec.toolUseResult;
      if (!r || typeof r !== 'object' || typeof r.agentId !== 'string' || !r.agentId) continue;
      ownIds.add(r.agentId);
      const name = agentCalls.get(b.tool_use_id).name;
      if (typeof name === 'string' && name) ownIds.add(name);
      if (r.status === 'completed' && (r.isAsync === undefined || r.isAsync === false)) sync = true;
    }
  }
  return { ownIds, sync, capped };
}

export function readTranscriptFacts(path, { capBytes = TAIL_CAP, chunkBytes = TAIL_CHUNK } = {}) {
  if (!path) return { error: 'no transcript path' };
  try { return transcriptFacts(linesFromEnd(path, capBytes, chunkBytes)); } catch (err) { return { error: `transcript unreadable: ${err?.code || 'error'}` }; }
}

// Steps 4 and 5, each only when the one before it found what it needs.
export function gatherFacts({ sessionId, cwd, cacheRoot, transcriptPath }, { discoverFn = discover } = {}) {
  const discovery = discoverFn({ sessionId, cwd, cacheRoot });
  if (discovery?.kind !== 'ledger') return { discovery };
  const plan = planOf(discovery.ledger, sessionId);
  if (plan.error) return { discovery, plan };
  return { discovery, plan, facts: readTranscriptFacts(transcriptPath) };
}

// Steps 4 to 7 as a pure function of what gatherFacts found.
export function decideDispatch({ tool, toolInput = {}, discovery, plan = null, facts = null }) {
  if (discovery?.kind !== 'ledger') return { decision: 'allow', reason: discovery?.kind === 'ambiguous' ? 'ambiguous' : 'no-plan' };
  if (!plan || plan.error) return { decision: 'allow', reason: 'hook-error', detail: plan?.error || 'plan not read' };
  if (!facts || facts.error) return { decision: 'allow', reason: 'hook-error', detail: facts?.error || 'transcript not read' };
  if (tool === 'Agent') {
    if (facts.sync) return { decision: 'deny', reason: 'background-agent' };
    return { decision: 'allow', reason: facts.capped ? 'transcript-capped' : 'fork-mode' };
  }
  const to = typeof toolInput.to === 'string' ? toolInput.to : '';
  const own = to !== '' && facts.ownIds.has(to);
  if (own && facts.sync) return { decision: 'deny', reason: 'sendmessage-resume' };
  if (facts.capped) return { decision: 'allow', reason: 'transcript-capped' };
  if (!own) return { decision: 'allow', reason: 'not-own-agent' };
  return { decision: 'allow', reason: 'fork-mode' };
}

export function refusalText(reason, plan, skill = SKILL_PATH) {
  const head = `SDD plan ${plan} is in progress in this session.`;
  const reread = `If you have not Read ${skill} in full since the last compaction, Read it now.`;
  if (reason === 'background-agent') return `${head} On this harness every subagent is dispatched in the foreground (run_in_background: false): the turn stays open while it works, which is what the editor shows as the session working. Dispatch this one again with run_in_background: false. ${reread}`;
  return `${head} On this harness a SendMessage resume runs in the background and the turn ends while the subagent works. Dispatch a fresh subagent in the foreground (run_in_background: false) with the brief path, the report-file path, and what you meant to send; for a fix round, the open findings verbatim on the original implementer's model. The report file records what the earlier subagent did. ${reread}`;
}

export function main(stdinText, env = process.env, deps = {}) {
  const started = Date.now();
  let input;
  try { input = JSON.parse(stdinText || '{}'); } catch { return SILENT; }
  const s = screen(input);
  if (s.done && !s.log) return SILENT;
  const cacheRoot = env.XDG_CACHE_HOME || join(env.HOME || '', '.cache');
  let d; let plan = null;
  if (s.done) d = { decision: 'allow', reason: s.log };
  else {
    const gather = deps.gather || gatherFacts;
    const g = gather({
      sessionId: s.sessionId,
      cwd: typeof input.cwd === 'string' && input.cwd ? input.cwd : process.cwd(),
      cacheRoot,
      transcriptPath: typeof input.transcript_path === 'string' ? input.transcript_path : '',
    }) || {};
    plan = g.plan || null;
    d = decideDispatch({ tool: s.tool, toolInput: s.toolInput, discovery: g.discovery, plan: g.plan, facts: g.facts });
  }
  if (env.DISPATCH_GUARD_FAULT === 'throw') throw new Error('injected fault');
  const line = { ts: new Date().toISOString(), session: s.sessionId, tool: s.tool };
  if (typeof input.tool_use_id === 'string' && input.tool_use_id) line.tool_use_id = input.tool_use_id;
  line.decision = d.decision;
  line.reason = d.reason;
  line.plan = plan?.plan ?? null;
  if (s.tool === 'SendMessage') line.to = typeof s.toolInput.to === 'string' ? s.toolInput.to : null;
  if (d.detail) line.detail = d.detail;
  line.elapsed_ms = Date.now() - started;
  // The log is a record, not a condition: a refusal stands when the line
  // could not be written.
  appendLine(join(cacheRoot, 'hyperpowers', 'dispatch-guard', `${s.sessionId}.jsonl`), line, { mkdirsUnder: cacheRoot });
  if (d.decision !== 'deny') return SILENT;
  return { stdout: JSON.stringify({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: refusalText(d.reason, plan.plan) } }), exitCode: 0 };
}

// CLI entry, as in stop-guard.mjs: the only place that reads stdin and writes
// stdout. node resolves symlinks for the main module's URL but leaves argv
// alone, so the comparison is on the resolved path, through pathToFileURL. An
// uncaught throw exits 1, which the wrapper turns into a hook-error line.
let mainPath = process.argv[1] || '';
try { if (mainPath) mainPath = realpathSync(mainPath); } catch { /* compare the raw path */ }
if (mainPath && import.meta.url === pathToFileURL(mainPath).href) {
  const text = readFileSync(0, 'utf8');
  const r = main(text, process.env);
  if (r.stdout) process.stdout.write(r.stdout + '\n');
  process.exit(r.exitCode);
}
