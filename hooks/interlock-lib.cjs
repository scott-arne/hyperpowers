#!/usr/bin/env node
// Node side of the first-edit interlock (hooks/first-edit-interlock calls it;
// a .cjs file because the plugin's package.json declares "type": "module";
// the evals analyzer calls the same file from the pinned plugin commit).
//
// Modes:
//   --hook              stdin: the PreToolUse payload. stdout: one line,
//                       "<decision>\t<session_id>\t<transcript_path>" where
//                       decision is "attempt" (a mutation attempt) or "skip".
//   --wave <transcript> stdout: the message id of the last assistant record in
//                       the transcript's last 64 KiB, or "unknown".
//   --publish <tmp> <marker>
//                       rename(2) tmp onto marker. Exit 0 published, 3 lost the
//                       race (marker exists and is not empty), 1 anything else.
//   --batch             stdin: a JSON array of {"tool_name","tool_input"} or of
//                       command strings. stdout: one line per item,
//                       "attempt" or "read-only".
//   --vectors <tsv>     run every "<command>\t<expected>" line; print "ok <n>"
//                       and exit 0, or print each mismatch and exit 1.
//
// The mutation definition lives in classify() below and is the one the design
// spec states. Unknown means mutation: the classifier fails closed.
//
// No heredoc operator (two adjacent less-than signs) appears in this file: the hooks
// fence test scans every file in hooks/ for one.

'use strict';

const fs = require('fs');

const MUTATING_TOOLS = new Set(['Edit', 'Write', 'MultiEdit', 'NotebookEdit']);

const ALLOW = new Set([
  'ls', 'cat', 'head', 'tail', 'wc', 'grep', 'egrep', 'fgrep', 'rg', 'ag',
  'sort', 'uniq', 'cut', 'tr', 'diff', 'cmp', 'comm', 'file', 'stat', 'du',
  'df', 'pwd', 'echo', 'printf', 'true', 'false', 'test', '[', 'which',
  'whereis', 'type', 'printenv', 'date', 'uname', 'id', 'whoami', 'hostname',
  'basename', 'dirname', 'realpath', 'readlink', 'jq', 'column', 'nl', 'od',
  'hexdump', 'strings', 'md5', 'md5sum', 'shasum', 'sha256sum', 'cksum', 'seq',
  'sleep', 'cd', 'pushd', 'popd', 'export', 'set', 'unset', 'shopt', 'read',
  'wait', 'jobs', ':', 'find', 'git',
]);

const ALLOWED_ASSIGNMENTS = new Set([
  'LC_ALL', 'LC_COLLATE', 'LC_CTYPE', 'LANG', 'TZ', 'TERM', 'COLUMNS', 'LINES',
  'NO_COLOR', 'CLICOLOR',
]);

const FIND_MUTATING = new Set([
  '-delete', '-exec', '-execdir', '-ok', '-okdir', '-fprint', '-fprint0',
  '-fprintf', '-fls',
]);

const GIT_READONLY = new Set([
  'status', 'log', 'diff', 'show', 'blame', 'grep', 'rev-parse', 'rev-list',
  'ls-files', 'ls-tree', 'cat-file', 'describe', 'merge-base', 'name-rev',
  'shortlog', 'show-ref',
]);
const GIT_CONFIG_READONLY = new Set(['--get', '--get-all', '--get-regexp', '--list']);
const GIT_GLOBAL_SKIP_WITH_VALUE = new Set(['-C']);
const GIT_GLOBAL_SKIP = new Set(['--no-pager', '-P', '--no-optional-locks']);
const GIT_HELPER_OPTIONS = new Set(['-o', '--output', '-O', '--open-files-in-pager', '--ext-diff', '--textconv']);
const GIT_BRANCH_FLAGS = new Set([
  '-a', '--all', '-r', '--remotes', '-l', '--list', '-v', '-vv', '--verbose',
  '--show-current', '--color', '--no-color', '--column', '--no-column',
]);
// Options that take a required value, either joined (--sort=x) or as the next
// word (--sort x). --color and --column take an optional value in the joined
// form only: a bare --color followed by a word leaves that word positional,
// so it is a flag here and never consumes its neighbour.
const GIT_BRANCH_VALUED = new Set([
  '--contains', '--no-contains', '--merged', '--no-merged', '--points-at',
  '--sort', '--format',
]);
const GIT_TAG_FLAGS = new Set(['-l', '--list', '-n', '--color', '--column']);
const GIT_TAG_VALUED = new Set([
  '--contains', '--no-contains', '--points-at', '--merged', '--no-merged',
  '--sort', '--format',
]);

const WRAPPERS_MUTATING = new Set([
  'sudo', 'doas', 'xargs', 'sh', 'bash', 'zsh', 'dash', 'ksh', 'eval', 'exec',
  'source', '.',
]);

// ---------------------------------------------------------------------------
// Lexing
// ---------------------------------------------------------------------------

// Remove heredoc bodies: after an unquoted heredoc operator (two less-than signs, not three) the delimiter word
// ends the body on its own line. The command line itself stays. Bash expands $( ) and backticks inside
// a heredoc whose delimiter is unquoted, so those bodies are returned for classification; a quoted
// delimiter makes the body inert.
function stripHeredocs(text) {
  const lines = text.split('\n');
  const out = [];
  const subs = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    const delimiters = heredocDelimiters(line);
    out.push(line);
    i += 1;
    for (const delim of delimiters) {
      const body = [];
      while (i < lines.length && lines[i].replace(/^\t+/, '') !== delim.word) {
        body.push(lines[i]);
        i += 1;
      }
      // Substitutions may span lines, so the body is scanned as one text.
      if (!delim.quoted) collectSubstitutions(body.join('\n'), subs);
      i += 1; // the delimiter line itself
    }
  }
  return { text: out.join('\n'), subs };
}

// The bodies of every $( ) and backtick substitution in one heredoc body line.
function collectSubstitutions(line, subs) {
  let i = 0;
  while (i < line.length) {
    const c = line[i];
    if (c === '\\') { i += 2; continue; }
    if (c === '$' && line[i + 1] === '(') {
      const end = matchParen(line, i + 1);
      subs.push(line.slice(i + 2, end));
      i = end + 1;
      continue;
    }
    if (c === '`') {
      const end = line.indexOf('`', i + 1);
      const stop = end === -1 ? line.length : end;
      subs.push(line.slice(i + 1, stop));
      i = stop + 1;
      continue;
    }
    i += 1;
  }
}

function heredocDelimiters(line) {
  const found = [];
  let q = null;
  for (let i = 0; i < line.length; i += 1) {
    const c = line[i];
    if (q) {
      if (c === '\\' && q === '"') { i += 1; continue; }
      if (c === q) q = null;
      continue;
    }
    if (c === '\\') { i += 1; continue; }
    if (c === "'" || c === '"') { q = c; continue; }
    // An unquoted # at a word start opens a comment: the rest of the line,
    // heredoc-looking or not, is text.
    if (c === '#' && (i === 0 || /[\s;|&(]/.test(line[i - 1]))) break;
    if (c === '<' && line[i + 1] === '<' && line[i + 2] !== '<') {
      let j = i + 2;
      if (line[j] === '-') j += 1;
      while (line[j] === ' ' || line[j] === '\t') j += 1;
      let word = '';
      let wq = null;
      let quoted = false;
      for (; j < line.length; j += 1) {
        const d = line[j];
        if (wq) { if (d === wq) wq = null; else word += d; continue; }
        if (d === "'" || d === '"') { wq = d; quoted = true; continue; }
        if (d === '\\') { j += 1; word += line[j] || ''; quoted = true; continue; }
        if (d === ' ' || d === '\t' || d === ';' || d === '|' || d === '&' || d === '>' || d === '<') break;
        word += d;
      }
      if (word) found.push({ word, quoted });
      i = j - 1;
    }
  }
  return found;
}

// Split text into top-level segments on unquoted |, ||, |&, &&, ;, &, and
// newlines. Bodies of $( ), ` `, <( ) are extracted into `subs` (each to be
// classified as its own command); >( ) marks the segment as redirecting.
function segments(text) {
  const segs = [];
  const subs = [];
  let cur = '';
  let redirectingSubst = false;
  let q = null;
  let i = 0;
  const pushSeg = () => {
    segs.push({ text: cur, redirectingSubst });
    cur = '';
    redirectingSubst = false;
  };
  while (i < text.length) {
    const c = text[i];
    const n = text[i + 1];
    if (q) {
      // Substitutions stay active inside double quotes; single quotes are inert.
      if (q === '"' && c === '$' && n === '(') {
        const end = matchParen(text, i + 1);
        subs.push(text.slice(i + 2, end));
        cur += ' __SUBST__ ';
        i = end + 1;
        continue;
      }
      if (q === '"' && c === '`') {
        const end = text.indexOf('`', i + 1);
        const stop = end === -1 ? text.length : end;
        subs.push(text.slice(i + 1, stop));
        cur += ' __SUBST__ ';
        i = stop + 1;
        continue;
      }
      cur += c;
      if (c === '\\' && q === '"') { cur += n === undefined ? '' : n; i += 2; continue; }
      if (c === q) q = null;
      i += 1;
      continue;
    }
    if (c === '\\') { cur += c + (n === undefined ? '' : n); i += 2; continue; }
    if (c === "'" || c === '"') { q = c; cur += c; i += 1; continue; }
    if ((c === '$' && n === '(') || (c === '<' && n === '(') || (c === '>' && n === '(')) {
      const end = matchParen(text, i + 1);
      const body = text.slice(i + 2, end);
      if (c === '>') redirectingSubst = true;
      else subs.push(body);
      cur += ' __SUBST__ ';
      i = end + 1;
      continue;
    }
    if (c === '`') {
      const end = text.indexOf('`', i + 1);
      const stop = end === -1 ? text.length : end;
      subs.push(text.slice(i + 1, stop));
      cur += ' __SUBST__ ';
      i = stop + 1;
      continue;
    }
    if (c === '\n' || c === ';') { pushSeg(); i += 1; continue; }
    if (c === '|') { pushSeg(); i += (n === '|' || n === '&') ? 2 : 1; continue; }
    if (c === '&') {
      if (n === '&') { pushSeg(); i += 2; continue; }
      if (n === '>') { cur += c; i += 1; continue; } // &> redirection, handled later
      if (text[i - 1] === '>') { cur += c; i += 1; continue; } // >&n, n>&m: a descriptor, handled later
      pushSeg(); i += 1; continue; // background
    }
    cur += c;
    i += 1;
  }
  pushSeg();
  return { segs: segs.filter((s) => s.text.trim() !== ''), subs };
}

function matchParen(text, open) {
  let depth = 0;
  let q = null;
  for (let i = open; i < text.length; i += 1) {
    const c = text[i];
    if (q) { if (c === '\\') { i += 1; continue; } if (c === q) q = null; continue; }
    if (c === '\\') { i += 1; continue; }
    if (c === "'" || c === '"') { q = c; continue; }
    if (c === '(') depth += 1;
    if (c === ')') { depth -= 1; if (depth === 0) return i; }
  }
  return text.length;
}

// Words of one segment, quotes removed, plus whether it redirects output to a
// file (anything but /dev/null or a descriptor).
function words(segment) {
  const out = [];
  let cur = '';
  let have = false;
  let q = null;
  let writesFile = false;
  let i = 0;
  const flush = () => { if (have) out.push(cur); cur = ''; have = false; };
  const isDigits = (s) => /^[0-9]+$/.test(s);
  while (i < segment.length) {
    const c = segment[i];
    const n = segment[i + 1];
    if (q) {
      if (c === q) { q = null; i += 1; continue; }
      if (c === '\\' && q === '"' && n !== undefined) { cur += n; i += 2; continue; }
      cur += c; i += 1; continue;
    }
    if (c === '\\') { cur += n === undefined ? '' : n; have = true; i += 2; continue; }
    if (c === "'" || c === '"') { q = c; have = true; i += 1; continue; }
    if (c === '#' && !have) break;
    if (c === ' ' || c === '\t') { flush(); i += 1; continue; }
    if (c === '<' && n === '<') { // heredoc operator: skip it and its word
      i += 2;
      if (segment[i] === '<') i += 1;
      if (segment[i] === '-') i += 1;
      flush();
      while (segment[i] === ' ' || segment[i] === '\t') i += 1;
      while (i < segment.length && !/[ \t;|&<>]/.test(segment[i])) i += 1;
      continue;
    }
    if (c === '<' && n === '>') { writesFile = true; i += 2; continue; }
    if (c === '<') { // input redirection: skip operator and target word
      flush();
      i += 1;
      while (segment[i] === ' ' || segment[i] === '\t') i += 1;
      while (i < segment.length && !/[ \t;|&<>]/.test(segment[i])) i += 1;
      continue;
    }
    if (c === '>' || (c === '&' && n === '>')) {
      // Possible forms: >, >>, >|, &>, &>>, n> (n already in cur as digits), >&n, >&-
      let j = i;
      if (c === '&') j += 1; // &>
      j += 1; // the '>'
      if (segment[j] === '>' || segment[j] === '|') j += 1;
      let target = '';
      if (segment[j] === '&') {
        j += 1;
        while (j < segment.length && !/[ \t;|&<>]/.test(segment[j])) { target += segment[j]; j += 1; }
        // >&n or >&- : a descriptor, not a file
        if (!(isDigits(target) || target === '-')) writesFile = true;
        if (have && !isDigits(cur)) { /* cur is a word before the operator */ } else { cur = ''; have = false; }
        i = j;
        continue;
      }
      while (segment[j] === ' ' || segment[j] === '\t') j += 1;
      let tq = null;
      while (j < segment.length) {
        const d = segment[j];
        if (tq) { if (d === tq) tq = null; else target += d; j += 1; continue; }
        if (d === "'" || d === '"') { tq = d; j += 1; continue; }
        if (/[ \t;|&<>]/.test(d)) break;
        target += d; j += 1;
      }
      if (target !== '/dev/null') writesFile = true;
      if (have && isDigits(cur)) { cur = ''; have = false; } else flush();
      i = j;
      continue;
    }
    cur += c; have = true; i += 1;
  }
  flush();
  return { words: out, writesFile };
}

// ---------------------------------------------------------------------------
// Classification
// ---------------------------------------------------------------------------

const SYSTEM_PATH = /^(?:\/bin|\/sbin|\/usr\/bin|\/usr\/sbin|\/usr\/local\/bin|\/opt\/homebrew\/bin|\/opt\/local\/bin)\/([^/]+)$/;

// The command name to look up: a bare word, or the basename of a path that is
// exactly one name under a system directory. Any other path (./ls, ../tool,
// /tmp/git, a home directory, /usr/bin/../../tmp/ls, /usr/bin/./ls) is an
// arbitrary executable and returns '' so that nothing matches it.
function basename(word) {
  if (word.indexOf('/') === -1) return word;
  const m = SYSTEM_PATH.exec(word);
  if (!m || m[1] === '.' || m[1] === '..') return '';
  return m[1];
}

// Commands whose read-only status depends on their arguments: an argument
// that carries a parameter expansion or a substitution could become any option
// or subcommand once the shell expands it, so it makes the call a mutation.
// The wrappers apply the same rule to their own option, value, and assignment
// slots, where word splitting moves the command boundary (timeout $DUR ls).
const ARGUMENT_SENSITIVE = new Set(['git', 'find', 'sort', 'file', 'date', 'hostname', 'rg', 'ag', 'export']);

function hasExpansion(word) {
  return word.indexOf('$') !== -1 || word.indexOf('__SUBST__') !== -1;
}

// GNU getopt accepts any unambiguous prefix of a long option, so --out=f is
// --output=f: a word matches the option when its name (before any =) is at
// least three characters and a prefix of the full spelling.
function longOption(word, full) {
  const eq = word.indexOf('=');
  const name = eq === -1 ? word : word.slice(0, eq);
  return name.length >= 3 && name.startsWith('--') && full.startsWith(name);
}

function isAssignment(word) {
  return /^[A-Za-z_][A-Za-z0-9_]*=/.test(word);
}

function assignmentAllowed(word) {
  return ALLOWED_ASSIGNMENTS.has(word.slice(0, word.indexOf('=')));
}

// true when the simple command (a word list) is read-only.
function simpleReadOnly(ws) {
  let i = 0;
  while (i < ws.length && isAssignment(ws[i])) {
    if (!assignmentAllowed(ws[i])) return false;
    i += 1;
  }
  if (i >= ws.length) return true; // assignments only, all permitted
  const rest = ws.slice(i);
  const cmd = basename(rest[0]);
  // A substitution in command position runs its output as the command, and
  // that output is unknown here: always a mutation attempt.
  if (cmd === '__SUBST__') return false;
  if (WRAPPERS_MUTATING.has(cmd)) return false;
  if (cmd === 'env') return envReadOnly(rest.slice(1));
  if (cmd === 'command') {
    if (rest[1] === '-v' || rest[1] === '-V') return true;
    return simpleReadOnly(rest.slice(rest[1] === '-p' ? 2 : 1));
  }
  if (cmd === 'nice') {
    let j = 1;
    while (j < rest.length && rest[j].startsWith('-')) { if (rest[j] === '-n') j += 1; j += 1; }
    if (rest.slice(1, j).some(hasExpansion)) return false;
    return simpleReadOnly(rest.slice(j));
  }
  if (cmd === 'nohup') return simpleReadOnly(rest.slice(1));
  if (cmd === 'time') return simpleReadOnly(rest.slice(rest[1] === '-p' ? 2 : 1));
  if (cmd === 'timeout') {
    let j = 1;
    while (j < rest.length && rest[j].startsWith('-')) { if (rest[j] === '-k' || rest[j] === '-s') j += 1; j += 1; }
    if (rest.slice(1, j + 1).some(hasExpansion)) return false; // j is the duration
    return simpleReadOnly(rest.slice(j + 1));
  }
  if (!ALLOW.has(cmd)) return false;
  const args = rest.slice(1);
  if (ARGUMENT_SENSITIVE.has(cmd) && args.some(hasExpansion)) return false;
  if (cmd === 'export') return args.every((a) => a === '-p' || a === '-n' || ALLOWED_ASSIGNMENTS.has(a) || (isAssignment(a) && assignmentAllowed(a)));
  if (cmd === 'rg') return !args.some((a) => longOption(a, '--pre'));
  if (cmd === 'ag') return !args.some((a) => longOption(a, '--pager'));
  if (cmd === 'find') return !args.some((a) => FIND_MUTATING.has(a));
  if (cmd === 'sort') return !args.some((a) => longOption(a, '--output') || longOption(a, '--compress-program') || /^-[a-zA-Z]*o/.test(a));
  if (cmd === 'file') return !args.some((a) => longOption(a, '--compile') || /^-[a-zA-Z]*C/.test(a));
  if (cmd === 'date') return !args.some((a) => longOption(a, '--set') || /^-[a-zA-Z]*s/.test(a));
  if (cmd === 'hostname') return args.every((a) => a.startsWith('-'));
  if (cmd === 'git') return gitReadOnly(args);
  return true;
}

// env accepts its permitted assignments and these options only; -S and
// --split-string run a command line of their own, and anything unknown is a
// mutation.
function envReadOnly(args) {
  let j = 0;
  while (j < args.length) {
    const a = args[j];
    if (!isAssignment(a) && !a.startsWith('-')) break; // the wrapped command
    if (hasExpansion(a)) return false;
    if (isAssignment(a)) { if (!assignmentAllowed(a)) return false; j += 1; continue; }
    if (a === '-u' || a === '--unset' || a === '-C' || a === '--chdir') {
      if (j + 1 < args.length && hasExpansion(args[j + 1])) return false;
      j += 2;
      continue;
    }
    if (a === '-i' || a === '--ignore-environment' || a === '-0' || a === '--null') { j += 1; continue; }
    return false;
  }
  return simpleReadOnly(args.slice(j));
}

function gitReadOnly(args) {
  let j = 0;
  while (j < args.length && args[j].startsWith('-')) {
    const a = args[j];
    if (a === '-c' || a.startsWith('-c')) return false; // a config override can name a command
    if (GIT_GLOBAL_SKIP_WITH_VALUE.has(a)) { j += 2; continue; }
    if (GIT_GLOBAL_SKIP.has(a) || a.startsWith('--git-dir=') || a.startsWith('--work-tree=')) { j += 1; continue; }
    return false;
  }
  if (j >= args.length) return true; // bare "git" prints usage
  const sub = args[j];
  const rest = args.slice(j + 1);
  if (rest.some((a) => GIT_HELPER_OPTIONS.has(a.indexOf('=') === -1 ? a : a.slice(0, a.indexOf('='))) || /^-O./.test(a))) return false;
  if (GIT_READONLY.has(sub)) return true;
  if (sub === 'config') return rest.length > 0 && GIT_CONFIG_READONLY.has(rest[0]);
  if (sub === 'stash') return rest[0] === 'list' || rest[0] === 'show';
  if (sub === 'worktree') return rest[0] === 'list';
  if (sub === 'remote') return rest.every((a) => a === '-v' || a === '--verbose');
  if (sub === 'branch') return listingOnly(rest, GIT_BRANCH_FLAGS, GIT_BRANCH_VALUED, new Set(['-l', '--list']));
  if (sub === 'tag') return listingOnly(rest, GIT_TAG_FLAGS, GIT_TAG_VALUED, new Set(['-l', '--list']));
  return false;
}

// Options only from `flags` (a joined =value is allowed on a flag, as in
// --color=always) or `valued` (which consume a value given as --opt=value or
// --opt value); positional arguments only after a listing flag.
function listingOnly(rest, flags, valued, listFlags) {
  let listing = false;
  let j = 0;
  while (j < rest.length) {
    const a = rest[j];
    if (a.startsWith('-')) {
      const eq = a.indexOf('=');
      const name = eq === -1 ? a : a.slice(0, eq);
      if (listFlags.has(name)) listing = true;
      if (/^-n[0-9]*$/.test(a) && flags.has('-n')) { j += 1; continue; }
      if (valued.has(name)) { j += eq === -1 ? 2 : 1; continue; }
      if (flags.has(name)) { j += 1; continue; }
      return false;
    }
    if (!listing) return false; // a positional outside a listing mode
    j += 1;
  }
  return true;
}

// true when the whole Bash command string is read-only.
function commandReadOnly(text) {
  const stripped = stripHeredocs(String(text));
  const { segs, subs } = segments(stripped.text);
  for (const body of stripped.subs.concat(subs)) {
    if (!commandReadOnly(body)) return false;
  }
  for (const seg of segs) {
    if (seg.redirectingSubst) return false;
    const w = words(seg.text);
    if (w.writesFile) return false;
    if (w.words.length === 0) continue;
    if (!simpleReadOnly(w.words)) return false;
  }
  return true;
}

// "attempt" or "read-only" for one tool call.
function classify(toolName, toolInput) {
  if (MUTATING_TOOLS.has(toolName)) return 'attempt';
  if (toolName === 'Bash') {
    const cmd = toolInput && typeof toolInput.command === 'string' ? toolInput.command : '';
    return commandReadOnly(cmd) ? 'read-only' : 'attempt';
  }
  return 'read-only';
}

// ---------------------------------------------------------------------------
// Transcript
// ---------------------------------------------------------------------------

function lastAssistantId(transcriptPath) {
  let fd;
  try {
    fd = fs.openSync(transcriptPath, 'r');
    const size = fs.fstatSync(fd).size;
    const span = Math.min(size, 65536);
    const buf = Buffer.alloc(span);
    fs.readSync(fd, buf, 0, span, size - span);
    const lines = buf.toString('utf8').split('\n');
    for (let i = lines.length - 1; i >= 0; i -= 1) {
      const line = lines[i].trim();
      if (!line) continue;
      let rec;
      try { rec = JSON.parse(line); } catch (e) { continue; }
      if (rec && rec.type === 'assistant') {
        const m = rec.message && typeof rec.message === 'object' ? rec.message : {};
        const id = [m.id, rec.requestId, rec.uuid].find((v) => typeof v === 'string' && v !== '');
        return id || 'unknown';
      }
    }
    return 'unknown';
  } catch (e) {
    return 'unknown';
  } finally {
    if (fd !== undefined) { try { fs.closeSync(fd); } catch (e) { /* nothing to do */ } }
  }
}

// ---------------------------------------------------------------------------
// Modes
// ---------------------------------------------------------------------------

function readStdin() {
  try { return fs.readFileSync(0, 'utf8'); } catch (e) { return ''; }
}

function modeHook() {
  let payload;
  try { payload = JSON.parse(readStdin()); } catch (e) { process.stdout.write('skip\t\t\n'); return 0; }
  if (!payload || typeof payload !== 'object') { process.stdout.write('skip\t\t\n'); return 0; }
  const sid = typeof payload.session_id === 'string' ? payload.session_id : '';
  const tp = typeof payload.transcript_path === 'string' ? payload.transcript_path : '';
  const decision = sid && tp ? classify(payload.tool_name, payload.tool_input) : 'read-only';
  const clean = (s) => s.replace(/[\t\n\r]/g, '');
  process.stdout.write((decision === 'attempt' ? 'attempt' : 'skip') + '\t' + clean(sid) + '\t' + clean(tp) + '\n');
  return 0;
}

function modeWave(path) {
  process.stdout.write(lastAssistantId(path) + '\n');
  return 0;
}

function modePublish(tmp, marker) {
  try {
    fs.renameSync(tmp, marker);
    return 0;
  } catch (e) {
    return e && (e.code === 'ENOTEMPTY' || e.code === 'EEXIST') ? 3 : 1;
  }
}

function modeBatch() {
  let items;
  try { items = JSON.parse(readStdin()); } catch (e) { process.stderr.write('batch: stdin is not JSON\n'); return 2; }
  if (!Array.isArray(items)) { process.stderr.write('batch: expected a JSON array\n'); return 2; }
  const out = items.map((it) => {
    if (typeof it === 'string') return classify('Bash', { command: it });
    return classify(it && it.tool_name, it && it.tool_input);
  });
  process.stdout.write(out.join('\n') + (out.length ? '\n' : ''));
  return 0;
}

function modeVectors(path) {
  const lines = fs.readFileSync(path, 'utf8').split('\n');
  let n = 0;
  let bad = 0;
  for (const raw of lines) {
    if (!raw.trim() || raw.startsWith('#')) continue;
    const tab = raw.lastIndexOf('\t');
    if (tab === -1) { process.stdout.write('malformed vector: ' + raw + '\n'); bad += 1; continue; }
    const command = raw.slice(0, tab).replace(/\\n/g, '\n');
    const expected = raw.slice(tab + 1).trim();
    const got = commandReadOnly(command) ? 'read-only' : 'mutation';
    n += 1;
    if (got !== expected) { process.stdout.write('mismatch: ' + JSON.stringify(command) + ' expected ' + expected + ' got ' + got + '\n'); bad += 1; }
  }
  if (bad === 0) process.stdout.write('ok ' + n + '\n');
  return bad === 0 ? 0 : 1;
}

function main(argv) {
  const mode = argv[0];
  if (mode === '--hook') return modeHook();
  if (mode === '--wave' && argv[1]) return modeWave(argv[1]);
  if (mode === '--publish' && argv[1] && argv[2]) return modePublish(argv[1], argv[2]);
  if (mode === '--batch') return modeBatch();
  if (mode === '--vectors' && argv[1]) return modeVectors(argv[1]);
  process.stderr.write('usage: interlock-lib.cjs --hook | --wave <transcript> | --publish <tmp> <marker> | --batch | --vectors <tsv>\n');
  return 2;
}

if (require.main === module) process.exit(main(process.argv.slice(2)));

module.exports = { classify, commandReadOnly, lastAssistantId };
