import { Action, ActionPanel, Color, Icon, List } from "@raycast/api";
import { existsSync } from "node:fs";
import { useCallback, useEffect, useRef, useState } from "react";
import {
  canRestart,
  elapsed,
  LOG_PATH,
  loadSnapshot,
  Operation,
  operationsFor,
  Phase,
  PHASE_LABEL,
  phaseOf,
  recentMessage,
  route,
  Snapshot,
} from "./lib/kamatte";
import { OperationAction, OPERATIONS, perform, PHASE_ICON, refreshMenuBar, restart } from "./lib/ui";

// 開いている間は着信や相手の応答をすぐ映し、経過時間も進める
const POLL_MS = 1_000;

const PHASE_HINT: Partial<Record<Phase, string>> = {
  stopped: "launchd の dev.kamatte.daemon を起動し直すと戻ります",
  reconnecting: "長くても 30 秒ほどでつながり直します",
};

function useSnapshot() {
  const [snapshot, setSnapshot] = useState<Snapshot>();
  const [error, setError] = useState<Error>();
  const [isLoading, setIsLoading] = useState(true);
  const inFlight = useRef(false);

  // 前の取得が終わる前に次を始めない。失敗しても次の周期で取り直す
  const refresh = useCallback(async () => {
    if (inFlight.current) return;
    inFlight.current = true;
    try {
      setSnapshot(await loadSnapshot());
      setError(undefined);
    } catch (e) {
      setError(e instanceof Error ? e : new Error(String(e)));
    } finally {
      inFlight.current = false;
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
    const timer = setInterval(refresh, POLL_MS);
    return () => clearInterval(timer);
  }, [refresh]);

  return { snapshot, error, isLoading, refresh };
}

export default function Command() {
  const { snapshot, error, isLoading, refresh } = useSnapshot();
  const [acting, setActing] = useState(false);
  const actingRef = useRef(false);
  const afterAction = () => Promise.all([refreshMenuBar(), refresh()]);

  // 呼び出しの返事を待つ間に Enter をもう一度押すと、切り替わった先の取り消しが走ってしまう。終わるまで次を受け付けない
  const act = (fn: () => Promise<void>) => async () => {
    if (actingRef.current) return;
    actingRef.current = true;
    setActing(true);
    try {
      await fn();
    } finally {
      actingRef.current = false;
      setActing(false);
    }
  };
  const operationAction = (op: Operation, s: Snapshot) => (
    <OperationAction
      key={op}
      op={op}
      snapshot={s}
      onAction={act(() => perform(op, { inWindow: true, onDone: afterAction }))}
    />
  );

  const common = (phase?: Phase) => (
    <ActionPanel.Section>
      <Action
        title="状態を読み直す"
        icon={Icon.ArrowClockwise}
        shortcut={{ modifiers: ["cmd"], key: "r" }}
        onAction={refresh}
      />
      {phase && canRestart(phase) && (
        <Action
          title="デーモンを起動し直す"
          icon={Icon.Power}
          shortcut={{ modifiers: ["cmd", "shift"], key: "r" }}
          onAction={act(() => restart({ inWindow: true, onDone: afterAction }))}
        />
      )}
      {existsSync(LOG_PATH) && (
        <Action.Open title="デーモンのログを開く" target={LOG_PATH} shortcut={{ modifiers: ["cmd"], key: "o" }} />
      )}
    </ActionPanel.Section>
  );

  if (error) {
    return (
      <List isLoading={isLoading}>
        <List.EmptyView
          icon={{ source: Icon.Warning, tintColor: Color.Red }}
          title="kamatte の状態を読めませんでした"
          description={error.message}
          actions={<ActionPanel>{common()}</ActionPanel>}
        />
      </List>
    );
  }

  if (!snapshot) return <List isLoading />;

  const phase = phaseOf(snapshot);
  const ops = operationsFor(phase);
  const recent = recentMessage(snapshot);
  const active = phase === "ringing" || phase === "outgoing" || phase === "incall";
  // 操作がないときは下の行に状態を出すので、見出しには自分の名前だけを出す
  const heading = active
    ? `${PHASE_LABEL[phase]}  ${route(snapshot)}`
    : ops.length > 0
      ? `${PHASE_LABEL[phase]}  ${snapshot.me}`
      : snapshot.me;

  return (
    <List isLoading={isLoading || acting} searchBarPlaceholder="操作で絞り込む">
      <List.Section title={heading} subtitle={active ? elapsed(snapshot) : undefined}>
        {ops.map((op) => (
          <List.Item
            key={op}
            icon={OPERATIONS[op].icon}
            title={OPERATIONS[op].title(snapshot)}
            keywords={[op]}
            actions={
              <ActionPanel>
                {operationAction(op, snapshot)}
                {common(phase)}
              </ActionPanel>
            }
          />
        ))}
        {ops.length === 0 && (
          <List.Item
            icon={PHASE_ICON[phase]}
            title={PHASE_LABEL[phase]}
            subtitle={phase === "unauthorized" ? snapshot.authError : PHASE_HINT[phase]}
            actions={<ActionPanel>{common(phase)}</ActionPanel>}
          />
        )}
      </List.Section>
      {recent && (
        <List.Section title="最近の出来事">
          <List.Item
            icon={Icon.Clock}
            title={recent.text}
            accessories={[{ text: recent.time }]}
            actions={
              <ActionPanel>
                <ActionPanel.Section>{ops.map((op) => operationAction(op, snapshot))}</ActionPanel.Section>
                {common(phase)}
              </ActionPanel>
            }
          />
        </List.Section>
      )}
    </List>
  );
}
