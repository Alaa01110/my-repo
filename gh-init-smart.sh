#!/data/data/com.termux/files/usr/bin/env bash
# gh-init-smart.sh — Smart GitHub init & push helper for Termux
# Usage: ./gh-init-smart.sh
# Logs: ./gh-init-smart.log

set -o pipefail

LOGFILE="./gh-init-smart.log"
exec 3>&1 1>>"${LOGFILE}" 2>&1

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }

echo "[$(timestamp)] --- gh-init-smart.sh started ---" >&3
echo "[$(timestamp)] Logging to ${LOGFILE}" >&3

# CONFIG — عدّل القيم دي لو حبّت
GIT_USER_NAME="Alaa01110"
GIT_USER_EMAIL="ngo0m0900@gmail.com"
DEFAULT_REMOTE="origin"
DEFAULT_BRANCH="main"
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

# 1) إعداد هوية Git على مستوى الجهاز (إن لم تكن مُعرفة)
git config --global user.name "${GIT_USER_NAME}" || { echo "[$(timestamp)] Failed to set git user.name" >&3; }
git config --global user.email "${GIT_USER_EMAIL}" || { echo "[$(timestamp)] Failed to set git user.email" >&3; }

echo "[$(timestamp)] Git identity set to: ${GIT_USER_NAME} <${GIT_USER_EMAIL}>" >&3

# 2) تأكد إننا داخل مستودع Git
if [ ! -d .git ]; then
  echo "[$(timestamp)] ERROR: This directory is not a git repository (no .git)." >&3
  echo "[$(timestamp)] Aborting." >&3
  exit 1
fi

# 3) شغّل ssh-agent وإضافة المفتاح لو موجود
if [ -f "${SSH_KEY_PATH}" ]; then
  echo "[$(timestamp)] Starting ssh-agent and adding key ${SSH_KEY_PATH}" >&3
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add "${SSH_KEY_PATH}" || echo "[$(timestamp)] Warning: ssh-add returned non-zero (maybe passphrase required)." >&3
else
  echo "[$(timestamp)] SSH key ${SSH_KEY_PATH} not found — continuing (you may need to add your key manually)." >&3
fi

# 4) اضمن وجود README.md
if [ ! -f README.md ]; then
  echo "# ${PWD##*/}" > README.md
  echo "[$(timestamp)] Created README.md" >&3
else
  echo "[$(timestamp)] README.md already exists" >&3
fi

# 5) اضف و commit
git add -A
if git diff --cached --quiet; then
  echo "[$(timestamp)] Nothing to commit (staged changes empty)." >&3
else
  git commit -m "Initial commit (via gh-init-smart.sh)" || {
    echo "[$(timestamp)] Commit failed — aborting." >&3
    exit 2
  }
  echo "[$(timestamp)] Commit created." >&3
fi

# 6) تغيير الفرع الحالي إلى main
git branch -M "${DEFAULT_BRANCH}" || echo "[$(timestamp)] Branch rename to ${DEFAULT_BRANCH} skipped or failed." >&3

# 7) تحقق من الريموت
REMOTE_URL=$(git remote get-url "${DEFAULT_REMOTE}" 2>/dev/null || true)
if [ -z "${REMOTE_URL}" ]; then
  echo "[$(timestamp)] ERROR: Remote '${DEFAULT_REMOTE}' not set." >&3
  echo "[$(timestamp)] Please add remote, e.g.:" >&3
  echo "git remote add ${DEFAULT_REMOTE} git@github.com:USERNAME/REPO.git" >&3
  exit 3
fi
echo "[$(timestamp)] Remote ${DEFAULT_REMOTE} => ${REMOTE_URL}" >&3

# 8) جلب من الريموت ومحاولة rebase إن احتاج
echo "[$(timestamp)] Fetching remote..." >&3
git fetch "${DEFAULT_REMOTE}" --prune || echo "[$(timestamp)] Warning: git fetch returned non-zero." >&3

# إذا كان هناك فرع رئيسي على الريموت، نحاول عمل pull --rebase لتجنب conflicts
if git ls-remote --heads "${REMOTE_URL}" "${DEFAULT_BRANCH}" | grep -q refs/heads/"${DEFAULT_BRANCH}"; then
  echo "[$(timestamp)] Remote has branch ${DEFAULT_BRANCH} — attempting git pull --rebase ${DEFAULT_REMOTE} ${DEFAULT_BRANCH}" >&3
  git pull --rebase "${DEFAULT_REMOTE}" "${DEFAULT_BRANCH}" || {
    echo "[$(timestamp)] git pull --rebase failed — attempting to continue. Resolve conflicts manually if any." >&3
  }
else
  echo "[$(timestamp)] Remote does not have branch ${DEFAULT_BRANCH} — will push new branch." >&3
fi

# 9) Push مع محاولات إعادة تجربة ذكية
MAX_RETRIES=3
TRY=1
while [ ${TRY} -le ${MAX_RETRIES} ]; do
  echo "[$(timestamp)] Attempt ${TRY} to push to ${DEFAULT_REMOTE}/${DEFAULT_BRANCH} ..." >&3
  if git push -u "${DEFAULT_REMOTE}" "${DEFAULT_BRANCH}"; then
    echo "[$(timestamp)] Push succeeded on attempt ${TRY}." >&3
    echo "[$(timestamp)] --- Completed successfully ---" >&3
    # Output tail of logfile to stdout for user convenience
    tail -n 200 "${LOGFILE}" >&3
    exit 0
  else
    echo "[$(timestamp)] Push failed on attempt ${TRY}." >&3
    # إذا كان سبب الفشل قد يكون conflicts أو تحديثات على الريموت، حاول إعادة جلب ثم إعادة rebase
    git fetch "${DEFAULT_REMOTE}" || true
    git pull --rebase "${DEFAULT_REMOTE}" "${DEFAULT_BRANCH}" || true
    TRY=$((TRY + 1))
    sleep 2
  fi
done

echo "[$(timestamp)] ERROR: All ${MAX_RETRIES} push attempts failed. Check ${LOGFILE} for details." >&3
exit 4
