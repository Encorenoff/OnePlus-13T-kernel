#!/usr/bin/env bash
set -euo pipefail

KERNEL_DIR="${1:?Usage: apply_epicmann24_patches.sh <kernel_dir> <work_dir> <branch> <filter> <model> [summary_file]}"
WORK_DIR="${2:?Missing work_dir}"
EPIC_BRANCH="${3:-}"
EPIC_FILTER="${4:-all}"
OP_MODEL="${5:-OP13T}"
SUMMARY_FILE="${6:-}"

EPIC_REPO="https://github.com/epicmann24/android_kernel_common_oneplus_sm8750.git"
OPLUS_REPO="https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8750.git"
GIT_DIR="${WORK_DIR}/epicmann_git"
PATCH_DIR="${WORK_DIR}/epicmann_patches"

rm -rf "$WORK_DIR"
mkdir -p "$GIT_DIR" "$PATCH_DIR"

AUTH_HEADER=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  AUTH_HEADER=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

if [ -z "$EPIC_BRANCH" ]; then
  EPIC_BRANCH=$(curl -fsSL "${AUTH_HEADER[@]}" -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/epicmann24/android_kernel_common_oneplus_sm8750" \
    | jq -r '.default_branch // empty' || true)
  if [ -z "$EPIC_BRANCH" ]; then
    EPIC_BRANCH=$(git ls-remote --symref "$EPIC_REPO" HEAD | awk '/^ref:/ {sub("refs/heads/", "", $2); print $2; exit}')
  fi
fi

if [ -z "$EPIC_BRANCH" ]; then
  echo "::error::Не удалось определить ветку epicmann24/android_kernel_common_oneplus_sm8750"
  exit 1
fi

echo "[epicmann24] Repo:   $EPIC_REPO"
echo "[epicmann24] Branch: $EPIC_BRANCH"
echo "[epicmann24] Filter: $EPIC_FILTER"

git -C "$GIT_DIR" init -q
git -C "$GIT_DIR" remote add epic "$EPIC_REPO"
git -C "$GIT_DIR" remote add oplus "$OPLUS_REPO"
git -C "$GIT_DIR" fetch --no-tags epic "$EPIC_BRANCH"
EPIC_HEAD=$(git -C "$GIT_DIR" rev-parse FETCH_HEAD)
git -C "$GIT_DIR" branch -f epic_head "$EPIC_HEAD"

FILTER_CLEAN=$(echo "$EPIC_FILTER" | tr ',' ' ' | tr '[:upper:]' '[:lower:]')
read -r -a TOKENS <<< "$FILTER_CLEAN"
if [ "${#TOKENS[@]}" -eq 0 ]; then
  TOKENS=("all")
fi

ALL_EXPLICIT=true
for tok in "${TOKENS[@]}"; do
  if [[ ! "$tok" =~ ^[0-9a-f]{7,40}$ ]]; then
    ALL_EXPLICIT=false
    break
  fi
done

match_category() {
  local sha="$1"
  local subj="$2"
  local files="$3"
  local tok="$4"

  [[ "$tok" == "all" ]] && return 0
  if [[ "$tok" =~ ^[0-9a-f]{7,40}$ ]] && [[ "${sha,,}" == "${tok,,}"* ]]; then
    return 0
  fi

  case "$tok" in
    charging)
      echo "$subj $files" | grep -qiE '(charg|pps|ufcs|battery|capacity|buffer|vooc|svooc|oplus_chg|power/supply)' && return 0 ;;
    thermal)
      echo "$subj $files" | grep -qiE '(thermal|throttl|temp|tzone|cooling)' && return 0 ;;
    haptics)
      echo "$subj $files" | grep -qiE '(haptic|vibrat|aw86|richtap|oplus_haptic)' && return 0 ;;
    wakelock)
      echo "$subj $files" | grep -qiE '(boeffla|wakelock|wakeup|suspend|s2idle|pm_wakeup)' && return 0 ;;
    sched)
      echo "$subj $files" | grep -qiE '(sched|bore|eevdf|walt|uclamp|cpufreq|cpuidle|hmbird|scx|kernel/sched)' && return 0 ;;
    mm)
      echo "$subj $files" | grep -qiE '(^mm/|zram|zswap|lz4|zstd|vmscan|mglru|kcompactd|slab|slub)' && return 0 ;;
    io)
      echo "$subj $files" | grep -qiE '(adios|^block/|ufs|f2fs|ext4|io_uring|elevator)' && return 0 ;;
    net)
      echo "$subj $files" | grep -qiE '(^net/|tcp|bbr|wireguard|bpf|nft|iptables|ttl|wlan|cnss)' && return 0 ;;
    display)
      echo "$subj $files" | grep -qiE '(drm|display|panel|dsi|kgsl|adreno|brightness|drivers/gpu)' && return 0 ;;
    *)
      echo "$subj $files" | grep -qiF "$tok" && return 0 ;;
  esac
  return 1
}

SELECTED_COMMITS=()

if [ "$ALL_EXPLICIT" = true ]; then
  echo "[epicmann24] Explicit SHA mode (${#TOKENS[@]} commits)"
  for sha in "${TOKENS[@]}"; do
    git -C "$GIT_DIR" cat-file -e "${sha}^{commit}" 2>/dev/null || git -C "$GIT_DIR" fetch --no-tags epic "$sha" || true
    full_sha=$(git -C "$GIT_DIR" rev-parse "$sha")
    SELECTED_COMMITS+=("$full_sha")
  done
else
  MODEL_SLUG=$(echo "${OP_MODEL#OP}" | tr '[:upper:]' '[:lower:]')
  CANDIDATE_BRANCHES=(
    "oneplus/sm8750_b_16.0.0_oneplus_${MODEL_SLUG}"
    "oneplus/sm8750_b_16.0.0_oneplus_13t"
    "oneplus/sm8750_b_16.0.0_oneplus_13s"
    "oneplus/sm8750_b_16.0.0_oneplus_13"
    "oneplus/sm8750_v_15.0.2_oneplus_13t"
    "oneplus/sm8750_v_15.0.0_oneplus_13"
  )

  BASE_SHA=""
  for ob in "${CANDIDATE_BRANCHES[@]}"; do
    if git -C "$GIT_DIR" fetch --no-tags oplus "$ob" 2>/dev/null; then
      BASE_SHA=$(git -C "$GIT_DIR" merge-base FETCH_HEAD epic_head 2>/dev/null || true)
      if [ -n "$BASE_SHA" ]; then
        echo "[epicmann24] Merge-base found: ${BASE_SHA:0:12} (against $ob)"
        break
      fi
    fi
  done

  if [ -n "$BASE_SHA" ]; then
    mapfile -t ALL_COMMITS < <(git -C "$GIT_DIR" rev-list --reverse --no-merges "${BASE_SHA}..epic_head")
  else
    echo "::warning::Общая ветка с OnePlusOSS не найдена, берём последние 200 коммитов epicmann24"
    mapfile -t ALL_COMMITS < <(git -C "$GIT_DIR" rev-list --reverse --no-merges -n 200 epic_head)
  fi

  for sha in "${ALL_COMMITS[@]}"; do
    subj=$(git -C "$GIT_DIR" log -1 --format=%s "$sha")
    if echo "$subj" | grep -qiE '(anykernel|localversion)'; then
      echo "  [SKIP] ${sha:0:8} $subj"
      continue
    fi

    files=$(git -C "$GIT_DIR" diff-tree --no-commit-id --name-only -r "$sha" | tr '\n' ' ')
    matched=false
    for tok in "${TOKENS[@]}"; do
      if match_category "$sha" "$subj" "$files" "$tok"; then
        matched=true
        break
      fi
    done

    if [ "$matched" = true ]; then
      SELECTED_COMMITS+=("$sha")
    fi
  done
fi

echo "[epicmann24] Selected ${#SELECTED_COMMITS[@]} commit(s)"

excluded_paths=(
  ':(exclude,icase)KernelSU*'
  ':(exclude,icase)drivers/kernelsu'
  ':(exclude)fs/susfs*'
  ':(exclude)include/linux/susfs*'
)
if [ -n "${SUSFS_PROTECTED_PATHS_FILE:-}" ]; then
  while IFS= read -r path; do
    excluded_paths+=(":(top,exclude,literal)$path")
  done < "$SUSFS_PROTECTED_PATHS_FILE"
fi

applied=0
already=0
conflicts=0
protected=0
APPLIED_LOG=""

idx=1
for sha in "${SELECTED_COMMITS[@]}"; do
  subj=$(git -C "$GIT_DIR" log -1 --format=%s "$sha")
  if grep -qiE '(kernelsu|sukisu|resukisu|bakasu|susfs|ksu[: _-])' <<< "$subj"; then
    protected=$((protected + 1))
    echo "  [SKIP-KSU/SUSFS] ${sha:0:8} $subj"
    continue
  fi
  pfile=$(printf "%s/%04d-%s.patch" "$PATCH_DIR" "$idx" "${sha:0:10}")
  idx=$((idx + 1))

  git -C "$GIT_DIR" format-patch -1 "$sha" --stdout --no-renames -- . "${excluded_paths[@]}" > "$pfile"

  if ! grep -q '^diff --git ' "$pfile"; then
    protected=$((protected + 1))
    echo "  [NO-PATCH] ${sha:0:8} $subj"
    rm -f "$pfile"
    continue
  fi

  if patch -d "$KERNEL_DIR" -p1 --forward --batch --fuzz=0 --dry-run -i "$pfile" >/dev/null 2>&1; then
    patch -d "$KERNEL_DIR" -p1 --forward --batch --fuzz=0 --no-backup-if-mismatch -i "$pfile" >/dev/null
    applied=$((applied + 1))
    APPLIED_LOG+="- \`${sha:0:8}\` (clean) ${subj}\n"
    echo "  ✅ [clean]  ${sha:0:8} $subj"
  elif patch -d "$KERNEL_DIR" -p1 --forward --batch --fuzz=3 --dry-run -i "$pfile" >/dev/null 2>&1; then
    patch -d "$KERNEL_DIR" -p1 --forward --batch --fuzz=3 --no-backup-if-mismatch -i "$pfile" >/dev/null
    applied=$((applied + 1))
    APPLIED_LOG+="- \`${sha:0:8}\` (fuzz=3) ${subj}\n"
    echo "  ⚠️  [fuzz=3] ${sha:0:8} $subj"
  elif patch -d "$KERNEL_DIR" -p1 --reverse --batch --dry-run -i "$pfile" >/dev/null 2>&1; then
    already=$((already + 1))
    echo "  ℹ️  [already] ${sha:0:8} $subj"
  else
    conflicts=$((conflicts + 1))
    echo "  ❌ [conflict-skipped] ${sha:0:8} $subj"
  fi
done

find "$KERNEL_DIR" \( -name '*.rej' -o -name '*.orig' \) -delete || true
rm -rf "$GIT_DIR"

echo "[epicmann24] Done: applied=${applied}, already=${already}, conflicts_skipped=${conflicts}, protected_or_empty=${protected}"

if [ -n "$SUMMARY_FILE" ]; then
  {
    echo ""
    echo "### 🧩 Epicmann24 SM8750 Patches"
    echo ""
    echo "- **Branch:** \`${EPIC_BRANCH}\` (\`${EPIC_HEAD:0:10}\`)"
    echo "- **Filter:** \`${EPIC_FILTER}\`"
    echo "- **Result:** ✅ Applied: **${applied}** | ℹ️ Already present: **${already}** | ⚠️ Conflicts: **${conflicts}** | Protected or empty: **${protected}**"
    if [ -n "$APPLIED_LOG" ]; then
      echo ""
      echo "<details><summary>Applied Epicmann24 commits</summary>"
      echo ""
      echo -e "$APPLIED_LOG"
      echo "</details>"
    fi
  } >> "$SUMMARY_FILE"
fi
