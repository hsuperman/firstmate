#!/usr/bin/env bash
# Isolated executable-interface evidence for fm-pr-delivery.sh.
set -euo pipefail

root=$1
world=$(mktemp -d)
trap 'rm -rf "$world"' EXIT
home="$world/home"
fixture="$world/fixture"
fakebin="$world/fakebin"
mkdir -p "$home/state" "$home/data" "$home/projects/alpha" "$fixture/open" "$fixture/view" "$fakebin"
printf '%s\n' '- alpha [direct-PR] - delivery evidence' > "$home/data/projects.md"
git -C "$home/projects/alpha" init -q
git -C "$home/projects/alpha" config user.name evidence
git -C "$home/projects/alpha" config user.email evidence@example.invalid
git -C "$home/projects/alpha" commit --allow-empty -qm initial
git -C "$home/projects/alpha" remote add origin https://github.com/acme/alpha.git
printf '%s\n' \
  'window=fm-ship42' \
  "worktree=$home/projects/ship42" \
  'project=alpha' \
  'harness=codex' \
  'kind=ship' \
  'mode=direct-PR' \
  'yolo=on' \
  'pr=https://github.com/acme/alpha/pull/42' > "$home/state/ship42.meta"
printf '%s\n' '[{"number":42,"url":"https://github.com/acme/alpha/pull/42","headRefName":"fm/ship42","headRefOid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","baseRefName":"main","reviewDecision":"","mergeable":"MERGEABLE","statusCheckRollup":[{"conclusion":"SUCCESS","status":"COMPLETED"}]}]' > "$fixture/open/acme__alpha.json"
printf '%s\n' '{"number":42,"url":"https://github.com/acme/alpha/pull/42","headRefName":"fm/ship42","headRefOid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","baseRefName":"main","reviewDecision":"","mergeable":"MERGEABLE","statusCheckRollup":[{"conclusion":"SUCCESS","status":"COMPLETED"}],"reviewThreads":{"nodes":[]},"state":"OPEN"}' > "$fixture/view/acme__alpha-42.json"
cat > "$fakebin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
fixture=${FM_PR_DELIVERY_FIXTURE:?}
repo=''
num=''
owner=''
name=''
query=''
args=("$@")
i=0
while [ "$i" -lt "$#" ]; do
  case "${args[$i]}" in
    --repo) repo="${args[$((i+1))]}"; i=$((i+2)); continue ;;
    view) num="${args[$((i+1))]}"; i=$((i+2)); continue ;;
    owner=*) owner=${args[$i]#owner=}; i=$((i+1)); continue ;;
    name=*) name=${args[$i]#name=}; i=$((i+1)); continue ;;
    number=*) num=${args[$i]#number=}; i=$((i+1)); continue ;;
    query=*) query=${args[$i]#query=}; i=$((i+1)); continue ;;
  esac
  i=$((i+1))
done
if [ "${1:-}" = pr ] && [ "${2:-}" = list ]; then
  jq -c . "$fixture/open/acme__alpha.json"
  exit 0
fi
if [ "${1:-}" = api ] && [ "${2:-}" = graphql ]; then
  if [[ "$query" == *pullRequests* ]]; then
    printf '%s\n' '{"data":{"repository":{"pullRequests":{"nodes":[{"number":42}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}'
  else
    jq -c '{data:{repository:{pullRequest:{
      number, url, headRefName, headRefOid, baseRefName, reviewDecision, mergeable, state,
      author:(.author // {login:"author"}),
      commits:{nodes:[{commit:{statusCheckRollup:{contexts:{nodes:(.statusCheckRollup // []),pageInfo:{hasNextPage:false}}}}}]},
      reviews:(.reviews // {nodes:[],pageInfo:{hasPreviousPage:false}}),
      comments:(.comments // {nodes:[],pageInfo:{hasPreviousPage:false}}),
      reviewThreads:(.reviewThreads // {nodes:[]})
    }}}}' "$fixture/view/acme__alpha-42.json"
  fi
  exit 0
fi
exit 99
SH
chmod +x "$fakebin/gh"
env FM_ROOT_OVERRIDE="$root" FM_HOME="$home" FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" FM_PROJECTS_OVERRIDE="$home/projects" FM_PR_DELIVERY_SECS=60 FM_PR_DELIVERY_FIXTURE="$fixture" GH_BIN=gh PATH="$fakebin:$PATH" "$root/bin/fm-pr-delivery.sh" scan --startup
env FM_ROOT_OVERRIDE="$root" FM_HOME="$home" FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" FM_PROJECTS_OVERRIDE="$home/projects" FM_PR_DELIVERY_SECS=60 FM_PR_DELIVERY_FIXTURE="$fixture" GH_BIN=gh PATH="$fakebin:$PATH" "$root/bin/fm-pr-delivery.sh" show
