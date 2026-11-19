import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export const BUNDLE_ID = "com.ardia.browser";
const DATA_DIR = join(homedir(), "Library/Application Support", BUNDLE_ID, "Chromium");

export type Profile = { id: string; name: string };

export type Tab = {
  id: string;
  title: string;
  url: string;
  pinned: boolean;
  focused: boolean;
  profile: Profile;
};

// JXA の run(argv) に引数を渡し、文字列をスクリプトに埋め込まずに済ませる
async function jxa<T>(script: string, ...args: string[]): Promise<T> {
  const { stdout } = await execFileAsync("/usr/bin/osascript", ["-l", "JavaScript", "-e", script, ...args]);
  const out = stdout.trim();
  return (out ? JSON.parse(out) : undefined) as T;
}

// sdef の URL / isPinned / isFocused は JXA では url / ispinned / isfocused になる
export function listTabs(): Promise<Tab[]> {
  return jxa<Tab[]>(`
    function run() {
      const a = Application("Ardia");
      if (!a.running()) return "[]";
      const out = [];
      for (const p of a.profiles()) {
        const profile = { id: p.id(), name: p.name() };
        const t = p.tabs;
        const ids = t.id();
        if (ids.length === 0) continue;
        const titles = t.title(), urls = t.url(), pinned = t.ispinned(), focused = t.isfocused();
        ids.forEach((id, i) => out.push({ id, title: titles[i], url: urls[i], pinned: pinned[i], focused: focused[i], profile }));
      }
      return JSON.stringify(out);
    }`);
}

export function listProfiles(): Promise<Profile[]> {
  return jxa<Profile[]>(`
    function run() {
      const a = Application("Ardia");
      return JSON.stringify(a.profiles().map((p) => ({ id: p.id(), name: p.name() })));
    }`);
}

export async function focusTab(tab: Tab): Promise<void> {
  await jxa(
    `function run([profileId, tabId]) {
      const a = Application("Ardia");
      a.profiles.byId(profileId).tabs.byId(tabId).focus();
      a.activate();
    }`,
    tab.profile.id,
    tab.id,
  );
}

export async function closeTab(tab: Tab): Promise<void> {
  await jxa(
    `function run([profileId, tabId]) {
      const a = Application("Ardia");
      a.close(a.profiles.byId(profileId).tabs.byId(tabId));
    }`,
    tab.profile.id,
    tab.id,
  );
}

export async function reloadTab(tab: Tab): Promise<void> {
  await jxa(
    `function run([profileId, tabId]) {
      Application("Ardia").profiles.byId(profileId).tabs.byId(tabId).reload();
    }`,
    tab.profile.id,
    tab.id,
  );
}

export async function focusProfile(profile: Profile): Promise<void> {
  await jxa(
    `function run([profileId]) {
      const a = Application("Ardia");
      a.profiles.byId(profileId).focus();
      a.activate();
    }`,
    profile.id,
  );
}

// URL があれば open で渡す（Ardia が起動していなくても開ける）。なければ空のタブを作る
export async function openInNewTab(url?: string): Promise<void> {
  if (url) {
    await execFileAsync("/usr/bin/open", ["-b", BUNDLE_ID, url]);
    return;
  }
  await jxa(`
    function run() {
      const a = Application("Ardia");
      a.activate();
      if (a.windows.length === 0) a.make({ new: "window" });
      else a.make({ new: "tab" }).focus();
    }`);
}

export async function newWindow(incognito: boolean): Promise<void> {
  await jxa(
    `function run([incognito]) {
      const a = Application("Ardia");
      a.activate();
      a.make({ new: "window", withProperties: { incognito: incognito === "true" } });
    }`,
    String(incognito),
  );
}

export async function currentTabUrl(): Promise<string | undefined> {
  return jxa<string | undefined>(`
    function run() {
      const a = Application("Ardia");
      if (!a.running() || a.windows.length === 0) return "";
      return JSON.stringify(a.windows[0].activeTab.url());
    }`);
}

// 入力が URL らしければそのまま、そうでなければ検索の URL にする
export function toUrl(input: string): string {
  const s = input.trim();
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(s)) return s;
  if (/^localhost(:\d+)?(\/.*)?$/i.test(s)) return `http://${s}`;
  if (!/\s/.test(s) && /^[\w-]+(\.[\w-]+)+(:\d+)?(\/.*)?$/i.test(s)) return `https://${s}`;
  return `https://www.google.com/search?q=${encodeURIComponent(s)}`;
}

// プロファイル ID "default" は Chromium の "Default"、それ以外は "Profile <id>" のディレクトリに対応する
function profileDir(profile: Profile): string {
  return join(DATA_DIR, profile.id === "default" ? "Default" : `Profile ${profile.id}`);
}

export type HistoryItem = {
  id: string;
  url: string;
  title: string;
  lastVisit: Date;
  profile: Profile;
};

// Chromium の時刻は 1601-01-01 からのマイクロ秒
const CHROMIUM_EPOCH_OFFSET_US = 11644473600000000;

// 起動中の Ardia がロックしているため immutable で開く（ブラウザの書き込み中でも読める）
export async function searchHistory(profile: Profile, text: string, limit = 100): Promise<HistoryItem[]> {
  const db = `file:${join(profileDir(profile), "History")}?immutable=1`;
  const like = `%${text.replace(/'/g, "''")}%`;
  const where = text ? `where title like '${like}' or url like '${like}'` : "";
  const sql = `select id, url, title, last_visit_time from urls ${where} order by last_visit_time desc limit ${limit}`;
  const { stdout } = await execFileAsync("/usr/bin/sqlite3", ["-json", db, sql], { maxBuffer: 16 * 1024 * 1024 });
  const rows: { id: number; url: string; title: string; last_visit_time: number }[] = stdout.trim()
    ? JSON.parse(stdout)
    : [];
  return rows.map((r) => ({
    id: `${profile.id}:${r.id}`,
    url: r.url,
    title: r.title || r.url,
    lastVisit: new Date((r.last_visit_time - CHROMIUM_EPOCH_OFFSET_US) / 1000),
    profile,
  }));
}

export type Bookmark = {
  id: string;
  url: string;
  title: string;
  folder: string;
  profile: Profile;
};

type BookmarkNode = { type: "url" | "folder"; id: string; name: string; url?: string; children?: BookmarkNode[] };

export async function listBookmarks(profile: Profile): Promise<Bookmark[]> {
  let json: { roots: Record<string, BookmarkNode> };
  try {
    json = JSON.parse(await readFile(join(profileDir(profile), "Bookmarks"), "utf8"));
  } catch {
    return [];
  }
  const out: Bookmark[] = [];
  const walk = (node: BookmarkNode, path: string[]) => {
    if (node.type === "url" && node.url) {
      out.push({ id: `${profile.id}:${node.id}`, url: node.url, title: node.name || node.url, folder: path.join(" / "), profile });
    }
    for (const child of node.children ?? []) walk(child, node.type === "folder" ? [...path, node.name] : path);
  };
  for (const root of Object.values(json.roots)) if (root && typeof root === "object") walk(root, []);
  return out;
}
