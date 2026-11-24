## Шаблон для третьего ДЗ по ИПР

Условие дз доступно по [ссылке](https://github.com/Nikfilk2030/missing_semester_hse_cs/blob/main/2026/amcs/year_1/hw_3/README.md)

## Запуск

Перейдите в папку `app` и создайте `.env` по примеру:

```sh
cp .env.example .env
docker compose up -d --build
```

Приложение будет доступно на `http://localhost:8080`. Порт и приветствие можно изменить в `.env` (`HOST_PORT`, `PORT`, `GREETING`). Счётчик хранится в Redis и переживает перезапуск Compose. Для остановки используйте `docker compose down`; `docker compose down -v` удалит сохранённые данные.

Чтобы выполнить автоматические проверки уровня 10 (нужны Docker Compose, `curl` и POSIX shell), запустите из папки `app`:

```sh
./scripts/check.sh
```

Сценарий создаёт отдельный Compose-проект, проверяет сохранение и восстановление, делает архив данных рядом с папкой `app` и удаляет тестовые контейнеры и volume.
