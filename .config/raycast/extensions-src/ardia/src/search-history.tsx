import { Icon, List } from "@raycast/api";
import { getFavicon, usePromise } from "@raycast/utils";
import { useState } from "react";
import { listProfiles, searchHistory } from "./ardia";
import { ProfileDropdown, UrlActions } from "./url-actions";

export default function Command() {
  const [text, setText] = useState("");
  const [profileId, setProfileId] = useState<string>();
  const { data: profiles = [] } = usePromise(listProfiles);
  const profile = profiles.find((p) => p.id === profileId);
  const { data = [], isLoading } = usePromise(
    async (p: typeof profile, q: string) => (p ? searchHistory(p, q) : []),
    [profile, text],
  );

  return (
    <List
      isLoading={isLoading || !profile}
      filtering={false}
      throttle
      onSearchTextChange={setText}
      searchBarPlaceholder="Search history"
      searchBarAccessory={<ProfileDropdown profiles={profiles} onChange={setProfileId} />}
    >
      {data.map((item) => (
        <List.Item
          key={item.id}
          icon={getFavicon(item.url, { fallback: Icon.Globe })}
          title={item.title}
          subtitle={item.url}
          accessories={[{ date: item.lastVisit, tooltip: item.lastVisit.toLocaleString() }]}
          actions={<UrlActions url={item.url} title={item.title} />}
        />
      ))}
    </List>
  );
}
