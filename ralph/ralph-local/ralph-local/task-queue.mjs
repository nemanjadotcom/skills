#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

const repoRoot = execFileSync("git", ["rev-parse", "--show-toplevel"], {
  encoding: "utf8",
}).trim();

const prdDir = path.join(repoRoot, "docs", "roadmap", "prds");
const activeTaskDir = path.join(repoRoot, "docs", "roadmap", "tasks");
const doneTaskDir = path.join(activeTaskDir, "done");
const taskBlockStart = "<!-- ralph-local:tasks:start -->";
const taskBlockEnd = "<!-- ralph-local:tasks:end -->";

function fail(message, code = 1) {
  console.error(message);
  process.exit(code);
}

function toRepoPath(absPath) {
  return path.relative(repoRoot, absPath).split(path.sep).join("/");
}

function fromRepoPath(repoPath) {
  return path.resolve(repoRoot, repoPath);
}

function readText(absPath) {
  return fs.readFileSync(absPath, "utf8");
}

function writeText(absPath, content) {
  fs.writeFileSync(absPath, content);
}

function stripInlineComment(value) {
  let inSingle = false;
  let inDouble = false;

  for (let i = 0; i < value.length; i += 1) {
    const char = value[i];
    const prev = value[i - 1];

    if (char === "'" && !inDouble && prev !== "\\") inSingle = !inSingle;
    if (char === '"' && !inSingle && prev !== "\\") inDouble = !inDouble;
    if (char === "#" && !inSingle && !inDouble) {
      return value.slice(0, i).trim();
    }
  }

  return value.trim();
}

function unquote(value) {
  const trimmed = value.trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

function parseArray(value) {
  const trimmed = value.trim();
  if (!trimmed.startsWith("[") || !trimmed.endsWith("]")) return [];
  const body = trimmed.slice(1, -1).trim();
  if (!body) return [];
  return body
    .split(",")
    .map((item) => unquote(stripInlineComment(item).trim()))
    .filter(Boolean);
}

function parseFrontmatter(content) {
  const lines = content.split(/\r?\n/);
  if (lines[0]?.trim() !== "---") return {};

  const endIndex = lines.findIndex((line, index) => index > 0 && line.trim() === "---");
  if (endIndex === -1) return {};

  const frontmatter = {};
  for (const line of lines.slice(1, endIndex)) {
    const match = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!match) continue;

    const key = match[1];
    const rawValue = stripInlineComment(match[2]);
    if (rawValue.startsWith("[") && rawValue.endsWith("]")) {
      frontmatter[key] = parseArray(rawValue);
    } else {
      frontmatter[key] = unquote(rawValue);
    }
  }

  return frontmatter;
}

function replaceFrontmatterStatus(content, status) {
  const lines = content.split(/\r?\n/);
  if (lines[0]?.trim() !== "---") {
    fail("Cannot update status: file has no YAML frontmatter.");
  }

  const endIndex = lines.findIndex((line, index) => index > 0 && line.trim() === "---");
  if (endIndex === -1) {
    fail("Cannot update status: frontmatter is not closed.");
  }

  for (let i = 1; i < endIndex; i += 1) {
    if (/^status:\s*/.test(lines[i])) {
      lines[i] = `status: "${status}"`;
      return lines.join("\n");
    }
  }

  fail("Cannot update status: frontmatter has no status field.");
}

function listMarkdownFiles(absDir) {
  if (!fs.existsSync(absDir)) return [];
  return fs
    .readdirSync(absDir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
    .map((entry) => path.join(absDir, entry.name));
}

function resolvePrd(ref) {
  if (!ref) fail("Usage: task-queue.mjs <command> <prd-ref> [...]");

  const possiblePaths = [
    path.resolve(process.cwd(), ref),
    path.resolve(repoRoot, ref),
  ];

  for (const possiblePath of possiblePaths) {
    if (fs.existsSync(possiblePath) && fs.statSync(possiblePath).isFile()) {
      return describePrd(possiblePath, ref);
    }
  }

  const prds = listMarkdownFiles(prdDir).map((filePath) => describePrd(filePath, ref));
  const normalizedRef = ref.replace(/\.md$/, "");
  const matches = prds.filter((prd) => {
    return (
      prd.id === ref ||
      prd.stem === normalizedRef ||
      prd.stem === slugify(normalizedRef) ||
      prd.stem.startsWith(`${normalizedRef}-`) ||
      prd.stem.startsWith(`${slugify(normalizedRef)}-`)
    );
  });

  if (matches.length === 0) {
    fail(`No PRD matched "${ref}" in docs/roadmap/prds/.`);
  }

  if (matches.length > 1) {
    fail(
      `PRD reference "${ref}" is ambiguous:\n${matches
        .map((prd) => `- ${toRepoPath(prd.path)}`)
        .join("\n")}`,
    );
  }

  return matches[0];
}

function describePrd(absPath, originalRef) {
  const content = readText(absPath);
  const frontmatter = parseFrontmatter(content);
  const stem = path.basename(absPath, ".md");
  const prdPrefix = stem.match(/^prd-\d+(?:\.\d+)*/)?.[0];
  const title =
    frontmatter.title ||
    content.match(/^#\s+(.+)$/m)?.[1]?.trim() ||
    stem;

  return {
    path: absPath,
    repoPath: toRepoPath(absPath),
    stem,
    id: frontmatter.id || prdPrefix || stem,
    title,
    originalRef,
    content,
  };
}

function slugify(value) {
  return String(value)
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function parseTaskBlock(prd) {
  const startIndex = prd.content.indexOf(taskBlockStart);
  const endIndex = prd.content.indexOf(taskBlockEnd);

  if (startIndex === -1 || endIndex === -1 || endIndex < startIndex) {
    fail(
      `${prd.repoPath} has no Ralph task block. Add ${taskBlockStart} and ${taskBlockEnd}.`,
    );
  }

  const block = prd.content.slice(startIndex + taskBlockStart.length, endIndex);
  const entries = [];

  for (const line of block.split(/\r?\n/)) {
    // Checkbox is optional — PRD Ralph blocks no longer track completion (see AGENTS.md).
    // Format with checkbox: "- [ ] `id` [title](href)"  (legacy, still parsed for compat)
    // Format without:        "- `id` [title](href)"      (current)
    const match = line.match(/^\s*-\s+(?:\[([ xX-])\]\s+)?`([^`]+)`\s+\[([^\]]+)\]\(([^)]+)\)/);
    if (!match) continue;

    entries.push({
      id: match[2].trim(),
      title: match[3].trim(),
      href: match[4].trim(),
      line,
    });
  }

  if (entries.length === 0) {
    fail(`${prd.repoPath} has a Ralph task block, but it contains no task links.`);
  }

  return entries;
}

function resolveTaskPathFromHref(prd, href) {
  const decodedHref = decodeURI(href.split("#")[0]);
  const candidates = [
    path.resolve(path.dirname(prd.path), decodedHref),
    path.resolve(repoRoot, decodedHref),
    path.join(activeTaskDir, path.basename(decodedHref)),
    path.join(doneTaskDir, path.basename(decodedHref)),
  ];

  const found = candidates.find((candidate) => fs.existsSync(candidate));
  if (!found) {
    fail(`Task link "${href}" in ${prd.repoPath} does not resolve to a file.`);
  }

  return found;
}

function loadTasksForPrd(prd) {
  if (!/^prd-\d+(?:\.\d+)*$/.test(prd.id)) {
    fail(
      `${prd.repoPath} has PRD id "${prd.id}". Ralph Local PRD ids must use frontmatter id "prd-<phase.sequence>", for example "prd-4.86".`,
    );
  }

  const entries = parseTaskBlock(prd);

  return entries.map((entry, index) => {
    const taskPath = resolveTaskPathFromHref(prd, entry.href);
    const content = readText(taskPath);
    const frontmatter = parseFrontmatter(content);
    const parentPrd = frontmatter["parent-prd"] || frontmatter.parent_prd || "";
    const task = {
      ...entry,
      order: index,
      path: taskPath,
      repoPath: toRepoPath(taskPath),
      frontmatter,
      content,
      id: frontmatter.id || entry.id,
      title: frontmatter.title || entry.title,
      status: frontmatter.status || "pending",
      parentPrd,
      dependsOn: Array.isArray(frontmatter.depends_on) ? frontmatter.depends_on : [],
    };

    if (task.id !== entry.id) {
      fail(
        `Task id mismatch in ${prd.repoPath}: PRD lists ${entry.id}, but ${task.repoPath} has id ${task.id}.`,
      );
    }

    if (!parentPrd) {
      fail(`${task.repoPath} is listed in ${prd.repoPath} but has no parent-prd value.`);
    }

    if (parentPrd !== prd.id) {
      fail(
        `${task.repoPath} has parent-prd "${parentPrd}", but Ralph Local will only run tasks whose parent-prd exactly matches "${prd.id}".`,
      );
    }

    return task;
  });
}

function findNextTask(prd, requestedTaskId) {
  const tasks = loadTasksForPrd(prd);
  const byId = new Map(tasks.map((task) => [task.id, task]));

  const candidates = requestedTaskId
    ? tasks.filter((task) => task.id === requestedTaskId)
    : tasks;

  if (requestedTaskId && candidates.length === 0) {
    fail(`Task ${requestedTaskId} is not listed in ${prd.repoPath}.`);
  }

  const blocked = [];
  for (const task of candidates) {
    if (task.status !== "pending") continue;

    const unsatisfied = task.dependsOn.filter((dependencyId) => {
      const dependency = byId.get(dependencyId);
      return !dependency || dependency.status !== "done";
    });

    if (unsatisfied.length === 0) return task;

    blocked.push({ task, unsatisfied });
  }

  const unfinished = tasks.filter((task) => task.status !== "done");
  if (unfinished.length === 0) {
    console.log("COMPLETE");
    process.exit(2);
  }

  if (blocked.length > 0) {
    fail(
      `No runnable task is available for ${prd.repoPath}:\n${blocked
        .map(
          ({ task, unsatisfied }) =>
            `- ${task.id} is blocked by ${unsatisfied.join(", ")}`,
        )
        .join("\n")}`,
      3,
    );
  }

  fail(
    `No pending task is runnable for ${prd.repoPath}. Current unfinished tasks:\n${unfinished
      .map((task) => `- ${task.id}: ${task.status}`)
      .join("\n")}`,
    3,
  );
}

function markdownContext(prd, task) {
  const tasks = loadTasksForPrd(prd);
  const siblingRows = tasks
    .map((item) => `| ${item.id} | ${item.status} | ${item.dependsOn.join(", ") || "-"} | ${item.repoPath} |`)
    .join("\n");

  return `# Ralph Local Context

## PRD
Path: ${prd.repoPath}
ID: ${prd.id}
Title: ${prd.title}

${prd.content}

## Selected Task
Path: ${task.repoPath}
ID: ${task.id}
Title: ${task.title}

${task.content}

## PRD Task Status

| ID | Status | Depends On | Path |
| --- | --- | --- | --- |
${siblingRows}
`;
}

function updateTaskStatus(taskPath, status) {
  const absPath = path.resolve(process.cwd(), taskPath);
  if (!fs.existsSync(absPath)) fail(`Task file not found: ${taskPath}`);
  const content = readText(absPath);
  writeText(absPath, replaceFrontmatterStatus(content, status));
}

function summary(prd) {
  const tasks = loadTasksForPrd(prd);
  return `# Ralph PRD Summary

PRD: ${prd.title}
Path: ${prd.repoPath}

${tasks
  .map((task) => `- [${task.status === "done" ? "x" : " "}] ${task.id} ${task.title} (${task.status}) - ${task.repoPath}`)
  .join("\n")}
`;
}

const [command, prdRef, maybeTask] = process.argv.slice(2);

switch (command) {
  case "prd-path": {
    console.log(resolvePrd(prdRef).repoPath);
    break;
  }
  case "prd-id": {
    console.log(resolvePrd(prdRef).id);
    break;
  }
  case "prd-title": {
    console.log(resolvePrd(prdRef).title);
    break;
  }
  case "slug": {
    const prd = resolvePrd(prdRef);
    console.log(slugify(prd.id || prd.stem));
    break;
  }
  case "next-task": {
    const prd = resolvePrd(prdRef);
    console.log(findNextTask(prd, maybeTask).repoPath);
    break;
  }
  case "task-id": {
    const absTaskPath = path.resolve(process.cwd(), prdRef);
    console.log(parseFrontmatter(readText(absTaskPath)).id);
    break;
  }
  case "context": {
    const prd = resolvePrd(prdRef);
    const taskPath = path.resolve(process.cwd(), maybeTask);
    const taskContent = readText(taskPath);
    const task = {
      path: taskPath,
      repoPath: toRepoPath(taskPath),
      content: taskContent,
      frontmatter: parseFrontmatter(taskContent),
    };
    task.id = task.frontmatter.id;
    task.title = task.frontmatter.title;
    console.log(markdownContext(prd, task));
    break;
  }
  case "mark-in-progress": {
    updateTaskStatus(prdRef, "in-progress");
    break;
  }
  case "summary": {
    console.log(summary(resolvePrd(prdRef)));
    break;
  }
  default:
    fail(`Unknown command "${command || ""}".`);
}
