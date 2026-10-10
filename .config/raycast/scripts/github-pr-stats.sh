#!/usr/bin/env bash
#
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title GitHub PR Stats
# @raycast.mode fullOutput
#
# Optional parameters:
# @raycast.icon 📊
# @raycast.packageName GitHub
# @raycast.argument1 { "type": "dropdown", "placeholder": "期間 (既定: 今週)", "optional": true, "data": [{ "title": "今週", "value": "this-week" }, { "title": "先週", "value": "last-week" }, { "title": "今月", "value": "this-month" }, { "title": "先月", "value": "last-month" }] }
# @raycast.description 所属orgを選び、期間内のPR作成数・レビュー数と各PRのリンクをコピー
#
# Documentation:
# @raycast.author mozumasu
# @raycast.authorURL https://raycast.com/mozumasu

set -euo pipefail

# Raycast の最小 PATH では nix / mise 管理のバイナリが見えないため明示的に追加する
export PATH="$HOME/.local/share/mise/shims:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$HOME/.nix-profile/bin:$PATH"
export LC_CTYPE=UTF-8

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI が見つかりません。PATH を確認してください。"
  exit 1
fi

# nix の coreutils と区別するため BSD date を明示する (-v による日付計算を使う)
bsd_date=/bin/date
midnight=(-v0H -v0M -v0S)
case "${1:-this-week}" in
  this-week)
    from=$($bsd_date -v-mon "${midnight[@]}" +%s)
    to=$($bsd_date +%s)
    ;;
  last-week)
    to=$($bsd_date -v-mon "${midnight[@]}" +%s)
    from=$((to - 7 * 24 * 60 * 60))
    ;;
  this-month)
    from=$($bsd_date -v1d "${midnight[@]}" +%s)
    to=$($bsd_date +%s)
    ;;
  last-month)
    from=$($bsd_date -v1d -v-1m "${midnight[@]}" +%s)
    to=$($bsd_date -v1d "${midnight[@]}" +%s)
    ;;
  *)
    echo "不明な期間です: $1"
    exit 1
    ;;
esac

orgs=()
while IFS= read -r o; do
  orgs+=("$o")
done < <(gh api user/orgs --paginate --jq '.[].login')
if [ ${#orgs[@]} -eq 0 ]; then
  echo "所属している org が見つかりません。"
  exit 1
fi

# Raycast の dropdown 引数は静的な選択肢しか持てないため、org は実行時にダイアログで選ぶ
# 引数で選択肢を渡す (do shell script は osascript の stdin を読めない)。前面に出すため System Events に表示させる
org=$(osascript - "${orgs[@]}" <<'APPLESCRIPT'
on run argv
  tell application "System Events"
    activate
    set picked to choose from list argv with prompt "集計する org を選択"
  end tell
  if picked is false then return ""
  return item 1 of picked
end run
APPLESCRIPT
)
if [ -z "$org" ]; then
  echo "キャンセルしました。"
  exit 0
fi

login=$(gh api user --jq .login)
from_iso=$($bsd_date -u -r "$from" +%Y-%m-%dT%H:%M:%SZ)
to_iso=$($bsd_date -u -r "$to" +%Y-%m-%dT%H:%M:%SZ)
# 終了日は表示上その日を含めたいので、終端が 0 時なら前日にする
label="$($bsd_date -r "$from" +%Y-%m-%d)〜$($bsd_date -r "$((to - 1))" +%Y-%m-%d)"

# contributionsCollection は private な org の貢献が restricted 扱いになり集計できないため、検索 API を使う
# shellcheck disable=SC2016 # GraphQL の変数であり shell の展開ではない
query='
query($q: String!, $login: String!, $endCursor: String) {
  search(query: $q, type: ISSUE, first: 100, after: $endCursor) {
    nodes {
      ... on PullRequest {
        title
        url
        reviews(author: $login, first: 100) { nodes { submittedAt state } }
      }
    }
    pageInfo { hasNextPage endCursor }
  }
}'

search() {
  gh api graphql --paginate --slurp -f query="$query" -f login="$login" -f q="$1" |
    jq '[.[].data.search.nodes[]]'
}

created=$(search "is:pr author:$login org:$org created:$from_iso..$to_iso")
# 検索はレビュー日時で絞れないため、期間以降に更新された PR を候補にしてレビュー日時で数える
reviewed=$(search "is:pr reviewed-by:$login -author:$login org:$org updated:>=$from_iso")

# Notion に貼ると <details> がトグルになるよう HTML を、他のアプリ向けにプレーンテキストを作る
# shellcheck disable=SC2016 # jq の変数であり shell の展開ではない
report=$(jq -n --argjson created "$created" --argjson reviewed "$reviewed" \
  --arg from "$from_iso" --arg to "$to_iso" --arg header "$org $label" '
  ($reviewed
    | map({title, url, n: ([.reviews.nodes[] | select(.state != "PENDING" and .submittedAt >= $from and .submittedAt < $to)] | length)})
    | map(select(.n > 0))) as $prs
  | ($created | map(. + {suffix: ""})) as $created_items
  | ($prs | map(. + {suffix: (if .n > 1 then " (\(.n)回)" else "" end)})) as $review_items
  | "PR作成: \($created | length)件" as $created_summary
  | "レビュー: \($prs | length)件 (計\($prs | map(.n) | add // 0)回)" as $review_summary
  | def text_section($summary; $items): [$summary, ($items[] | "- \(.title)\(.suffix) \(.url)")] | join("\n");
    def html_section($summary; $items):
      "<details><summary>\($summary | @html)</summary><ul>"
      + ($items | map("<li><a href=\"\(.url | @html)\">\(.title | @html)</a>\(.suffix | @html)</li>") | join(""))
      + "</ul></details>";
  {
    text: ([$header, text_section($created_summary; $created_items), "", text_section($review_summary; $review_items)] | join("\n")),
    html: ("<p>\($header | @html)</p>" + html_section($created_summary; $created_items) + html_section($review_summary; $review_items))
  }')

text=$(jq -r .text <<<"$report")
html=$(jq -r .html <<<"$report")

# pbcopy はプレーンテキストしか置けないため、NSPasteboard に HTML とテキストを両方置く
osascript -l JavaScript - "$html" "$text" <<'JXA' >/dev/null
ObjC.import("AppKit");
function run(argv) {
  const pb = $.NSPasteboard.generalPasteboard;
  pb.clearContents;
  pb.setStringForType(argv[0], "public.html");
  pb.setStringForType(argv[1], "public.utf8-plain-text");
}
JXA
printf '%s\n' "$text"
