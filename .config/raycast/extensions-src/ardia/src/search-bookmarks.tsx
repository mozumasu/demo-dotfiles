import { Icon, List } from "@raycast/api";
import { getFavicon, usePromise } from "@raycast/utils";
import { useState } from "react";
import { listBookmarks, listProfiles } from "./ardia";
import { ProfileDropdown, UrlActions } from "./url-actions";

export default function Command() {
  const [profileId, setProfileId] = useState<string>();
  const { data: profiles = [] } = usePromise(listProfiles);
  const profile = profiles.find((p) => p.id === profileId);
  const { data = [], isLoading } = usePromise(async (p: typeof profile) => (p ? listBookmarks(p) : []), [profile]);

  return (
    <List
      isLoading={isLoading || !profile}
      searchBarPlaceholder="Search bookmarks"
      searchBarAccessory={<ProfileDropdown profiles={profiles} onChange={setProfileId} />}
    >
      {data.map((b) => (
        <List.Item
          key={b.id}
          icon={getFavicon(b.url, { fallback: Icon.Bookmark })}
          title={b.title}
          subtitle={b.url}
          keywords={[b.url, b.folder]}
          accessories={b.folder ? [{ tag: b.folder }] : []}
          actions={<UrlActions url={b.url} title={b.title} />}
        />
      ))}
      <List.EmptyView title="No bookmarks" />
    </List>
  );
}
