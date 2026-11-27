#!/usr/bin/env bash
# NRQL の結果を New Relic の staticChartUrl で PNG にして保存する。
# 使い方: nr-chart.sh <account_id> <chart_type> <out.png> <nrql>
#   chart_type: LINE, AREA, BAR, PIE など（NerdGraph の ChartImageType）
# 前提: newrelic CLI の profile（User API key）が設定済み、jq と curl がある。
set -euo pipefail

if [ $# -ne 4 ]; then
  echo "usage: $0 <account_id> <chart_type> <out.png> <nrql>" >&2
  exit 2
fi

account_id=$1
chart_type=$2
out=$3
nrql=$4

# shellcheck disable=SC2016 # GraphQL の変数なので展開しない
query='query($id: Int!, $nrql: Nrql!) {
  actor { account(id: $id) { nrql(query: $nrql) {
    staticChartUrl(chartType: '"$chart_type"', format: PNG, width: 1200, height: 500)
  } } }
}'
variables=$(jq -n --argjson id "$account_id" --arg nrql "$nrql" '{id: $id, nrql: $nrql}')

url=$(newrelic nerdgraph query "$query" --variables "$variables" |
  jq -r '(.data // .) | .actor.account.nrql.staticChartUrl // empty')

if [ -z "$url" ]; then
  echo "staticChartUrl を取得できなかった" >&2
  exit 1
fi

# staticChartUrl は有効期限付きなので、すぐにファイルへ保存する。
curl -fsSL -o "$out" "$url"
echo "$out"
