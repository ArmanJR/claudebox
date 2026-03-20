const http = require("http");
const { spawn } = require("child_process");

const PORT = parseInt(process.env.PORT || "3000", 10);
const MAX_CONCURRENT = parseInt(process.env.MAX_CONCURRENT || "4", 10);

let activeRequests = 0;

function log(level, msg, meta = {}) {
  const entry = { ts: new Date().toISOString(), level, msg, ...meta };
  process.stderr.write(JSON.stringify(entry) + "\n");
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (chunk) => (data += chunk));
    req.on("end", () => resolve(data));
    req.on("error", reject);
  });
}

function runClaude(prompt, options = {}) {
  return new Promise((resolve, reject) => {
    const args = [
      "-p",
      "--output-format",
      "json",
      "--dangerously-skip-permissions",
      "--no-session-persistence",
    ];

    if (options.model) args.push("--model", options.model);
    if (options.maxTurns) args.push("--max-turns", String(options.maxTurns));
    if (options.maxBudgetUsd)
      args.push("--max-budget-usd", String(options.maxBudgetUsd));
    if (options.systemPrompt)
      args.push("--system-prompt", options.systemPrompt);
    if (options.appendSystemPrompt)
      args.push("--append-system-prompt", options.appendSystemPrompt);
    if (options.allowedTools)
      args.push("--allowedTools", ...options.allowedTools);

    args.push(prompt);

    log("info", "spawning claude", { prompt: prompt.slice(0, 100) });

    const proc = spawn("claude", args, {
      stdio: ["inherit", "pipe", "pipe"],
      cwd: options.cwd || "/workspace",
    });

    let stdout = "";
    let stderr = "";
    proc.stdout.on("data", (d) => (stdout += d));
    proc.stderr.on("data", (d) => (stderr += d));

    proc.on("error", (err) => reject(err));
    proc.on("close", (code) => {
      if (code !== 0) {
        log("error", "claude exited with error", { code, stderr });
        reject(new Error(stderr || `claude exited with code ${code}`));
      } else {
        resolve(stdout);
      }
    });
  });
}

function sendJSON(res, status, body) {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
}

const server = http.createServer(async (req, res) => {
  if (req.method === "GET" && req.url === "/health") {
    sendJSON(res, 200, { status: "ok", activeRequests });
    return;
  }

  if (req.method === "POST" && req.url === "/prompt") {
    if (activeRequests >= MAX_CONCURRENT) {
      log("warn", "rejected request, at capacity", { activeRequests });
      sendJSON(res, 429, { error: "Too many concurrent requests" });
      return;
    }

    activeRequests++;
    try {
      const raw = await readBody(req);
      let body;
      try {
        body = JSON.parse(raw);
      } catch {
        sendJSON(res, 400, { error: "Invalid JSON body" });
        return;
      }

      if (!body.prompt) {
        sendJSON(res, 400, { error: "Missing 'prompt' field" });
        return;
      }

      const result = await runClaude(body.prompt, body.options || {});
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(result);
    } catch (err) {
      sendJSON(res, 500, { error: err.message });
    } finally {
      activeRequests--;
    }
    return;
  }

  sendJSON(res, 404, { error: "Not found. Use POST /prompt or GET /health" });
});

server.listen(PORT, "0.0.0.0", () => {
  log("info", `claudebox server listening on port ${PORT}`, {
    maxConcurrent: MAX_CONCURRENT,
  });
});
