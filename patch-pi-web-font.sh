#!/usr/bin/env bash
# 调小 pi-web 中扩展 widget 面板的字号。
#
# 背景：pi-web 前端把扩展 widget 的字号写死为「14px + 聊天字体偏移」
# （CSS 规则 .extension-widget-content），pi 扩展只能提供文本，无法控制字号，
# 因此只能在 pi-web 的构建产物 CSS 上打补丁。
# 注意：pi-web 升级或重装后补丁会被覆盖，需要重跑本脚本。
#
# 用法：
#   ./patch-pi-web-font.sh              # 改成默认的 10px
#   ./patch-pi-web-font.sh 12px         # 自定义字号
#   ./patch-pi-web-font.sh --restore    # 还原（用首次备份）
#   PI_WEB_DIR=/path/to/pi-web ./patch-pi-web-font.sh
#
# 生效方式：浏览器硬刷新（Ctrl+Shift+R）；若未生效请重启 pi-web。

set -euo pipefail

DEFAULT_SIZE="10px"
size="$DEFAULT_SIZE"
restore=0

usage() {
	sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
	case "$arg" in
		--restore | -r) restore=1 ;;
		-h | --help)
			usage
			exit 0
			;;
		--*)
			echo "未知参数: $arg（用 --help 查看用法）" >&2
			exit 1
			;;
		*) size="$arg" ;;
	esac
done

# 定位已安装的 pi-web 包目录
find_pi_web_dir() {
	if [ -n "${PI_WEB_DIR:-}" ]; then
		printf '%s\n' "$PI_WEB_DIR"
		return 0
	fi
	local npm_root=""
	if [ -n "${npm_config_prefix:-}" ] && [ -d "${npm_config_prefix}/node_modules" ]; then
		npm_root="${npm_config_prefix}/node_modules"
	else
		npm_root="$(npm root -g 2>/dev/null || true)"
	fi
	[ -n "$npm_root" ] || return 1
	if command -v cygpath >/dev/null 2>&1; then
		npm_root="$(cygpath -u "$npm_root")"
	fi
	printf '%s\n' "$npm_root/@agegr/pi-web"
}

dir="$(find_pi_web_dir)" || {
	echo "无法定位全局 npm 目录，请用 PI_WEB_DIR 指定 pi-web 包目录" >&2
	exit 1
}
[ -d "$dir" ] || {
	echo "找不到 pi-web：$dir（可用 PI_WEB_DIR 指定）" >&2
	exit 1
}

# 收集所有含扩展 widget 样式的 CSS（生产构建产物）
targets=()
while IFS= read -r f; do
	[ -n "$f" ] && targets+=("$f")
done < <(grep -rl "extension-widget-content" "$dir/.next/static" --include='*.css' 2>/dev/null || true)

if [ "${#targets[@]}" -eq 0 ]; then
	echo "未找到含扩展 widget 样式的 CSS（$dir/.next/static）" >&2
	exit 1
fi

if [ "$restore" = 1 ]; then
	for f in "${targets[@]}"; do
		if [ -f "$f.bak-font" ]; then
			cp "$f.bak-font" "$f"
			echo "已还原: $f"
		else
			echo "无备份，跳过: $f"
		fi
	done
	echo "完成，硬刷新浏览器（Ctrl+Shift+R）。"
	exit 0
fi

for f in "${targets[@]}"; do
	[ -f "$f.bak-font" ] || cp "$f" "$f.bak-font" # 只备份首次的原始版本
	perl -0pi -e "s/(\.extension-widget-content\{[^}]*?font-size:)[^;}]+/\${1}${size}/" "$f"
	echo "已更新: $f -> font-size:$size"
done

echo "完成，硬刷新浏览器（Ctrl+Shift+R）；若未生效请重启 pi-web。"
