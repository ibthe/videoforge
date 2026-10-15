# Сервер активации VideoForge

API принимает подписанный офлайн-ключ `VF1`, проверяет email, ID установки и окно активации (7 дней), а затем атомарно привязывает `licenseId` к одной установке в SQLite. Повтор с той же установкой возвращает прежнюю лицензию; другой ID получает HTTP 409. После активации выдаётся подписанный сервером токен `VFL1` на 365 дней с даты активации.

## Запуск для разработки

```bash
python -m venv .venv
. .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
export VF_ISSUER_PUBLIC_KEY=./keys/issuer_public.pem
export VF_SERVER_PRIVATE_KEY=./keys/server_private.pem
uvicorn app:app --host 127.0.0.1 --port 8000
```

На production разворачивать только за HTTPS reverse proxy (Caddy/nginx/облачный балансировщик) с действительным сертификатом. Не выставляйте порт 8000 напрямую в интернет. Подключите мониторинг, резервное копирование `/data/licenses.sqlite3`, rate limit на `/v1/activate`, firewall и обновление зависимостей. Endpoint не должен выдавать ключи и не имеет публичного endpoint выпуска.

## Ключи

- `keys/issuer_public.pem` — открытый ключ офлайн-издателя, нужен серверу для проверки ваучеров.
- `keys/server_private.pem` — секретный закрытый ключ сервера, нужен только серверу для подписи активированных лицензий. Хранить в secret manager/защищённом томе, не в репозитории.
- Приложение содержит только открытый ключ сервера.

База SQLite должна храниться на постоянном диске. При нескольких экземплярах API нужна общая транзакционная БД (например PostgreSQL) вместо локального SQLite.
