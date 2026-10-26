import { Action, ActionPanel, Color, Detail, Icon, List, showToast, Toast } from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { execFile } from "node:child_process";
import { open } from "node:fs/promises";
import { homedir, userInfo } from "node:os";
import { basename, join } from "node:path";
import { promisify } from "node:util";
import { useEffect, useState } from "react";

const execFileAsync = promisify(execFile);

// Raycast の最小 PATH では nix 管理の ghost が見えないため、実体のパスを直接指す
const GHOST = `/etc/profiles/per-user/${userInfo().username}/bin/ghost`;
const DB = join(homedir(), "Library/Application Support/ghost/tasks.db");

type Status = "running" | "exited" | "killed";

type Task = {
  id: string;
  pid: number;
  command: string[];
  env: [string, string][];
  cwd: string;
  status: Status;
  exitCode: number | null;
  startedAt: Date;
  finishedAt: Date | null;
  logPath: string;
};

type Row = {
  id: string;
  pid: number;
  command: string;
  env: string | null;
  cwd: string | null;
  status: Status;
  exit_code: number | null;
  started_at: number;
  finished_at: number | null;
  log_path: string;
};

function isAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

// ghost list の表示はコマンドを省略するため、全文と起動時の環境変数を持つ DB を直接読む
// DB は WAL モードで、-readonly だと -shm を作れず開けないことがあるため、読み取りだけでも通常の方法で開く
async function loadTasks(): Promise<Task[]> {
  const { stdout } = await execFileAsync("/usr/bin/sqlite3", [
    "-json",
    DB,
    "select * from tasks order by started_at desc limit 100",
  ]);
  const rows: Row[] = stdout.trim() ? JSON.parse(stdout) : [];
  return rows.map((r) => ({
    id: r.id,
    pid: r.pid,
    command: JSON.parse(r.command),
    env: r.env ? JSON.parse(r.env) : [],
    cwd: r.cwd ?? homedir(),
    // ghost が終了を記録する前に落ちたプロセスは running のまま残るため、生きているかを確かめる
    status: r.status === "running" && !isAlive(r.pid) ? "exited" : r.status,
    exitCode: r.exit_code,
    startedAt: new Date(r.started_at * 1000),
    finishedAt: r.finished_at ? new Date(r.finished_at * 1000) : null,
    logPath: r.log_path,
  }));
}

const ANSI = /\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07]*\x07/g;

async function readLogTail(path: string, maxBytes: number): Promise<string> {
  let fh;
  try {
    fh = await open(path, "r");
  } catch {
    return "";
  }
  try {
    const { size } = await fh.stat();
    const start = Math.max(0, size - maxBytes);
    const buf = Buffer.alloc(size - start);
    await fh.read(buf, 0, buf.length, start);
    let text = buf.toString("utf8");
    // 途中から読んだときは、切れた先頭行を捨てる
    if (start > 0) text = text.slice(text.indexOf("\n") + 1);
    return text.replace(ANSI, "");
  } finally {
    await fh.close();
  }
}

function codeBlock(text: string): string {
  const longest = Math.max(2, ...(text.match(/`+/g) ?? []).map((s) => s.length));
  const fence = "`".repeat(longest + 1);
  return `${fence}\n${text || "(ログは空です)"}\n${fence}`;
}

function shellQuote(arg: string): string {
  return /^[\w@%+=:,./-]+$/.test(arg) ? arg : `'${arg.replace(/'/g, `'\\''`)}'`;
}

async function waitForExit(pid: number, timeoutMs: number): Promise<boolean> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (!isAlive(pid)) return true;
    await new Promise((r) => setTimeout(r, 200));
  }
  return !isAlive(pid);
}

async function stopTask(task: Task, force: boolean) {
  await execFileAsync(GHOST, ["stop", ...(force ? ["--force"] : []), task.id]);
}

// 起動したときの環境変数で同じディレクトリから起動し直す。Raycast の環境で動かすと PATH などが足りない
async function rerunTask(task: Task) {
  if (task.status === "running" && isAlive(task.pid)) {
    await stopTask(task, false);
    if (!(await waitForExit(task.pid, 10_000))) {
      await stopTask(task, true);
      await waitForExit(task.pid, 3_000);
    }
  }
  await execFileAsync(GHOST, ["run", "--cwd", task.cwd, "--", ...task.command], {
    cwd: task.cwd,
    env: Object.fromEntries(task.env),
  });
}

async function runWithToast(title: string, fn: () => Promise<void>, onDone: () => void) {
  const toast = await showToast({ style: Toast.Style.Animated, title: `${title}中…` });
  try {
    await fn();
    toast.style = Toast.Style.Success;
    toast.title = `${title}しました`;
  } catch (e) {
    toast.style = Toast.Style.Failure;
    toast.title = `${title}できませんでした`;
    toast.message = e instanceof Error ? e.message : String(e);
  } finally {
    onDone();
  }
}

function statusIcon(task: Task) {
  if (task.status === "running") return { source: Icon.CircleFilled, tintColor: Color.Green };
  if (task.status === "killed") return { source: Icon.XMarkCircle, tintColor: Color.Red };
  return { source: Icon.Circle, tintColor: task.exitCode ? Color.Orange : Color.SecondaryText };
}

function statusLabel(task: Task): string {
  if (task.status === "running") return "実行中";
  if (task.status === "killed") return "停止";
  return task.exitCode == null ? "終了" : `終了 (${task.exitCode})`;
}

function taskKey(task: Task): string {
  return JSON.stringify([task.cwd, task.command]);
}

function formatDate(d: Date): string {
  return d.toLocaleString("ja-JP", { month: "numeric", day: "numeric", hour: "2-digit", minute: "2-digit" });
}

function TaskDetail({ task }: { task: Task }) {
  const { data: log } = usePromise(readLogTail, [task.logPath, 8_000]);
  return (
    <List.Item.Detail
      markdown={codeBlock(log ?? "")}
      metadata={
        <List.Item.Detail.Metadata>
          <List.Item.Detail.Metadata.TagList title="状態">
            <List.Item.Detail.Metadata.TagList.Item text={statusLabel(task)} color={statusIcon(task).tintColor} />
          </List.Item.Detail.Metadata.TagList>
          <List.Item.Detail.Metadata.Label title="コマンド" text={task.command.join(" ")} />
          <List.Item.Detail.Metadata.Label title="ディレクトリ" text={task.cwd} />
          <List.Item.Detail.Metadata.Label title="PID" text={String(task.pid)} />
          <List.Item.Detail.Metadata.Label title="開始" text={formatDate(task.startedAt)} />
          {task.finishedAt && <List.Item.Detail.Metadata.Label title="終了" text={formatDate(task.finishedAt)} />}
          <List.Item.Detail.Metadata.Label title="ID" text={task.id} />
        </List.Item.Detail.Metadata>
      }
    />
  );
}

function LogView({ task }: { task: Task }) {
  const { data: log, isLoading, revalidate } = usePromise(readLogTail, [task.logPath, 200_000]);
  // 実行中のタスクは tail -f のように追いかける
  useEffect(() => {
    if (task.status !== "running") return;
    const timer = setInterval(revalidate, 2_000);
    return () => clearInterval(timer);
  }, [task.status]);
  return (
    <Detail
      navigationTitle={`${basename(task.cwd)} のログ`}
      isLoading={isLoading}
      markdown={codeBlock(log ?? "")}
      actions={
        <ActionPanel>
          <Action title="再読み込み" icon={Icon.ArrowClockwise} onAction={revalidate} />
          <Action.Open title="ログファイルを開く" target={task.logPath} shortcut={{ modifiers: ["cmd"], key: "o" }} />
          <Action.CopyToClipboard title="ログをコピー" content={log ?? ""} />
        </ActionPanel>
      }
    />
  );
}

export default function Command() {
  const { data: tasks, isLoading, revalidate } = usePromise(loadTasks);
  const [showingDetail, setShowingDetail] = useState(true);

  const running = (tasks ?? []).filter((t) => t.status === "running");
  // 起動し直すたびに記録が増えるため、終了済みは同じディレクトリとコマンドの組を最新の 1 件にまとめる
  // 実行中のものと同じ組は、実行中の行から再起動できるので出さない
  const runCounts = new Map<string, number>();
  for (const t of tasks ?? []) runCounts.set(taskKey(t), (runCounts.get(taskKey(t)) ?? 0) + 1);
  const seen = new Set(running.map(taskKey));
  const finished = (tasks ?? []).filter((t) => {
    if (t.status === "running" || seen.has(taskKey(t))) return false;
    seen.add(taskKey(t));
    return true;
  });

  const sections: [string, Task[]][] = [
    ["実行中", running],
    ["終了済み", finished],
  ];

  return (
    <List isLoading={isLoading} isShowingDetail={showingDetail} searchBarPlaceholder="ディレクトリやコマンドで絞り込む">
      {sections.map(([title, items]) => (
        <List.Section key={title} title={title} subtitle={String(items.length)}>
          {items.map((task) => (
            <List.Item
              key={task.id}
              icon={statusIcon(task)}
              title={basename(task.cwd)}
              subtitle={showingDetail ? undefined : task.command.join(" ")}
              keywords={[...task.command, task.cwd]}
              accessories={[
                ...(task.status !== "running" && runCounts.get(taskKey(task))! > 1
                  ? [{ tag: `${runCounts.get(taskKey(task))}回`, tooltip: "同じディレクトリとコマンドで起動した回数" }]
                  : []),
                { text: formatDate(task.startedAt) },
              ]}
              detail={<TaskDetail task={task} />}
              actions={
                <ActionPanel>
                  <ActionPanel.Section>
                    <Action.Push title="ログを見る" icon={Icon.Terminal} target={<LogView task={task} />} />
                    <Action
                      title={task.status === "running" ? "再起動" : "再実行"}
                      icon={Icon.RotateClockwise}
                      shortcut={{ modifiers: ["cmd", "shift"], key: "r" }}
                      onAction={() => runWithToast("再実行", () => rerunTask(task), revalidate)}
                    />
                    {task.status === "running" && (
                      <>
                        <Action
                          title="停止"
                          icon={Icon.Stop}
                          style={Action.Style.Destructive}
                          shortcut={{ modifiers: ["ctrl"], key: "x" }}
                          onAction={() => runWithToast("停止", () => stopTask(task, false), revalidate)}
                        />
                        <Action
                          title="強制停止"
                          icon={Icon.XMarkCircle}
                          style={Action.Style.Destructive}
                          shortcut={{ modifiers: ["ctrl", "shift"], key: "x" }}
                          onAction={() => runWithToast("強制停止", () => stopTask(task, true), revalidate)}
                        />
                      </>
                    )}
                  </ActionPanel.Section>
                  <ActionPanel.Section>
                    <Action.Open
                      title="ログファイルを開く"
                      target={task.logPath}
                      shortcut={{ modifiers: ["cmd"], key: "o" }}
                    />
                    <Action.ShowInFinder
                      title="ディレクトリを Finder で開く"
                      path={task.cwd}
                      shortcut={{ modifiers: ["cmd", "shift"], key: "f" }}
                    />
                    <Action.CopyToClipboard
                      title="起動コマンドをコピー"
                      content={`cd ${shellQuote(task.cwd)} && ghost run -- ${task.command.map(shellQuote).join(" ")}`}
                      shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
                    />
                  </ActionPanel.Section>
                  <ActionPanel.Section>
                    <Action
                      title={showingDetail ? "詳細を隠す" : "詳細を表示"}
                      icon={Icon.Sidebar}
                      shortcut={{ modifiers: ["cmd"], key: "d" }}
                      onAction={() => setShowingDetail((v) => !v)}
                    />
                    <Action
                      title="一覧を更新"
                      icon={Icon.ArrowClockwise}
                      shortcut={{ modifiers: ["cmd"], key: "r" }}
                      onAction={revalidate}
                    />
                    <Action
                      title="終了済みの記録を消す"
                      icon={Icon.Trash}
                      style={Action.Style.Destructive}
                      onAction={() =>
                        runWithToast(
                          "終了済みの記録を削除",
                          async () => void (await execFileAsync(GHOST, ["cleanup", "--all"])),
                          revalidate,
                        )
                      }
                    />
                  </ActionPanel.Section>
                </ActionPanel>
              }
            />
          ))}
        </List.Section>
      ))}
    </List>
  );
}
