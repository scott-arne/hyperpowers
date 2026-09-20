#!/usr/bin/env node
// Node side of the first-edit interlock (hooks/first-edit-interlock calls it;
// a .cjs file because the plugin's package.json declares "type": "module";
// the evals analyzer calls the same file from the pinned plugin commit).
//
// Modes:
//   --hook              stdin: the PreToolUse payload. stdout: one line of five
//                       tab-separated fields,
//                       "<decision>\t<session_id>\t<context>\t<transcript>\t<call>"
//                       where decision is "attempt" (a mutation attempt) or
//                       "skip". <context> names the calling agent context and
//                       <transcript> is that context's own transcript; see
//                       contextOf() for why neither comes from transcript_path
//                       alone. <call> is the payload's own tool_use_id, empty
//                       when it carries none. A "skip" line is the word
//                       followed by four empty fields.
//   --resolve <transcript> <tool-use-id> [<poll-ms>]
//                       find the assistant record carrying a tool_use block
//                       with that id, reading the whole file backwards, and
//                       print one line: "id<TAB><turn identifier>" when that
//                       record carries message.id or requestId, "noid" when it
//                       carries neither, "absent" when no such record is in the
//                       file, "unreadable" when the file cannot be read. Polls
//                       every 50 ms for up to 400 ms while the answer is
//                       "absent"; the other three answers return at once. The
//                       optional poll-ms budget replaces the 400; the hook never
//                       passes it, and a budget of 0 makes the lookup a single
//                       non-polling read. That exists for the live probe, which
//                       has to ask whether a record was on disk at a moment
//                       rather than wait for it to arrive; a negative or
//                       non-numeric budget falls back to the 400.
//
// Probe trace. When INTERLOCK_PROBE_TRACE names a file, --resolve and --last
// append one tab-separated line to it describing the reads they just did:
//   resolve<TAB><id><TAB>reads=<n><TAB>first=<f><TAB>result=<r>
//   last<TAB>result=<id|none|unreadable>
// where <f> and <r> are present, absent, noid or unreadable. Nothing in
// production sets the variable, so the cost there is one environment lookup
// per process and no output of any kind. The live probe sets it, and this is
// the only faithful way it can learn what the hook's own reads saw: a second
// reader running alongside the hook answers for its own moment rather than
// the hook's, and running one before the hook delays the read it is measuring.
// The line is appended after the reads it reports, so it cannot change them.
//   --delivered <transcript> <tool-use-id>
//                       exit 0 when the transcript holds a tool_result whose
//                       tool_use_id is that id AND whose content contains the
//                       interlock message's opening sentence, 3 when it holds
//                       no such result, 1 when the file cannot be read. Both
//                       halves are required: the message is the hook's own
//                       text, and any cat or rg of this repository prints it.
//   --last <transcript> print "id<TAB><turn identifier>" for the last assistant
//                       record that carries one, skipping trailing records that
//                       carry neither, or "none", or "unreadable".
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
const path = require('path');

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
  'shortlog', 'show-ref', 'for-each-ref', 'check-ignore', 'check-attr',
  'diff-tree', 'diff-index', 'diff-files', 'count-objects', 'var', 'cherry',
  'range-diff', 'annotate', 'show-branch', 'whatchanged', 'version',
]);
// Global flags that print and exit before any subcommand runs.
const GIT_BARE_FLAGS = new Set(['--version', '--help', '--html-path', '--man-path', '--info-path']);
// config reads when one of these is present and none of the write actions is;
// git refuses two actions in one call.
const GIT_CONFIG_READONLY = new Set(['--get', '--get-all', '--get-regexp', '--list', '-l']);
const GIT_CONFIG_WRITE = new Set(['--unset', '--unset-all', '--add', '--replace-all', '--rename-section', '--remove-section', '--edit', '-e']);
// hostname prints with these; -F, --file, -b, and a positional set the name.
const HOSTNAME_DISPLAY = new Set([
  '-f', '--fqdn', '--long', '-s', '--short', '-d', '--domain', '-i', '--ip-address',
  '-I', '--all-ip-addresses', '-a', '--alias', '-A', '--all-fqdns', '-y', '--yp', '--nis',
]);
// Variables the shell or git consults for what to execute: read may not fill
// them, unset may not clear them, and printf -v may not assign at all.
const SHELL_SENSITIVE_NAME = /^(?:PATH|IFS|CDPATH|ENV|BASH_ENV|SHELLOPTS|BASHOPTS|PROMPT_COMMAND|PS4|GLOBIGNORE|EXECIGNORE|HOME|TMPDIR|GIT_.*|LD_.*|DYLD_.*|BASH_.*)$/;
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
// A backtick body ends at the first backtick not escaped by a backslash. Bash
// removes the backslash before $, a backtick, and a backslash inside the body,
// so a nested \` opens an inner substitution that classifying the body finds.
function backtickBody(text, open) {
  let body = '';
  let i = open;
  while (i < text.length) {
    const c = text[i];
    if (c === '\\' && i + 1 < text.length) {
      const n = text[i + 1];
      body += (n === '$' || n === '`' || n === '\\') ? n : c + n;
      i += 2;
      continue;
    }
    if (c === '`') return { body, end: i };
    body += c;
    i += 1;
  }
  return { body, end: text.length };
}

// A word carrying an unquoted pathname or brace pattern is marked: after
// expansion it can be any number of any words, so the argument rules treat it
// as an expansion. The standalone [ is the test builtin.
const GLOB_MARK = '__GLOB__';
const GLOB_CHARS = '*?[{}()';

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
      const bt = backtickBody(line, i + 1);
      subs.push(bt.body);
      i = bt.end + 1;
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
        const bt = backtickBody(text, i + 1);
        subs.push(bt.body);
        cur += ' __SUBST__ ';
        i = bt.end + 1;
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
      const bt = backtickBody(text, i + 1);
      subs.push(bt.body);
      cur += ' __SUBST__ ';
      i = bt.end + 1;
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
  let glob = false;
  let i = 0;
  const flush = () => {
    if (have) out.push(glob && cur !== '[' ? GLOB_MARK + cur : cur);
    cur = ''; have = false; glob = false;
  };
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
    if (GLOB_CHARS.indexOf(c) !== -1) glob = true;
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
const ARGUMENT_SENSITIVE = new Set(['git', 'find', 'sort', 'file', 'date', 'hostname', 'rg', 'ag', 'export', 'uniq', 'read', 'unset']);

function hasExpansion(word) {
  return word.indexOf('$') !== -1 || word.indexOf('__SUBST__') !== -1 || word.indexOf(GLOB_MARK) !== -1;
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
  if (cmd === 'date') {
    // BSD date sets the clock from a positional operand or -f; a format starts with +.
    for (let j = 0; j < args.length; j += 1) {
      const a = args[j];
      if (longOption(a, '--set')) return false;
      if (/^-I/.test(a)) continue;
      if (/^-[a-zA-Z]*[sf]/.test(a)) return false;
      if (a === '-r' || a === '-d' || a === '-v' || a === '--date' || a === '--reference') { j += 1; continue; }
      if (a.startsWith('-') || a.startsWith('+')) continue;
      return false;
    }
    return true;
  }
  if (cmd === 'hostname') return args.every((a) => HOSTNAME_DISPLAY.has(a));
  if (cmd === 'uniq') {
    // A second operand is uniq's output file.
    let operands = 0;
    for (let j = 0; j < args.length; j += 1) {
      const a = args[j];
      if (a === '-f' || a === '-s' || a === '-w') { j += 1; continue; }
      if (a === '-' || !a.startsWith('-')) operands += 1; // - is standard input
    }
    return operands <= 1;
  }
  if (cmd === 'printf') {
    // Options end at the format word, so only a leading word can become -v.
    for (let j = 0; j < args.length; j += 1) {
      const a = args[j];
      if (a === '--') return true;
      if (/^-v/.test(a) || hasExpansion(a)) return false;
      if (!a.startsWith('-')) return true;
    }
    return true;
  }
  if (cmd === 'read' || cmd === 'unset') return !args.some((a) => !a.startsWith('-') && SHELL_SENSITIVE_NAME.test(a));
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
    if (GIT_BARE_FLAGS.has(a)) return true;
    if (GIT_GLOBAL_SKIP_WITH_VALUE.has(a)) { j += 2; continue; }
    if (GIT_GLOBAL_SKIP.has(a) || a.startsWith('--git-dir=') || a.startsWith('--work-tree=')) { j += 1; continue; }
    return false;
  }
  if (j >= args.length) return true; // bare "git" prints usage
  const sub = args[j];
  const rest = args.slice(j + 1);
  if (rest.some((a) => GIT_HELPER_OPTIONS.has(a.indexOf('=') === -1 ? a : a.slice(0, a.indexOf('='))) || /^-O./.test(a))) return false;
  if (GIT_READONLY.has(sub)) return true;
  if (sub === 'config') return rest.some((a) => GIT_CONFIG_READONLY.has(a)) && !rest.some((a) => GIT_CONFIG_WRITE.has(a));
  if (sub === 'reflog') return rest.length === 0 || rest[0] === 'show' || rest[0].startsWith('-');
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

// Every read below is a whole-file read. A fixed tail window was the first
// draft and it was wrong: treating anything outside the last megabyte as "many
// turns ago" holds only if one turn cannot fill the window, and nothing bounds
// a turn's size. Several parallel Write calls with large contents, or one
// oversized record, evict the denied call from a tail read while its own turn
// is still current -- the leak this rule exists to close. The cost is what the
// file costs, and these files are small: the 2026-09-20 campaign's 1309 context
// transcripts run to a median of 208 KB and a maximum of 1.24 MB, with no
// single record above 105 KB.
const POLL_INTERVAL_MS = 50;
const POLL_BUDGET_MS = 400;

function sleepSync(ms) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

function readRecords(transcriptPath) {
  let text;
  try { text = fs.readFileSync(transcriptPath, 'utf8'); } catch (e) { return null; }
  const out = [];
  const lines = text.split('\n');
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i].trim();
    if (!line) continue;
    // A record still being flushed is skipped, not fatal: the poll comes round
    // again and the whole line is there the next time.
    try { out.push(JSON.parse(line)); } catch (e) { /* partially written */ }
  }
  return out;
}

// message.id, falling back to requestId, and never the record's uuid. Both of
// the first two are one value per assistant turn -- the 2026-09-19 probe's
// subagent transcript holds fifteen assistant records carrying six of each --
// while uuid is one per content block, fifteen distinct values across those
// same fifteen records. A uuid identifier would give each block of a turn its
// own identity, so a sibling of the denied call would read as a later turn and
// be allowed: the one failure the rule exists to prevent. Empty string means
// the record names no turn at all.
function turnIdOf(rec) {
  const m = rec && rec.message && typeof rec.message === 'object' ? rec.message : {};
  const id = [m.id, rec && rec.requestId].find((v) => typeof v === 'string' && v !== '');
  return id || '';
}

function contentBlocks(rec) {
  const c = rec && rec.message && typeof rec.message === 'object' ? rec.message.content : null;
  return Array.isArray(c) ? c : [];
}

// The assistant record carrying a tool_use block with this id. Backwards,
// because the id a caller asks about is nearly always recent.
function findCallRecord(records, id) {
  for (let i = records.length - 1; i >= 0; i -= 1) {
    const rec = records[i];
    if (!rec || rec.type !== 'assistant') continue;
    const blocks = contentBlocks(rec);
    for (let j = 0; j < blocks.length; j += 1) {
      const b = blocks[j];
      if (b && b.type === 'tool_use' && b.id === id) return rec;
    }
  }
  return null;
}

// The interlock message's opening sentence. The 2026-09-20 probe found this
// substring in exactly one tool_result per denied context.
const DENIAL_OPENING = 'Interlock, once before your first edit:';

function resultText(block) {
  const c = block && block.content;
  if (typeof c === 'string') return c;
  if (!Array.isArray(c)) return '';
  let out = '';
  for (let i = 0; i < c.length; i += 1) {
    const part = c[i];
    if (typeof part === 'string') out += part;
    else if (part && typeof part.text === 'string') out += part.text;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Modes
// ---------------------------------------------------------------------------

function readStdin() {
  try { return fs.readFileSync(0, 'utf8'); } catch (e) { return ''; }
}

const SAFE_NAME = /^[A-Za-z0-9._-]+$/;

// Name the agent context a payload came from, and find that context's own
// transcript.
//
// A subagent's tool call does not carry the subagent's transcript_path: Claude
// Code puts the controller's path in every payload, whoever made the call
// (measured 2026-09-19 on 2.1.276, evidence/2026-09-17-first-edit-interlock/
// probe/). agent_id is the only field that tells one context from another, and
// keying on transcript_path alone collapsed a controller and both its
// subagents into one interlock -- trapping the first subagent and never gating
// the second. So agent_id, when present, supplies both the marker's name and
// the transcript every wave read uses; Claude Code lays a subagent's transcript
// out beside its controller's as <dir>/<stem>/subagents/agent-<id>.jsonl.
function contextOf(transcriptPath, agentId) {
  const stem = path.basename(transcriptPath).replace(/\.[^.]*$/, '');
  if (!agentId) return { name: stem, transcript: transcriptPath };
  const name = 'agent-' + agentId;
  return {
    name: name,
    transcript: path.join(path.dirname(transcriptPath), stem, 'subagents', name + '.jsonl'),
  };
}

function modeHook() {
  const skip = () => { process.stdout.write('skip\t\t\t\t\n'); return 0; };
  let payload;
  try { payload = JSON.parse(readStdin()); } catch (e) { return skip(); }
  if (!payload || typeof payload !== 'object') return skip();
  const sid = typeof payload.session_id === 'string' ? payload.session_id : '';
  const tp = typeof payload.transcript_path === 'string' ? payload.transcript_path : '';
  if (!sid || !tp) return skip();
  const agentId = typeof payload.agent_id === 'string' ? payload.agent_id : '';
  // Rejected here rather than downstream: a stripped separator would otherwise
  // turn an unusable agent_id into a name that keys some other context's marker.
  if (agentId && !SAFE_NAME.test(agentId)) return skip();
  if (classify(payload.tool_name, payload.tool_input) !== 'attempt') return skip();
  const ctx = contextOf(tp, agentId);
  // The payload's own tool_use_id is the one value the hook can trust about
  // this call: it arrives in the payload, so reading it races nothing. The
  // marker stores it, and both lookups below are keyed on it.
  const callId = typeof payload.tool_use_id === 'string' ? payload.tool_use_id : '';
  const clean = (s) => s.replace(/[\t\n\r]/g, '');
  process.stdout.write('attempt\t' + clean(sid) + '\t' + clean(ctx.name) + '\t' + clean(ctx.transcript) + '\t' + clean(callId) + '\n');
  return 0;
}

// Step 6 and step 7 both call this: step 6 with the denied call's id to resolve
// the wave, step 7 with this call's own id to resolve its turn. The poll is for
// the concurrent first wave -- the caller that lost the rename is a sibling of
// the winner, dispatched in the same turn, and the winner's record may still be
// in flight. Only "absent" polls; the other answers are final on the first read.
// The probe trace (see the header). Inert unless INTERLOCK_PROBE_TRACE names a
// file; a trace that cannot be written is the probe's problem, never the
// hook's, so the append swallows its own failure.
const PROBE_TRACE = process.env.INTERLOCK_PROBE_TRACE || '';
function trace(line) {
  if (!PROBE_TRACE) return;
  try { fs.appendFileSync(PROBE_TRACE, line + '\n'); } catch (e) { /* not the hook's business */ }
}

function modeResolve(transcriptPath, id, budgetArg) {
  const asked = budgetArg === undefined ? POLL_BUDGET_MS : Number(budgetArg);
  const budget = Number.isFinite(asked) && asked >= 0 ? asked : POLL_BUDGET_MS;
  const deadline = Date.now() + budget;
  // `first` is what the very first read saw. That, and not the final answer,
  // is the population step 7's poll exists for: a record the hook found only
  // after polling was not on disk when the hook reached this step.
  let reads = 0;
  let first = '';
  for (;;) {
    const records = readRecords(transcriptPath);
    reads += 1;
    if (records === null) {
      if (!first) first = 'unreadable';
      trace('resolve\t' + id + '\treads=' + reads + '\tfirst=' + first + '\tresult=unreadable');
      process.stdout.write('unreadable\n');
      return 0;
    }
    const rec = findCallRecord(records, id);
    if (rec) {
      const turn = turnIdOf(rec);
      const answer = turn ? 'present' : 'noid';
      if (!first) first = answer;
      trace('resolve\t' + id + '\treads=' + reads + '\tfirst=' + first + '\tresult=' + answer);
      process.stdout.write(turn ? 'id\t' + turn + '\n' : 'noid\n');
      return 0;
    }
    if (!first) first = 'absent';
    if (Date.now() >= deadline) {
      trace('resolve\t' + id + '\treads=' + reads + '\tfirst=' + first + '\tresult=absent');
      process.stdout.write('absent\n');
      return 0;
    }
    sleepSync(POLL_INTERVAL_MS);
  }
}

// A denial demonstrably delivered, bound to the call that is holding this
// context. Both halves matter. The id proves the result belongs to the denied
// call; an unbound text search would release a sibling on the output of any cat
// or rg that happens to print the hook's own message, and the read-only
// allowlist above lets both run.
function modeDelivered(transcriptPath, id) {
  const records = readRecords(transcriptPath);
  if (records === null) return 1;
  for (let i = records.length - 1; i >= 0; i -= 1) {
    const blocks = contentBlocks(records[i]);
    for (let j = 0; j < blocks.length; j += 1) {
      const b = blocks[j];
      if (b && b.type === 'tool_result' && b.tool_use_id === id
          && resultText(b).indexOf(DENIAL_OPENING) !== -1) return 0;
    }
  }
  return 3;
}

// Step 8's fallback. Trailing records that name no turn are skipped rather than
// stopped on: such a record can neither match the wave nor witness a later
// turn, so reading it as a different turn would release the same-turn sibling
// the wave rule exists to stop. The scan terminates on a real value whenever a
// wave was resolved, because the denied call's own record is then in the file
// and carries an identifier.
function modeLast(transcriptPath) {
  const records = readRecords(transcriptPath);
  if (records === null) {
    trace('last\tresult=unreadable');
    process.stdout.write('unreadable\n');
    return 0;
  }
  for (let i = records.length - 1; i >= 0; i -= 1) {
    const rec = records[i];
    if (!rec || rec.type !== 'assistant') continue;
    const turn = turnIdOf(rec);
    if (turn) {
      // The hook calls --last at step 8 and nowhere else, so a trace holding a
      // last line is exactly a call that fell through the step-7 poll.
      trace('last\tresult=id');
      process.stdout.write('id\t' + turn + '\n');
      return 0;
    }
  }
  trace('last\tresult=none');
  process.stdout.write('none\n');
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
  if (mode === '--resolve' && argv[1] && argv[2]) return modeResolve(argv[1], argv[2], argv[3]);
  if (mode === '--delivered' && argv[1] && argv[2]) return modeDelivered(argv[1], argv[2]);
  if (mode === '--last' && argv[1]) return modeLast(argv[1]);
  if (mode === '--publish' && argv[1] && argv[2]) return modePublish(argv[1], argv[2]);
  if (mode === '--batch') return modeBatch();
  if (mode === '--vectors' && argv[1]) return modeVectors(argv[1]);
  process.stderr.write('usage: interlock-lib.cjs --hook | --resolve <transcript> <id> [<poll-ms>] | --delivered <transcript> <id> | --last <transcript> | --publish <tmp> <marker> | --batch | --vectors <tsv>\n');
  return 2;
}

if (require.main === module) process.exit(main(process.argv.slice(2)));

module.exports = { classify, commandReadOnly, contextOf, findCallRecord, readRecords, turnIdOf };
