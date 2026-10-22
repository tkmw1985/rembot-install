#!/usr/bin/env bash
# REM Bot — encrypted one-line installer.
#   bash <(curl -fsSL https://raw.githubusercontent.com/tkmw1985/rembot-install/main/install.sh)
# Downloads the encrypted release (rembot.enc), asks for the installer password, decrypts it
# locally and starts the REM Bot installer. Without the password the archive cannot be read.
set -Eeuo pipefail

REPO="${REMBOT_INSTALL_REPO:-tkmw1985/rembot-install}"
ASSET_URL="${REMBOT_ASSET_URL:-https://github.com/${REPO}/releases/latest/download}"
DEST="${REMBOT_SETUP_DIR:-/root/rembot-setup}"
TRIES=3

B='\033[1m'; G='\033[32m'; R='\033[31m'; Y='\033[33m'; C='\033[36m'; D='\033[2m'; N='\033[0m'
ok(){ printf "%b\n" "${G}  ✔${N} $*"; }
info(){ printf "%b\n" "${C}  ●${N} $*"; }
die(){ printf "%b\n" "${R}  ✖${N} $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Запустите от root: sudo bash <(curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh)"
# Works with both «bash <(curl …)» and «curl … | bash»: questions are always read from the terminal.
if (exec </dev/tty) 2>/dev/null; then TTY=/dev/tty; else TTY=/dev/stdin; fi

printf "%b\n" "${B}${C}REM Bot · зашифрованная установка${N}"
printf "%b\n" "${D}Источник: ${ASSET_URL}${N}"

need=()
for c in curl openssl tar sha256sum; do command -v "$c" >/dev/null 2>&1 || need+=("$c"); done
if [ "${#need[@]}" -gt 0 ]; then
  command -v apt-get >/dev/null 2>&1 || die "Не хватает: ${need[*]}"
  info "Устанавливаю: ${need[*]}"
  DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl openssl tar coreutils ca-certificates >/dev/null
fi
openssl enc -help 2>&1 | grep -q -- '-pbkdf2' || die "Нужен OpenSSL 1.1.1 или новее (Ubuntu 20.04+/Debian 10+)."

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
info "Загружаю зашифрованный релиз"
curl -fsSL --retry 3 -o "$tmp/rembot.enc" "$ASSET_URL/rembot.enc" || die "Не удалось скачать rembot.enc"
curl -fsSL --retry 3 -o "$tmp/rembot.enc.sha256" "$ASSET_URL/rembot.enc.sha256" || die "Не удалось скачать контрольную сумму"
( cd "$tmp" && sha256sum -c --status rembot.enc.sha256 ) || die "Файл повреждён при загрузке (контрольная сумма не совпала). Повторите."
ok "Загружено и проверено ($(du -h "$tmp/rembot.enc" | cut -f1))"

decrypt(){ openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 -in "$tmp/rembot.enc" -out "$tmp/rembot.tar.gz" -pass fd:3 3<<<"$1" 2>/dev/null && tar -tzf "$tmp/rembot.tar.gz" >/dev/null 2>&1; }

pass="${REMBOT_PASSWORD:-}"
if [ -n "$pass" ]; then
  decrypt "$pass" || die "Пароль из REMBOT_PASSWORD не подошёл."
else
  for i in $(seq 1 "$TRIES"); do
    printf "%b" "${B}Пароль установки${N}: "
    IFS= read -r pass <"$TTY" || die "Ввод прерван"
    if decrypt "$pass"; then break; fi
    rm -f "$tmp/rembot.tar.gz"
    [ "$i" -lt "$TRIES" ] && printf "%b\n" "${Y}  ⚠${N} Неверный пароль, осталось попыток: $((TRIES-i))" || die "Неверный пароль. Установка остановлена."
    sleep $((i*2))
  done
fi
unset pass REMBOT_PASSWORD
ok "Пароль принят"

mkdir -p "$DEST" && chmod 700 "$DEST"
tar -xzf "$tmp/rembot.tar.gz" -C "$DEST"
( cd "$DEST" && sha256sum -c --status MANIFEST.sha256 ) || die "Содержимое архива не прошло проверку целостности."
ver="$(cat "$DEST/VERSION" 2>/dev/null || echo '?')"
ok "REM Bot v${ver} распакован в ${DEST}"
chmod +x "$DEST/rembot-install.sh"
cd "$DEST"
exec bash "$DEST/rembot-install.sh" <"$TTY"
