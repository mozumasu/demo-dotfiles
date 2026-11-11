import { Action, Color, Icon, Image, launchCommand, LaunchType, showHUD, showToast, Toast } from "@raycast/api";
import { Operation, Phase, restartDaemon, runOperation, Snapshot } from "./kamatte";

type OperationInfo = {
  title: (s: Snapshot) => string;
  icon: Image.ImageLike;
  progress: string;
  failure: string;
  destructive?: boolean;
};

export const OPERATIONS: Record<Operation, OperationInfo> = {
  call: {
    title: (s) => `${s.peer} を呼び出す`,
    icon: { source: Icon.Phone, tintColor: Color.Green },
    progress: "呼び出しています…",
    failure: "呼び出せませんでした",
  },
  answer: {
    title: () => "出る",
    icon: { source: Icon.Phone, tintColor: Color.Green },
    progress: "応答しています…",
    failure: "出られませんでした",
  },
  decline: {
    title: () => "拒否する",
    icon: { source: Icon.XMarkCircle, tintColor: Color.Red },
    progress: "拒否しています…",
    failure: "拒否できませんでした",
    destructive: true,
  },
  cancel: {
    title: () => "呼び出しを取り消す",
    icon: { source: Icon.Undo, tintColor: Color.Orange },
    progress: "取り消しています…",
    failure: "取り消せませんでした",
    destructive: true,
  },
  hangup: {
    title: () => "切る",
    icon: { source: Icon.Stop, tintColor: Color.Red },
    progress: "切っています…",
    failure: "切れませんでした",
    destructive: true,
  },
  toggle: {
    title: () => "出る、取り消す、切る",
    icon: Icon.Switch,
    progress: "切り替えています…",
    failure: "切り替えられませんでした",
  },
};

export const PHASE_ICON: Record<Phase, Image.ImageLike> = {
  idle: { source: Icon.Phone, tintColor: Color.Green },
  ringing: { source: Icon.PhoneRinging, tintColor: Color.Red },
  outgoing: { source: Icon.PhoneRinging, tintColor: Color.Orange },
  incall: { source: Icon.Phone, tintColor: Color.Blue },
  stopped: { source: Icon.Power, tintColor: Color.SecondaryText },
  unauthorized: { source: Icon.Warning, tintColor: Color.Red },
  reconnecting: { source: Icon.WifiDisabled, tintColor: Color.Orange },
};

// メニューバーのコマンドを有効にしていないと launchCommand が失敗する。そのときは更新するものがない
export async function refreshMenuBar() {
  try {
    await launchCommand({ name: "menu-bar", type: LaunchType.Background });
  } catch {
    // 何もしない
  }
}

type Options = {
  // Raycast の画面の中から呼ぶか。画面が閉じているとトーストは HUD に置き換わり、あとから失敗に書き換えても映らない
  inWindow?: boolean;
  onDone?: () => unknown;
};

async function fail(toast: Toast | undefined, title: string, e: unknown) {
  const message = e instanceof Error ? e.message : String(e);
  if (!toast) return showHUD(`${title}: ${message}`);
  toast.style = Toast.Style.Failure;
  toast.title = title;
  toast.message = message;
}

// 成功したら HUD を出して Raycast を閉じる。画面の中で失敗したら、理由をトーストに残して開いたままにする
export async function perform(op: Operation, { inWindow = false, onDone = refreshMenuBar }: Options = {}) {
  const info = OPERATIONS[op];
  const toast = inWindow ? await showToast({ style: Toast.Style.Animated, title: info.progress }) : undefined;
  try {
    const message = await runOperation(op);
    await toast?.hide();
    await showHUD(message || "着信も呼び出しも通話もありません");
  } catch (e) {
    await fail(toast, info.failure, e);
  } finally {
    await onDone();
  }
}

export async function restart({ inWindow = false, onDone = refreshMenuBar }: Options = {}) {
  const toast = inWindow
    ? await showToast({ style: Toast.Style.Animated, title: "デーモンを起動し直しています…" })
    : undefined;
  try {
    await restartDaemon();
    if (!toast) {
      await showHUD("デーモンを起動し直しました");
    } else {
      toast.style = Toast.Style.Success;
      toast.title = "デーモンを起動し直しました";
    }
  } catch (e) {
    await fail(toast, "デーモンを起動し直せませんでした", e);
  } finally {
    await onDone();
  }
}

export function OperationAction({
  op,
  snapshot,
  onAction,
}: {
  op: Operation;
  snapshot: Snapshot;
  onAction: () => void;
}) {
  const info = OPERATIONS[op];
  return (
    <Action
      title={info.title(snapshot)}
      icon={info.icon}
      style={info.destructive ? Action.Style.Destructive : Action.Style.Regular}
      onAction={onAction}
    />
  );
}

export function noViewCommand(op: Operation) {
  return () => perform(op);
}
