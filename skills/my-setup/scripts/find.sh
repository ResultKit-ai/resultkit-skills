#!/usr/bin/env bash
#
# Finds things in the caller's ResultKit setup by loose name. Read-only.
#
#   find.sh                   one line per company, busiest first
#   find.sh TERM [TERM...]    every team, project and 1:1 whose full path
#                             (company / team / project) contains ALL the terms;
#                             the words team, project, 1on1 pick the kind instead
#   find.sh count PROJECT_ID  every card in a project, counted by column and
#                             by status (reads all of them, never a sample)
#
# Runs through api.sh, so RESULTKIT_PROFILE / RESULTKIT_CONFIG pick the account.
set -euo pipefail

API="$(dirname "$0")/api.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Responses go to files, not variables: a big account's snapshot is larger than
# the longest argument Linux will pass to a command.
get() { # get PATH OUTFILE → body in OUTFILE, or an ERROR line and exit 1
  "$API" GET "$1" >"$TMP/raw"
  if [ "$(jq -r '.status' "$TMP/raw")" != "200" ]; then
    echo "ERROR GET $1: $(jq -c '{status, error}' "$TMP/raw")"
    exit 1
  fi
  jq -c '.body' "$TMP/raw" >"$2"
}

paged() { # paged PATH_WITH_QUERY OUTFILE → every page's .data as one array
  local page=1 pages=1
  : >"$TMP/pages"
  while [ "$page" -le "$pages" ]; do
    get "$1&per_page=100&page=$page" "$TMP/page"
    jq -c '.data' "$TMP/page" >>"$TMP/pages"
    pages=$(jq -r '.meta.total_pages // 1' "$TMP/page")
    page=$((page + 1))
  done
  jq -c -s 'add // []' "$TMP/pages" >"$2"
}

if [ "${1:-}" = "count" ]; then
  [ -n "${2:-}" ] || { echo "USAGE: find.sh count PROJECT_ID"; exit 1; }
  # depth=2 returns each column with every one of its cards nested inside.
  paged "/items/$2/children?depth=2" "$TMP/top"
  jq -r '
    if any(.[]; (.children | length) > 0) then
      # shortcut: a loose card sitting beside columns prints as an empty column; upgrade when a board mixes the two
      "cards\tcolumn\tstatus",
      ( .[] | .name as $c
        | if (.children | length) == 0 then "0\t\($c)\t-"
          else (.children | group_by(.status)[] | "\(length)\t\($c)\t\(.[0].status)") end ),
      "total cards: \([.[].children[]] | length)"
    else
      "cards\tstatus (this project has no columns)",
      ( group_by(.status)[] | "\(length)\t\(.[0].status)" ),
      "total cards: \(length)"
    end' "$TMP/top"
  exit 0
fi

get /users/me/context "$TMP/ctx"
paged "/1-on-1?scope=all" "$TMP/ones"

jq -r -n --slurpfile ctx "$TMP/ctx" --slurpfile ones "$TMP/ones" --args '
  ($ARGS.positional | map(ascii_downcase)) as $all
  # team / project / 1on1 pick the kind of line; every other word must appear in it.
  | ($all | map(select(IN("team", "project", "1on1", "1:1")) | if . == "1:1" then "1on1" else . end)) as $kinds
  | ($all - ["team", "project", "1on1", "1:1"]) as $terms
  | def hit: ascii_downcase as $l | all($terms[]; . as $t | $l | contains($t));
  $ctx[0].data.organizations as $orgs
  | $ones[0] as $ones
  | if ($all | length) == 0 then
      $orgs
      | map(. as $o | {
          line: "company \($o.id) | \($o.name) | \($o.role)",
          teams: ($o.teams | length),
          projects: ([$o.teams[].projects[]] | length),
          todos: ([$o.teams[].todos[]] | length),
          rocks: ([$o.teams[].rocks[]] | length),
          ones: ([$ones[] | select(any(.teams[]; .organization_id == $o.id))] | length)
        })
      | sort_by(-(.projects + .todos + .rocks + .ones))
      | .[]
      | "\(.line) | \(.teams) teams, \(.projects) projects, \(.todos) open to-dos of yours, \(.rocks) rocks, \(.ones) 1:1s"
    else
      (
        $orgs[] as $o
        | $o.teams[] as $t
        | (if $t.is_root then "\($o.name) (\($o.id))" else "\($o.name) (\($o.id)) / \($t.name) (\($t.id))" end) as $path
        | (
            "team \($t.id) | \($path) | \($t.framework // "no framework") | \($t.projects | length) projects",
            ( $t.projects[]
              | "project \(.id) | \($path) / \(.name) | columns: \([.children[] | "\(.name) \(.id)"] | join("; "))" )
          )
        | { l: ., h: . }
      ),
      (
        # A 1:1 line names its companies only; team names still count for matching.
        $ones[]
        | def who: ([.first_name, .last_name] | map(select(. != null and . != "")) | join(" ")) as $n | if $n == "" then (.login // "unnamed") else $n end;
        ([.teams[] | "\(.organization_name) (\(.organization_id))"] | unique | join(", ")) as $cos
        | "1on1 \(.id) | \(.persons.person1 | who) x \(.persons.person2 | who) | \(if $cos == "" then "no company on this 1:1" else $cos end)\(if .archived then " | archived" else "" end)" as $l
        | { l: $l, h: "\($l) \([.teams[] | .name] | join(" "))" }
      )
      | select(.h | hit)
      | select(($kinds | length) == 0 or ((.l | split(" ")[0]) as $k | ($kinds | index($k)) != null))
      | .l
    end
' "$@"
