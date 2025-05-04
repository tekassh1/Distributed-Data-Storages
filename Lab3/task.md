- раскомментируем строчки в `pg_hba.conf`, чтобы репликация была доступна с `localhost`

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
host    all             all             0.0.0.0/0               password
# IPv6 local connections:
host    all             all             ::0/0                   password
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     trust
host    replication     all             127.0.0.1/32            trust
host    replication     all             ::1/128                 trust
```

Напишем скрипт бекапа
```
#pg_backup1.sh
...

```

Добавим скрипт на автоматическое исполнение в `cron`

```
crontab -e

0 */12 * * * /var/db/postgres1/pg_backup1.sh

```

Средний объем новых данных в БД за сутки: 50МБ.

Считаем, что в первые сутки у нас 50МБ данных
Данные поступают в течении 30 дней, и объем прироста за копию составляет 50МБ
Всего у нас 30 * 2 = 60 резервных копий в месяц
За месяц объем архива будет составлять 30 * 50 МБ = 1500 МБ = 1.5 ГБ

`30 * (50 + 1500) / 2 = 23250 МБ`

Тк у нас создаётся 2 копии в сутки, имеем дубликаты:

`23250 * 2 = 46500 МБ = 46.5 ГБ` - за месяц

Средний объем измененных данных за сутки: 300МБ. (записи в WAL)

`30 * (300 + 9000) / 2 = 139500 МБ`


Тк у нас создаётся 2 копии в сутки, имеем дубликаты:

`139500 * 2 = 279000 МБ = 279 ГБ` - за месяц
