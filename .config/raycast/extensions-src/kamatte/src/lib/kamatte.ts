import { execFile } from "node:child_process";
import { accessSync, constants, existsSync } from "node:fs";
import { homedir, userInfo } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

// Raycast の最小 PATH では kamatte が見えないため、Script Commands で PATH に足していた場所を同じ順に探す
const CANDIDATES = [
  join(homedir(), ".local/bin/kamatte"),
  `/etc/profiles/per-user/${userInfo().username}/bin/kamatte`,
  join(homedir(), ".nix-profile/bin/kamatte"),
];

const STATE_DIR = process.env.KAMATTE_STATE_DIR ?? join(homedir(), ".local/state/kamatte");
export const LOG_PATH = join(STATE_DIR, "daemon.log");
const STATE_PATH = join(STATE_DIR, "state.json");
// デーモンは 30 秒ごとに状態ファイルを書き直す。kamatte status と WezTerm と同じく 3 回分途切れたら止まったとみなす
const STALE_SECONDS = 90;
const DAEMON_LABEL = "dev.kamatte.daemon";

export type Status = "idle" | "ringing" | "outgoing" | "incall";
export type Phase = Status | "stopped" | "unauthorized" | "reconnecting";
export type Operation = "call" | "answer" | "decline" | "cancel" | "hangup" | "toggle";

// メニューバーのキャッシュに JSON で保存するので、Date などを持たせない
export type Snapshot = {
  status: Status;
  me: string;
  peer: string;
  caller?: string;
  callee?: string;
  since?: number;
  connected: boolean;
  message?: string;
  messageAt?: number;
  authError?: string;
  running: boolean;
};

function kamatteBin(): string {
  const bin = CANDIDATES.find((path) => {
    try {
      accessSync(path, constants.X_OK);
      return true;
    } catch {
      return false;
    }
  });
  if (!bin)
    throw new Error("kamatte が見つかりません。home-manager の switch か kamatte の mac/install.sh で入れてください");
  return bin;
}

// kamatte は失敗すると「kamatte: 理由」を標準エラーに出して終了コード 1 で終わる
function toError(e: unknown, timeoutMessage: string): Error {
  const err = e as { stderr?: string; killed?: boolean; message?: string };
  if (err.killed) return new Error(timeoutMessage);
  const reason = err.stderr?.trim().replace(/^kamatte: /, "");
  return new Error(reason || err.message || String(e));
}

async function kamatte(args: string[], timeout: number): Promise<string> {
  try {
    const { stdout } = await execFileAsync(kamatteBin(), args, { timeout });
    return stdout;
  } catch (e) {
    throw toError(e, `kamatte ${args.join(" ")} が ${timeout / 1000} 秒たっても終わりませんでした`);
  }
}

export async function loadSnapshot(): Promise<Snapshot> {
  const st = JSON.parse(await kamatte(["status", "--json"], 10_000));
  return {
    status: st.status,
    me: st.me,
    peer: st.peer,
    caller: st.caller,
    callee: st.callee,
    since: st.since,
    connected: st.connected,
    message: st.message,
    messageAt: st.messageAt,
    authError: st.authError,
    // 状態ファイルがないときも status --json は今の時刻の idle を返すので、ファイルがあるかも確かめる
    running: existsSync(STATE_PATH) && Date.now() / 1000 - st.updatedAt < STALE_SECONDS,
  };
}

// デーモンの応答メッセージを返す。着信も呼び出しも通話もないときの toggle は空になる
export async function runOperation(op: Operation): Promise<string> {
  // 応答を待つ側のタイムアウトは 15 秒なので、それより長く待つ
  return (await kamatte([op], 30_000)).trim();
}

export async function restartDaemon(): Promise<void> {
  try {
    await execFileAsync("/bin/launchctl", ["kickstart", "-k", `gui/${userInfo().uid}/${DAEMON_LABEL}`], {
      timeout: 10_000,
    });
  } catch (e) {
    // 113 はサービスが launchd に登録されていないとき
    if ((e as { code?: number }).code === 113) {
      throw new Error(
        `launchd に ${DAEMON_LABEL} が登録されていません。home-manager の switch か kamatte の mac/install.sh で登録してください`,
      );
    }
    throw toError(e, "launchctl kickstart が終わりませんでした");
  }
}

export function phaseOf(s: Snapshot): Phase {
  if (!s.running) return "stopped";
  if (!s.connected && s.authError) return "unauthorized";
  if (s.status === "idle" && !s.connected) return "reconnecting";
  return s.status;
}

export const PHASE_LABEL: Record<Phase, string> = {
  idle: "待ち受け中",
  ringing: "着信中",
  outgoing: "呼び出し中",
  incall: "通話中",
  stopped: "デーモンが止まっています",
  unauthorized: "接続できません",
  reconnecting: "接続し直しています",
};

export function operationsFor(phase: Phase): Operation[] {
  switch (phase) {
    case "idle":
      return ["call"];
    case "ringing":
      return ["answer", "decline"];
    case "outgoing":
      return ["cancel"];
    case "incall":
      return ["hangup"];
    default:
      return [];
  }
}

// launchd から起動し直せば戻る状態か。通話や呼び出しの途中で起動し直すと切れてしまうので、待ち受け以外では出さない
export function canRestart(phase: Phase): boolean {
  return phase === "stopped" || phase === "unauthorized" || phase === "reconnecting";
}

export function route(s: Snapshot): string {
  return `${s.caller ?? "?"} → ${s.callee ?? "?"}`;
}

export function elapsed(s: Snapshot): string | undefined {
  if (s.since == null) return undefined;
  const sec = Math.max(0, Math.floor(Date.now() / 1000 - s.since));
  return `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, "0")}`;
}

const PHASE_MARK: Record<Phase, string> = {
  idle: "●",
  ringing: "📞",
  outgoing: "📞",
  incall: "🔴",
  stopped: "○",
  unauthorized: "○",
  reconnecting: "○",
};

// Script Commands の kamatte status が出していた kamatte status --short の一行目に合わせる
export function summary(s: Snapshot): string {
  const phase = phaseOf(s);
  const rest =
    phase === "ringing" || phase === "outgoing" || phase === "incall"
      ? [route(s), elapsed(s)].filter(Boolean).join("  ")
      : s.me;
  return `${PHASE_MARK[phase]} ${PHASE_LABEL[phase]}  ${rest}`;
}

// Alfred のワークフローと同じく、5 分以内の出来事だけを出す
export function recentMessage(s: Snapshot): { text: string; time: string } | undefined {
  if (!s.message || s.messageAt == null || Date.now() / 1000 - s.messageAt > 300) return undefined;
  const time = new Date(s.messageAt * 1000).toLocaleTimeString("ja-JP", { hour: "2-digit", minute: "2-digit" });
  return { text: s.message, time };
}
