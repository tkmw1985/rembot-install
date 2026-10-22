# REM Bot — установка

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tkmw1985/rembot-install/main/install.sh)
```

Скрипт скачивает зашифрованный релиз (`rembot.enc`, AES-256, ключ из пароля через PBKDF2-SHA256,
600 000 итераций), спрашивает **пароль установки**, расшифровывает его на сервере и запускает установщик
REM Bot. Без пароля содержимое архива прочитать нельзя.

Требования: Ubuntu 20.04+ / Debian 10+, root.

Без вопросов о пароле (например, в своих скриптах):

```bash
REMBOT_PASSWORD='…' bash <(curl -fsSL https://raw.githubusercontent.com/tkmw1985/rembot-install/main/install.sh)
```
