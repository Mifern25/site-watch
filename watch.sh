#!/bin/bash
# Checks the sites from OUTSIDE the server (the server's own watchers die with it).
# Telegram only on a change: down, then back up. State is state.txt in this repo.
set -u
SITES=${SITES:-"smartearningguide.online segjobs.in"}
now=$(date +%s); hm() { TZ=Asia/Kolkata date -d "@$1" '+%d %b %H:%M IST'; }
send() { [ -n "${TG_TOKEN:-}" ] && curl -s -m 20 -o /dev/null "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
  --data-urlencode "chat_id=$TG_CHAT" --data-urlencode "text=$1"; }
up() {  # 3 tries, 20 s apart: one slow answer is not an outage
  for i in 1 2 3; do
    c=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "https://$1/")
    [ "$c" -ge 200 ] && [ "$c" -lt 500 ] && return 0
    [ $i -lt 3 ] && sleep 20
  done; return 1; }

touch state.txt; changed=0; down=0; msg=""
for s in $SITES; do
  old=$(grep "^$s " state.txt | cut -d' ' -f2); since=$(grep "^$s " state.txt | cut -d' ' -f3)
  if up "$s"; then st=up; else st=down; down=$((down+1)); fi
  if [ "$st" != "${old:-up}" ]; then
    changed=1
    if [ $st = down ]; then msg+="DOWN: $s is not answering (checked from outside, 3 tries).
"; else msg+="BACK: $s is answering again (was down since $(hm ${since:-$now})).
"; fi
    since=$now
  fi
  echo "$s $st ${since:-$now}" >> state.new
done
mv state.new state.txt
[ $changed = 1 ] && [ $down = 2 ] && msg+="Both are down, so the server itself is probably off. Check the AIC panel first (payment due? stopped?)."
[ $changed = 1 ] && send "$msg"
[ "${TEST:-false}" = true ] && send "site-watch test: checked from GitHub, $(grep -c ' up ' state.txt) of 2 sites up."

# GitHub switches off schedules in repos with no commits for 60 days: commit on change or every 30 days
last=$(git log -1 --format=%ct)
if [ $changed = 1 ] || [ $((now - last)) -gt 2592000 ]; then
  git config user.name site-watch; git config user.email site-watch@users.noreply.github.com
  git add state.txt; git commit -qm "state $(hm $now)" --allow-empty && git push -q
fi
cat state.txt
