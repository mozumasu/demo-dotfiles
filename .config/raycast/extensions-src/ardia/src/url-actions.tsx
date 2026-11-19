import { Action, ActionPanel, Icon, List } from "@raycast/api";
import { BUNDLE_ID } from "./ardia";

export function UrlActions({ url, title }: { url: string; title: string }) {
  return (
    <ActionPanel>
      <Action.Open title="Open in Ardia" target={url} application={BUNDLE_ID} icon={Icon.Globe} />
      <Action.CopyToClipboard title="Copy URL" content={url} />
      <Action.CopyToClipboard
        title="Copy as Markdown Link"
        content={`[${title}](${url})`}
        shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
      />
      <Action.OpenInBrowser title="Open in Default Browser" url={url} shortcut={{ modifiers: ["cmd"], key: "o" }} />
    </ActionPanel>
  );
}

export function ProfileDropdown({
  profiles,
  onChange,
}: {
  profiles: { id: string; name: string }[];
  onChange: (id: string) => void;
}) {
  return (
    <List.Dropdown tooltip="Profile" storeValue onChange={onChange}>
      {profiles.map((p) => (
        <List.Dropdown.Item key={p.id} title={p.name} value={p.id} />
      ))}
    </List.Dropdown>
  );
}
