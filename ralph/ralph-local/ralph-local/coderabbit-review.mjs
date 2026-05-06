#!/usr/bin/env node
import { execFileSync, spawnSync } from "node:child_process";

function fail(message, code = 1) {
  console.error(message);
  process.exit(code);
}

function gh(args, options = {}) {
  return execFileSync("gh", args, {
    encoding: "utf8",
    stdio: options.stdio || ["ignore", "pipe", "pipe"],
  }).trim();
}

function ghJson(args, fallback) {
  const output = gh(args);
  if (!output) return fallback;
  return JSON.parse(output);
}

function repoParts() {
  const nameWithOwner = gh(["repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"]);
  const [owner, repo] = nameWithOwner.split("/");
  if (!owner || !repo) fail(`Could not parse GitHub repo: ${nameWithOwner}`);
  return { owner, repo };
}

function prView(prRef) {
  return ghJson([
    "pr",
    "view",
    prRef,
    "--json",
    "number,url,reviewDecision,mergeStateStatus,state,isDraft",
  ]);
}

function inlineComments(prRef) {
  const { owner, repo } = repoParts();
  return ghJson([
    "api",
    `repos/${owner}/${repo}/pulls/${prRef}/comments`,
    "--jq",
    '[.[] | select(.user.login == "coderabbitai") | {id: .id, path: .path, line: .line, body: .body, diff_hunk: .diff_hunk}]',
  ], []);
}

function topLevelComments(prRef) {
  return ghJson([
    "pr",
    "view",
    prRef,
    "--comments",
    "--json",
    "comments",
    "--jq",
    '[.comments[] | select(.author.login == "coderabbitai") | {body: .body, createdAt: .createdAt}]',
  ], []);
}

function unresolvedThreads(prRef) {
  const { owner, repo } = repoParts();
  const query = `query { repository(owner: "${owner}", name: "${repo}") { pullRequest(number: ${Number(prRef)}) { reviewThreads(first: 100) { nodes { id isResolved comments(first: 5) { nodes { body path line author { login } } } } } } } }`;
  return ghJson([
    "api",
    "graphql",
    "--raw-field",
    `query=${query}`,
    "--jq",
    ".data.repository.pullRequest.reviewThreads.nodes",
  ], []).filter((thread) => thread.isResolved === false);
}

function markdownSummary(prRef) {
  const view = prView(prRef);
  const inline = inlineComments(String(view.number));
  const topLevel = topLevelComments(String(view.number));
  const threads = unresolvedThreads(String(view.number));

  const inlineMarkdown = inline.length
    ? inline
        .map(
          (comment, index) => `### Inline Comment ${index + 1}

Path: ${comment.path}
Line: ${comment.line ?? "unknown"}

Diff hunk:
\`\`\`diff
${comment.diff_hunk || ""}
\`\`\`

Body:
${comment.body}
`,
        )
        .join("\n")
    : "No CodeRabbit inline comments found.";

  const topLevelMarkdown = topLevel.length
    ? topLevel
        .map(
          (comment, index) => `### Top-Level Comment ${index + 1}

Created: ${comment.createdAt}

${comment.body}
`,
        )
        .join("\n")
    : "No CodeRabbit top-level comments found.";

  const threadMarkdown = threads.length
    ? threads
        .map((thread, index) => {
          const comments = thread.comments.nodes
            .map(
              (comment) => `- ${comment.author.login}${comment.path ? ` on ${comment.path}:${comment.line ?? "?"}` : ""}: ${comment.body}`,
            )
            .join("\n");
          return `### Unresolved Thread ${index + 1}

Thread ID: ${thread.id}

${comments}
`;
        })
        .join("\n")
    : "No unresolved review threads found.";

  return `# CodeRabbit Review Context

PR: ${view.url}
Review decision: ${view.reviewDecision}
Merge state: ${view.mergeStateStatus}
State: ${view.state}
Draft: ${view.isDraft}

## Inline CodeRabbit Comments

${inlineMarkdown}

## Top-Level CodeRabbit Comments

${topLevelMarkdown}

## Unresolved Review Threads

${threadMarkdown}
`;
}

function waitChecks(prRef) {
  const result = spawnSync("gh", ["pr", "checks", prRef, "--watch", "--fail-fast"], {
    stdio: "inherit",
  });
  process.exit(result.status ?? 1);
}

function resolveThread(threadId) {
  const query = `mutation { resolveReviewThread(input: {threadId: "${threadId}"}) { thread { isResolved } } }`;
  console.log(gh([
    "api",
    "graphql",
    "--raw-field",
    `query=${query}`,
    "--jq",
    ".data.resolveReviewThread.thread.isResolved",
  ]));
}

function replyThread(threadId, body) {
  const escapedBody = JSON.stringify(body);
  const query = `mutation { addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: "${threadId}", body: ${escapedBody}}) { comment { id } } }`;
  console.log(gh([
    "api",
    "graphql",
    "--raw-field",
    `query=${query}`,
    "--jq",
    ".data.addPullRequestReviewThreadReply.comment.id",
  ]));
}

function isClean(prRef) {
  const view = prView(prRef);
  const threads = unresolvedThreads(String(view.number));
  const reviewApproved = view.reviewDecision === "APPROVED";
  const mergeUnblocked = !["BLOCKED", "DIRTY", "UNKNOWN"].includes(view.mergeStateStatus);

  if (threads.length === 0 && reviewApproved && mergeUnblocked) {
    process.exit(0);
  }

  console.error(
    `CodeRabbit review is not clean yet. reviewDecision=${view.reviewDecision}, mergeStateStatus=${view.mergeStateStatus}, unresolvedThreads=${threads.length}`,
  );
  process.exit(1);
}

const [command, prRef, extra] = process.argv.slice(2);

switch (command) {
  case "wait-checks":
    waitChecks(prRef || "");
    break;
  case "summary":
    console.log(markdownSummary(prRef || ""));
    break;
  case "comments":
    console.log(
      JSON.stringify(
        {
          inline: inlineComments(prRef || ""),
          topLevel: topLevelComments(prRef || ""),
        },
        null,
        2,
      ),
    );
    break;
  case "unresolved-threads":
    console.log(JSON.stringify(unresolvedThreads(prRef || ""), null, 2));
    break;
  case "resolve-thread":
    resolveThread(prRef || extra || "");
    break;
  case "reply-thread":
    replyThread(prRef || "", process.argv.slice(4).join(" "));
    break;
  case "is-clean":
    isClean(prRef || "");
    break;
  default:
    fail(`Unknown command "${command || ""}".`);
}
