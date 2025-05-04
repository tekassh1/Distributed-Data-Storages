# Этап 1

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


# Этап 2

Проверяем состояние резервного кластера

```
> psql -p 9956 -d postgres

psql (16.4)
Введите "help", чтобы получить справку.

postgres=# \dt
Отношения не найдены.

```

Перейдем к восстановлению

Останавливаем кластер на резервном сервере

`pg_ctl -D $PGDATA stop`

Очищаем данные кластера

`rm -rf ~/wfe99/*`

Распаковываем содержимое резервной копии

`tar -xzf ~/backups/pg_backup_2025-05-04_20-16-12/base.tar.gz -C ~/wfe99`

Распаковываем содержимое WAL буферов

`tar -xzf ~/backups/pg_backup_2025-05-04_20-16-12/pg_wal.tar.gz -C ~/wfe99/pg_wal`

chown -R postgres2:postgres ~/wfe99
chmod 700 ~/wfe99

Сделаем доступной аутентификацию пользователю postgres1 по паролю в ph_hba.conf

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     md5
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

```
[postgres2@pg112 ~/wfe99]$ pg_ctl -D $PGDATA start
ожидание запуска сервера....2025-05-04 20:41:42.726 MSK [28170] СООБЩЕНИЕ:  передача вывода в протокол процессу сбора протоколов
2025-05-04 20:41:42.726 MSK [28170] ПОДСКАЗКА:  В дальнейшем протоколы будут выводиться в каталог "pg_log".
 готово
сервер запущен
[postgres2@pg112 ~/wfe99]$ psql -U postgres1 -p 9956 -d postgres
Пароль пользователя postgres1: 
psql (16.4)
Введите "help", чтобы получить справку.

postgres=# \dt
              Список отношений
 Схема  |     Имя     |   Тип   | Владелец  
--------+-------------+---------+-----------
 public | table_five  | таблица | postgres1
 public | table_four  | таблица | postgres1
 public | table_one   | таблица | postgres1
 public | table_three | таблица | postgres1
 public | table_two   | таблица | postgres1
(5 строк)

postgres=# SELECT * FROM table_one
postgres-# ;
 id | username | age | signup_date | is_active 
----+----------+-----+-------------+-----------
  1 | alice    |  25 | 2025-05-03  | t
  2 | bob      |  32 | 2025-04-29  | f
  3 | carol    |  29 | 2025-05-01  | t
  4 | dave     |  40 | 2025-04-24  | t
  5 | eve      |  22 | 2025-05-04  | f
(5 строк)

postgres=#
```

Как видим, восстановление прошло успешно, все таблицы на месте, целостность не нарушена

# Этап 3

Узнаем OID удаляемой таблицы

```
postgres=# SELECT oid, relname FROM pg_class WHERE relname = 'table_three';
  oid  |   relname   
-------+-------------
 16526 | table_three
(1 строка)
```

Узнаём oid базы `postgres`:

```
postgres=# SELECT oid, datname FROM pg_database WHERE datname = 'postgres';
 oid | datname  
-----+----------
   5 | postgres
(1 строка)
```

Остановим кластер:

`pg_ctl -D $PGDATA stop`

Удалим данные о таблице с диска

`rm -rf $PGDATA/base/5/16526`

Попробуем запустить кластер и повзаимодействовать с таблицей:

```
pg_ctl -D $PGDATA start
psql -d postgres -p 9956

postgres=# \dt
              Список отношений
 Схема  |     Имя     |   Тип   | Владелец  
--------+-------------+---------+-----------
 public | table_five  | таблица | postgres1
 public | table_four  | таблица | postgres1
 public | table_one   | таблица | postgres1
 public | table_three | таблица | postgres1
 public | table_two   | таблица | postgres1
(5 строк)

postgres=# SELECT * FROM table_three;
ОШИБКА:  не удалось открыть файл "base/5/16526": Нет такого файла или каталога
```

Как видим - таблица недоступна, перезапуск не помогает

Начнём восстановление из резервной копии

создадим новый tablespace

mkdir new_tablespace
chown postgres1:postgres new_tablespace/

Восстановим кластер из бэкапа

```
tar -xzf backups/pg_backup_2025-05-04_20-16-12/base.tar.gz -C $PGDATA/
tar -xzf backups/pg_backup_2025-05-04_20-16-12/pg_wal.tar.gz -C $PGDATA/pg_wal

[postgres1@pg118 ~]$ ls -l $PGDATA/pg_tblspc/
total 1
lrwx------  1 postgres1 postgres 23  4 мая   21:42 16388 -> /var/db/postgres1/yjr62
```

Удалим ссылку на предыдущий tablespace

`rm $PGDATA/pg_tblspc/16388`

Создадим новую

`ln -s $HOME/new_tablespace $PGDATA/pg_tblspc/16388`

Восстановим данные tablespace из бэкапа в новую директорию

`tar -xzf backups/pg_backup_2025-05-04_20-16-12/16388.tar.gz -C new_tablespace/`

Отредактируем `restore_command` в `postgresql.conf`

```
# - Archive Recovery -

# These are only used in recovery mode.

restore_command = 'cp /var/db/postgres1/wal_restore/%f %p'
```

Создадим сигнал восстановления

`touch wfe99/recovery.signal`

Теперь после подключения к БД, видим, что таблица восстановлена и корректно работает

```
[postgres1@pg118 ~]$ psql -p 9956 -d postgres
psql (16.4)
Введите "help", чтобы получить справку.

postgres=# \dt
              Список отношений
 Схема  |     Имя     |   Тип   | Владелец  
--------+-------------+---------+-----------
 public | table_five  | таблица | postgres1
 public | table_four  | таблица | postgres1
 public | table_one   | таблица | postgres1
 public | table_three | таблица | postgres1
 public | table_two   | таблица | postgres1
(5 строк)

postgres=# SELECT * FROM table_three;
 order_id | customer_name | total |   status   |         created_at         
----------+---------------+-------+------------+----------------------------
        1 | John Doe      |   100 | pending    | 2025-05-04 20:07:12.392736
        2 | Jane Smith    |   200 | shipped    | 2025-05-03 20:07:12.392736
        3 | Mike Black    |   150 | processing | 2025-05-02 20:07:12.392736
        4 | Anna White    |   250 | cancelled  | 2025-04-29 20:07:12.392736
        5 | Leo Green     |   300 | completed  | 2025-05-01 20:07:12.392736
(5 строк)
```