import { Action, ActionPanel, closeMainWindow, Icon, List, showToast, Toast } from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { focusProfile, listProfiles } from "./ardia";

export default function Command() {
  const { data = [], isLoading } = usePromise(listProfiles);
  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search profiles">
      {data.map((p) => (
        <List.Item
          key={p.id}
          icon={Icon.Person}
          title={p.name}
          actions={
            <ActionPanel>
              <Action
                title="Switch to Profile"
                icon={Icon.ArrowRight}
                onAction={async () => {
                  try {
                    await focusProfile(p);
                    await closeMainWindow();
                  } catch (e) {
                    await showToast({ style: Toast.Style.Failure, title: "Failed to switch profile", message: String(e) });
                  }
                }}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
