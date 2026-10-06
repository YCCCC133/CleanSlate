#!/bin/zsh

case "${1:-}" in
  '') ;;
  --dry-run) ;;
  -h|--help) print -- '用法：一键退出并深度清理_v2.command [--dry-run]'; exit 0 ;;
  *) print -u2 -- "未知参数：$1"; exit 2 ;;
esac
(( $# <= 1 )) || { print -u2 -- '参数过多。'; exit 2; }


# macOS 一键退出应用 + 深度清理 v2
# 特点：前台执行、实时显示操作、绝不主动退出当前终端、无 sudo、无后台 nohup。
# 不删除：桌面/下载/文档/照片/钥匙串/浏览器书签/密码/Cookie/废纸篓等个人数据。

setopt NULL_GLOB
setopt NO_NOMATCH

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

HOME_DIR="$HOME"
USER_UID=$(/usr/bin/id -u)
TMP_DIR="${TMPDIR:-/tmp}"
START_FREE_KB=$(/bin/df -k "$HOME_DIR" 2>/dev/null | /usr/bin/awk 'NR==2 {print $4}')
[[ "$START_FREE_KB" == <-> ]] || START_FREE_KB=0

print_line() { /bin/echo "────────────────────────────────────────────────────────"; }
ts() { /bin/date '+%H:%M:%S'; }
info() { /bin/echo "[$(ts)]  $*"; }
ok()   { /bin/echo "[$(ts)]  ✓ $*"; }
skip() { /bin/echo "[$(ts)]  ↳ $*"; }
warn() { /bin/echo "[$(ts)]  ! $*"; }

human_kb() {
  local kb="${1:-0}"
  [[ "$kb" == <-> ]] || kb=0
  if (( kb >= 1048576 )); then
    /usr/bin/awk -v k="$kb" 'BEGIN {printf "%.2f GB", k/1048576}'
  elif (( kb >= 1024 )); then
    /usr/bin/awk -v k="$kb" 'BEGIN {printf "%.1f MB", k/1024}'
  else
    /bin/echo "${kb} KB"
  fi
}

dir_kb() {
  local p="$1" v
  [[ -e "$p" ]] || { /bin/echo 0; return; }
  v=$(/usr/bin/du -sk "$p" 2>/dev/null | /usr/bin/awk 'NR==1 {print $1}')
  [[ "$v" == <-> ]] || v=0
  /bin/echo "$v"
}

safe_clean_contents() {
  local dir="$1"
  local label="$2"
  local before after freed

  [[ -d "$dir" ]] || { skip "$label：不存在，跳过"; return 0; }

  # 只允许明确属于缓存/日志/临时/开发构建缓存的路径。
  case "$dir" in
    "$HOME_DIR/Library/Caches"|\
    "$HOME_DIR/Library/Logs"|\
    "$HOME_DIR/.cache"|\
    "$HOME_DIR/.npm/_cacache"|\
    "$HOME_DIR/.npm/_logs"|\
    "$HOME_DIR/.yarn/cache"|\
    "$HOME_DIR/.gradle/caches"|\
    "$HOME_DIR/.gradle/daemon"|\
    "$HOME_DIR/Library/Developer/Xcode/DerivedData"|\
    "$HOME_DIR/Library/Developer/CoreSimulator/Caches"|\
    "$HOME_DIR/Library/Caches/Homebrew"|\
    "$HOME_DIR/Library/Caches/CocoaPods"|\
    "$HOME_DIR/Library/Containers/"*/Data/Library/Caches|\
    "$HOME_DIR/Library/Group Containers/"*/Library/Caches|\
    "$HOME_DIR/Library/Application Support/"*/Cache|\
    "$HOME_DIR/Library/Application Support/"*/Caches|\
    "$HOME_DIR/Library/Application Support/"*/"Code Cache"|\
    "$HOME_DIR/Library/Application Support/"*/GPUCache|\
    "$HOME_DIR/Library/Application Support/"*/CachedData|\
    "$HOME_DIR/Library/Application Support/"*/*/Cache|\
    "$HOME_DIR/Library/Application Support/"*/*/Caches|\
    "$HOME_DIR/Library/Application Support/"*/*/"Code Cache"|\
    "$HOME_DIR/Library/Application Support/"*/*/GPUCache|\
    "$HOME_DIR/Library/Application Support/"*/*/CachedData|\
    "$HOME_DIR/Library/Application Support/"*/*/*/Cache|\
    "$HOME_DIR/Library/Application Support/"*/*/*/Caches|\
    "$HOME_DIR/Library/Application Support/"*/*/*/"Code Cache"|\
    "$HOME_DIR/Library/Application Support/"*/*/*/GPUCache|\
    "$HOME_DIR/Library/Application Support/"*/*/*/CachedData)
      ;;
    *)
      warn "$label：安全检查未通过，已跳过：$dir"
      return 0
      ;;
  esac

  before=$(dir_kb "$dir")
  info "清理 $label（约 $(human_kb "$before")）"

  if (( DRY_RUN )); then
    skip "预览模式：未删除 $dir"
    return 0
  fi

  /usr/bin/find "$dir" -mindepth 1 -maxdepth 1 -exec /bin/rm -rf -- {} + 2>/dev/null || true
  after=$(dir_kb "$dir")
  freed=$(( before > after ? before - after : 0 ))
  ok "$label 完成，释放约 $(human_kb "$freed")"
}

clear
print_line
/bin/echo "        Mac 一键退出应用 + 深度清理 v2"
print_line
/bin/echo "• 当前终端不会被脚本结束"
/bin/echo "• 所有操作会实时显示在本窗口"
/bin/echo "• 不使用 sudo，不删除个人文件/密码/书签/Cookie"
(( DRY_RUN )) && /bin/echo "• 当前为 --dry-run 预览模式，不执行删除"
print_line

# 保存当前终端/脚本的祖先进程 PID，任何情况下都不结束它们。
typeset -a PROTECTED_PIDS
pid="$$"
while [[ "$pid" == <-> ]] && (( pid > 1 )); do
  PROTECTED_PIDS+=("$pid")
  parent=$(/bin/ps -p "$pid" -o ppid= 2>/dev/null | /usr/bin/tr -d ' ')
  [[ "$parent" == <-> ]] || break
  [[ "$parent" == "$pid" ]] && break
  pid="$parent"
done

is_protected_pid() {
  local target="$1" p
  for p in "${PROTECTED_PIDS[@]}"; do
    [[ "$target" == "$p" ]] && return 0
  done
  return 1
}

is_terminal_app() {
  local bundle="$1" name="$2"
  case "$bundle" in
    com.apple.Terminal|com.googlecode.iterm2|dev.warp.Warp-Stable|dev.warp.Warp|com.github.wez.wezterm|org.alacritty|net.kovidgoyal.kitty) return 0 ;;
  esac
  case "$name" in
    Terminal|终端|iTerm|iTerm2|Warp|WezTerm|Alacritty|kitty) return 0 ;;
  esac
  return 1
}

/bin/echo
/bin/echo "【1/7】退出可见应用（保留当前终端）"
print_line

APP_LIST=$(/usr/bin/osascript -l JavaScript <<'JXA' 2>/dev/null
ObjC.import('AppKit');
$.NSWorkspace.sharedWorkspace.runningApplications.js
  .filter(function (app) { return Number(app.activationPolicy) === 0; })
  .map(function (app) {
    var pid = Number(app.processIdentifier);
    var bid = ObjC.unwrap(app.bundleIdentifier) || '';
    var name = ObjC.unwrap(app.localizedName) || '未命名应用';
    return pid + '\t' + bid + '\t' + name;
  }).join('\n');
JXA
)

if [[ -z "$APP_LIST" ]]; then
  warn "未读取到可见应用列表，跳过退出应用步骤；缓存清理仍会继续"
else
  while IFS=$'\t' read -r app_pid app_bundle app_name; do
    [[ "$app_pid" == <-> ]] || continue

    if is_protected_pid "$app_pid" || is_terminal_app "$app_bundle" "$app_name"; then
      skip "保留：$app_name（当前/终端相关进程）"
      continue
    fi

    owner=$(/bin/ps -p "$app_pid" -o uid= 2>/dev/null | /usr/bin/tr -d ' ')
    [[ "$owner" == "$USER_UID" ]] || { skip "跳过非当前用户进程：$app_name"; continue; }

    if (( DRY_RUN )); then
      info "将退出：$app_name (PID $app_pid)"
    else
      info "正在退出：$app_name"
      /bin/kill -TERM "$app_pid" 2>/dev/null || true
    fi
  done <<< "$APP_LIST"
fi

if (( ! DRY_RUN )); then
  /bin/sleep 1
  ok "应用退出步骤完成；当前终端保持运行"
fi

/bin/echo
/bin/echo "【2/7】清理 macOS 用户缓存与日志"
print_line
safe_clean_contents "$HOME_DIR/Library/Caches" "用户缓存 ~/Library/Caches"
safe_clean_contents "$HOME_DIR/Library/Logs" "用户日志 ~/Library/Logs"
safe_clean_contents "$HOME_DIR/.cache" "通用缓存 ~/.cache"

/bin/echo
/bin/echo "【3/7】清理沙盒应用 / 浏览器 / Electron 缓存"
print_line
for d in "$HOME_DIR"/Library/Containers/*/Data/Library/Caches; do
  [[ -d "$d" ]] && safe_clean_contents "$d" "沙盒缓存：${d#$HOME_DIR/Library/Containers/}"
done
for d in "$HOME_DIR"/Library/Group\ Containers/*/Library/Caches; do
  [[ -d "$d" ]] && safe_clean_contents "$d" "共享容器缓存：${d#$HOME_DIR/Library/Group Containers/}"
done

APP_SUPPORT="$HOME_DIR/Library/Application Support"
if [[ -d "$APP_SUPPORT" ]]; then
  while IFS= read -r -d '' d; do
    safe_clean_contents "$d" "应用缓存：${d#$APP_SUPPORT/}"
  done < <(/usr/bin/find "$APP_SUPPORT" -mindepth 2 -maxdepth 4 -type d \
    \( -name Cache -o -name Caches -o -name 'Code Cache' -o -name GPUCache -o -name CachedData \) \
    -print0 2>/dev/null)
fi
ok "应用缓存扫描完成"

/bin/echo
/bin/echo "【4/7】清理开发工具缓存"
print_line
safe_clean_contents "$HOME_DIR/Library/Developer/Xcode/DerivedData" "Xcode DerivedData"
safe_clean_contents "$HOME_DIR/Library/Developer/CoreSimulator/Caches" "iOS Simulator 缓存"
safe_clean_contents "$HOME_DIR/Library/Caches/Homebrew" "Homebrew 下载缓存"
safe_clean_contents "$HOME_DIR/Library/Caches/CocoaPods" "CocoaPods 缓存"
safe_clean_contents "$HOME_DIR/.npm/_cacache" "npm 包缓存"
safe_clean_contents "$HOME_DIR/.npm/_logs" "npm 日志"
safe_clean_contents "$HOME_DIR/.yarn/cache" "Yarn 缓存"
safe_clean_contents "$HOME_DIR/.gradle/caches" "Gradle 缓存"
safe_clean_contents "$HOME_DIR/.gradle/daemon" "Gradle daemon 缓存"

if (( ! DRY_RUN )) && command -v pnpm >/dev/null 2>&1; then
  info "执行 pnpm store prune"
  pnpm store prune 2>&1 | /usr/bin/sed 's/^/    /' || true
  ok "pnpm 缓存整理完成"
else
  command -v pnpm >/dev/null 2>&1 || skip "未安装 pnpm"
fi

if (( ! DRY_RUN )) && command -v brew >/dev/null 2>&1; then
  info "执行 brew cleanup -s"
  HOMEBREW_NO_AUTO_UPDATE=1 brew cleanup -s 2>&1 | /usr/bin/sed 's/^/    /' || true
  ok "Homebrew 旧缓存/旧版本整理完成"
else
  command -v brew >/dev/null 2>&1 || skip "未安装 Homebrew"
fi

/bin/echo
/bin/echo "【5/7】清理当前用户临时文件"
print_line
if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
  resolved_tmp=$(cd "$TMP_DIR" 2>/dev/null && /bin/pwd -P)
  [[ -n "$resolved_tmp" ]] || resolved_tmp="$TMP_DIR"
  case "$resolved_tmp" in
    /private/var/folders/*|/var/folders/*|/private/tmp/*|/tmp/*)
      info "扫描临时目录：$resolved_tmp"
      if (( DRY_RUN )); then
        count=$(/usr/bin/find "$resolved_tmp" -mindepth 1 -maxdepth 1 -user "$USER_UID" -mmin +30 2>/dev/null | /usr/bin/wc -l | /usr/bin/tr -d ' ')
        info "将清理约 $count 个 30 分钟以上的临时项目"
      else
        /usr/bin/find "$resolved_tmp" -mindepth 1 -maxdepth 1 -user "$USER_UID" -mmin +30 -exec /bin/rm -rf -- {} + 2>/dev/null || true
        ok "临时文件清理完成（保留最近 30 分钟项目，避免影响当前终端）"
      fi
      ;;
    *) warn "TMPDIR 路径异常，出于安全原因跳过：$resolved_tmp" ;;
  esac
else
  skip "未发现当前用户临时目录"
fi

/bin/echo
/bin/echo "【6/7】刷新可安全重建的系统缓存"
print_line
if (( DRY_RUN )); then
  info "将重置 Quick Look 缩略图缓存"
else
  info "重置 Quick Look 缩略图缓存"
  /usr/bin/qlmanage -r cache >/dev/null 2>&1 || true
  /usr/bin/killall QuickLookUIService 2>/dev/null || true
  ok "Quick Look 缓存刷新完成"
fi

/bin/echo
/bin/echo "【7/7】完成统计"
print_line
END_FREE_KB=$(/bin/df -k "$HOME_DIR" 2>/dev/null | /usr/bin/awk 'NR==2 {print $4}')
[[ "$END_FREE_KB" == <-> ]] || END_FREE_KB="$START_FREE_KB"
GAIN_KB=$(( END_FREE_KB > START_FREE_KB ? END_FREE_KB - START_FREE_KB : 0 ))

if (( DRY_RUN )); then
  ok "预览完成：没有删除任何内容"
else
  ok "深度清理完成"
  /bin/echo "本次磁盘可用空间增加约：$(human_kb "$GAIN_KB")"
fi

/bin/echo
/bin/echo "安全保留：桌面、下载、文档、照片、钥匙串、浏览器密码/书签/Cookie、废纸篓。"
/bin/echo "当前终端没有被退出。"
print_line
/bin/echo "清理脚本已结束，现在进入正常 zsh 终端；窗口会继续保持打开。"
/bin/echo "可继续输入命令，或手动关闭窗口。"
print_line

# 关键：不 exit，不关闭这个终端；直接切换成正常交互式 zsh。
if [[ -t 0 && -t 1 ]]; then
  exec /bin/zsh -l
fi
