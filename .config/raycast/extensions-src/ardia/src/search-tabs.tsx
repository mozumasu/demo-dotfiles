import { Action, ActionPanel, Icon, List, closeMainWindow, showToast, Toast } from "@raycast/api";
import { getFavicon, usePromise } from "@raycast/utils";
import { closeTab, focusTab, listTabs, reloadTab, Tab } from "./ardia";

export default function Command() {
  const { data = [], isLoading, revalidate } = usePromise(listTabs);
  const profiles = [...new Map(data.map((t) => [t.profile.id, t.profile])).values()];

  async function run(title: string, fn: () => Promise<void>) {
    try {
      await fn();
    } catch (e) {
      await showToast({ style: Toast.Style.Failure, title, message: String(e) });
    }
  }

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search tabs">
      {profiles.map((profile) => (
        <List.Section key={profile.id} title={profile.name}>
          {data
            .filter((t) => t.profile.id === profile.id)
            .map((tab: Tab) => (
              <List.Item
                key={tab.id}
                icon={getFavicon(tab.url, { fallback: Icon.Globe })}
                title={tab.title || tab.url || "New Tab"}
                subtitle={tab.url}
                keywords={[tab.url]}
                accessories={[
                  ...(tab.focused ? [{ icon: Icon.Eye, tooltip: "Selected" }] : []),
                  ...(tab.pinned ? [{ icon: Icon.Pin, tooltip: "Pinned" }] : []),
                ]}
                actions={
                  <ActionPanel>
                    <Action
                      title="Switch to Tab"
                      icon={Icon.ArrowRight}
                      onAction={() =>
                        run("Failed to switch tab", async () => {
                          await focusTab(tab);
                          await closeMainWindow();
                        })
                      }
                    />
                    {tab.url && <Action.CopyToClipboard title="Copy URL" content={tab.url} />}
                    {tab.url && (
                      <Action.CopyToClipboard
                        title="Copy as Markdown Link"
                        content={`[${tab.title}](${tab.url})`}
                        shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
                      />
                    )}
                    <Action
                      title="Reload Tab"
                      icon={Icon.ArrowClockwise}
                      shortcut={{ modifiers: ["cmd"], key: "r" }}
                      onAction={() => run("Failed to reload tab", () => reloadTab(tab))}
                    />
                    <Action
                      title="Close Tab"
                      icon={Icon.XMarkCircle}
                      style={Action.Style.Destructive}
                      shortcut={{ modifiers: ["ctrl"], key: "x" }}
                      onAction={() =>
                        run("Failed to close tab", async () => {
                          await closeTab(tab);
                          revalidate();
                        })
                      }
                    />
                    <Action
                      title="Refresh List"
                      icon={Icon.RotateClockwise}
                      shortcut={{ modifiers: ["cmd", "shift"], key: "r" }}
                      onAction={revalidate}
                    />
                  </ActionPanel>
                }
              />
            ))}
        </List.Section>
      ))}
      <List.EmptyView title="No tabs" description="Ardia が起動していないか、開いているタブがありません" />
    </List>
  );
}
