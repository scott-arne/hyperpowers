#!/usr/bin/env node
// Test double for codex-plugin-cc's app-server-broker.mjs. It has the same
// process shape the sweep looks for — `app-server-broker.mjs serve --endpoint
// unix:<socket>` — listens on that socket, answers `broker/shutdown` with a
// JSON-RPC result, and exits.
//
// Flags the real broker does not have, so tests can observe what the sweep did:
//   --pid-file PATH        record this process's own pid
//   --shutdown-marker PATH create this file when broker/shutdown arrives, so a
//                          test can prove the protocol ran rather than inferring
//                          it from the process being gone
//   --ignore-shutdown      accept broker/shutdown and keep running (a wedged
//                          broker), which is what makes the signal fallback
//                          observable
// Nothing else of the real broker is modeled.
import fs from "node:fs";
import net from "node:net";
import process from "node:process";
const argv = process.argv.slice(2);
const flag = (name) => { const i = argv.indexOf(name); return i >= 0 ? argv[i + 1] : null; };
const endpoint = flag("--endpoint") ?? "";
if (argv[0] !== "serve" || !endpoint.startsWith("unix:")) {
  process.stderr.write("usage: app-server-broker.mjs serve --endpoint unix:<path>\n");
  process.exit(2);
}
const sock = endpoint.slice("unix:".length);
// The test needs this process's own pid, not the pid of whatever shell
// backgrounded it: `$!` on a compound command names the intermediate subshell.
const pidFile = flag("--pid-file");
if (pidFile) fs.writeFileSync(pidFile, `${process.pid}\n`);
const marker = flag("--shutdown-marker");
const ignoreShutdown = argv.includes("--ignore-shutdown");
try { fs.unlinkSync(sock); } catch {}
const server = net.createServer((c) => {
  c.setEncoding("utf8");
  let buf = "";
  c.on("data", (d) => {
    buf += d;
    let nl;
    while ((nl = buf.indexOf("\n")) >= 0) {
      const line = buf.slice(0, nl); buf = buf.slice(nl + 1);
      let msg = null;
      try { msg = JSON.parse(line); } catch { continue; }
      if (msg && msg.method === "broker/shutdown") {
        if (marker) { try { fs.writeFileSync(marker, `${Date.now()}\n`); } catch {} }
        c.end(`${JSON.stringify({ id: msg.id ?? 1, result: {} })}\n`);
        if (ignoreShutdown) continue;
        server.close(() => process.exit(0));
        setTimeout(() => process.exit(0), 200).unref();
      } else {
        c.write(`${JSON.stringify({ id: msg && msg.id, result: { ok: true } })}\n`);
      }
    }
  });
});
server.listen(sock, () => { process.stdout.write("listening\n"); });
process.on("SIGTERM", () => {}); // the real broker survives a bare SIGTERM too
