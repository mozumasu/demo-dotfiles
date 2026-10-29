import { Color, Icon, Image, launchCommand, LaunchType, MenuBarExtra, open, updateCommandMetadata } from "@raycast/api";
import { useCachedPromise } from "@raycast/utils";
import { existsSync } from "node:fs";
import { useState } from "react";
import {
  canRestart,
  elapsed,
  LOG_PATH,
  loadSnapshot,
  operationsFor,
  Phase,
  PHASE_LABEL,
  phaseOf,
  recentMessage,
  route,
  summary,
} from "./lib/kamatte";
import { OPERATIONS, PHASE_ICON, perform, restart } from "./lib/ui";

// メニューバーの表示は短くし、詳しい状態はメニューを開いたときに出す
const MENU_TITLE: Partial<Record<Phase, string>> = {
  ringing: "着信中",
  outgoing: "呼び出し中",
  incall: "通話中",
};

// 待ち受け中は色を付けず、メニューバーの文字色に合わせる
function menuIcon(phase: Phase): Image.ImageLike {
  return phase === "idle" ? Icon.Phone : PHASE_ICON[phase];
}

export default function Command() {
  const [busy, setBusy] = useState(false);
  const { data, error, isLoading, revalidate } = useCachedPromise(loadSnapshot, [], {
    keepPreviousData: true,
    // 10 秒ごとに裏で動くので、失敗のたびにトーストを出さない。理由はメニューに出す
    onError: () => {},
    // ルート検索のこのコマンドの行にも今の状態を出す
    onData: (s) => updateCommandMetadata({ subtitle: summary(s) }),
  });

  const run = (fn: () => Promise<void>) => async () => {
    setBusy(true);
    try {
      await fn();
    } finally {
      setBusy(false);
    }
  };
  const openKamatte = () => launchCommand({ name: "kamatte", type: LaunchType.UserInitiated });

  if (!data) {
    return (
      <MenuBarExtra
        icon={error ? { source: Icon.Phone, tintColor: Color.Red } : Icon.Phone}
        tooltip={error?.message ?? "kamatte"}
        isLoading={isLoading}
      >
        {error && <MenuBarExtra.Item title="kamatte の状態を読めませんでした" subtitle={error.message} />}
        <MenuBarExtra.Item title="Kamatte を開く" icon={Icon.AppWindow} onAction={openKamatte} />
      </MenuBarExtra>
    );
  }

  const phase = phaseOf(data);
  const active = phase === "ringing" || phase === "outgoing" || phase === "incall";
  const recent = recentMessage(data);

  return (
    <MenuBarExtra
      icon={menuIcon(phase)}
      title={MENU_TITLE[phase]}
      tooltip={summary(data)}
      isLoading={isLoading || busy}
    >
      <MenuBarExtra.Section>
        <MenuBarExtra.Item
          icon={PHASE_ICON[phase]}
          title={PHASE_LABEL[phase]}
          subtitle={active ? [route(data), elapsed(data)].filter(Boolean).join("  ") : data.me}
        />
        {phase === "unauthorized" && <MenuBarExtra.Item title={data.authError ?? ""} />}
        {error && <MenuBarExtra.Item title="最新の状態を読めませんでした" subtitle={error.message} />}
        {recent && <MenuBarExtra.Item icon={Icon.Clock} title={recent.text} subtitle={recent.time} />}
      </MenuBarExtra.Section>
      <MenuBarExtra.Section>
        {operationsFor(phase).map((op) => (
          <MenuBarExtra.Item
            key={op}
            icon={OPERATIONS[op].icon}
            title={OPERATIONS[op].title(data)}
            onAction={run(() => perform(op, { onDone: revalidate }))}
          />
        ))}
        {canRestart(phase) && (
          <MenuBarExtra.Item
            icon={Icon.Power}
            title="デーモンを起動し直す"
            onAction={run(() => restart({ onDone: revalidate }))}
          />
        )}
      </MenuBarExtra.Section>
      <MenuBarExtra.Section>
        <MenuBarExtra.Item title="Kamatte を開く" icon={Icon.AppWindow} onAction={openKamatte} />
        {existsSync(LOG_PATH) && (
          <MenuBarExtra.Item title="デーモンのログを開く" icon={Icon.Document} onAction={() => open(LOG_PATH)} />
        )}
      </MenuBarExtra.Section>
    </MenuBarExtra>
  );
}
