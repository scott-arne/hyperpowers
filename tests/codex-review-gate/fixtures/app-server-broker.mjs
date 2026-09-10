#!/usr/bin/env node
// Test double for codex-plugin-cc's app-server-broker.mjs. It has the same
// process shape the sweep looks for — `app-server-broker.mjs serve --endpoint
// unix:<socket>` — listens on that socket, answers `broker/shutdown` with a
// JSON-RPC result, and exits. With --pid-file it records its own pid there.
// Nothing else of the real broker is modeled.
import fs from "node:fs";
import net from "node:net";
import process from "node:process";
const argv = process.argv.slice(2);
const i = argv.indexOf("--endpoint");
const endpoint = i >= 0 ? argv[i + 1] : "";
if (argv[0] !== "serve" || !endpoint.startsWith("unix:")) {
  process.stderr.write("usage: app-server-broker.mjs serve --endpoint unix:<path>\n");
  process.exit(2);
}
const sock = endpoint.slice("unix:".length);
// The test needs this process's own pid, not the pid of whatever shell
// backgrounded it: `$!` on a compound command names the intermediate subshell.
const pf = argv.indexOf("--pid-file");
if (pf >= 0 && argv[pf + 1]) fs.writeFileSync(argv[pf + 1], `${process.pid}\n`);
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
        c.end(`${JSON.stringify({ id: msg.id ?? 1, result: {} })}\n`);
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
