# Установка KVM и libvirt

sudo apt update
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virtinst bridge-utils
sudo usermod -aG libvirt $(whoami)
newgrp libvirt

## Настройка DHCP для виртуальных машин

## Сохраняем в файл internal-net.xml
<network>
  <name>internal-net</name>
  <bridge name='virbr10' stp='on' delay='0'/>
  <ip address='192.168.100.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.100.100' end='192.168.100.200'/>
    </dhcp>
  </ip>
</network>

virsh net-define internal-net.xml
virsh net-autostart internal-net
virsh net-start internal-net

virsh list --all
virsh shutdown <vmname>


## Если надо удалить
virsh destroy <vm-name>
virsh undefine <vm-name>
rm /var/lib/libvirt/images/<vm-name>.qcow2

# Установим виртуальные машины

## Создадим диски

sudo qemu-img create -f qcow2 /var/lib/libvirt/images/postgres-A.qcow2 10G
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/postgres-B.qcow2 10G
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/postgres-C.qcow2 10G
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/postgres-client.qcow2 10G

## Установим виртуальные машины на основе дисков

virt-install \
  --name postgres-A \
  --ram 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/postgres-A.qcow2,format=qcow2 \
  --os-variant ubuntu24.04 \
  --cdrom /home/kuznecov/ITMO/DDB/Lab4/ubuntu-24.04.2-live-server-amd64.iso \
  --network network=internal-net \
  --graphics vnc

virt-install \
  --name postgres-B \
  --ram 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/postgres-B.qcow2,format=qcow2 \
  --os-variant ubuntu24.04 \
  --cdrom /home/kuznecov/ITMO/DDB/Lab4/ubuntu-24.04.2-live-server-amd64.iso \
  --network network=internal-net \
  --graphics vnc

virt-install \
  --name postgres-C \
  --ram 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/postgres-C.qcow2,format=qcow2 \
  --os-variant ubuntu24.04 \
  --cdrom /home/kuznecov/ITMO/DDB/Lab4/ubuntu-24.04.2-live-server-amd64.iso \
  --network network=internal-net \
  --graphics vnc

virt-install \
  --name postgres-client \
  --ram 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/postgres-client.qcow2,format=qcow2 \
  --os-variant ubuntu24.04 \
  --cdrom /home/kuznecov/ITMO/DDB/Lab4/ubuntu-24.04.2-live-server-amd64.iso \
  --network network=internal-net \
  --graphics vnc

postgres1: tekassh1@192.168.122.253
postgres2: tekassh1@192.168.122.198
postgres3: tekassh1@192.168.122.192
postgres-client: tekassh1@192.168.122.34
ыыы


# Начинаем настраивать кластеры

Сервер А (192.168.122.253):


sudo vim /etc/postgresql/16/main/postgresql.conf

```
  listen_addresses = '*'
  wal_level = replica
  max_wal_senders = 10
  synchronous_standby_names = 'postgres2'
  wal_keep_size = 64
  archive_mode = on
  archive_command = 'cp %p /var/lib/postgresql/16/main/archive/%f'
```

sudo mkdir -p /var/lib/postgresql/16/main/archive
sudo chown postgres:postgres /var/lib/postgresql/16/main/archive

sudo vim pg_hba.conf

host    replication     replicator      192.168.122.198/32     md5


psql

CREATE ROLE replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD 'replicator_pass';

sudo systemctl restart postgresql



Сервер B (192.168.122.198):

sudo systemctl stop postgresql

## Очищаем каталог кластера

sudo rm -rf /var/lib/postgresql/16/main
sudo mkdir /var/lib/postgresql/16/main

sudo chown -R postgres:postgres /var/lib/postgresql/16/main
sudo chmod -R 700 /var/lib/postgresql/16/main

sudo pg_basebackup -h 192.168.122.253 -D /var/lib/postgresql/16/main -U replicator -Fp -Xs -P -R

## Отредактируем postgresql.conf

```
  listen_addresses = '*'
  primary_conninfo = 'host=192.168.122.253 port=5432 user=replicator password=replicator_pass application_name=postgres2'
  synchronous_standby_names = ''
  hot_standby = on
```

## Отредактируем pg_hba.conf

```
host    replication     replicator     192.168.122.192/32     md5
```

sudo systemctl start postgresql
`sudo systemctl start postgresql@16-main` ?

Сервер C (192.168.122.192):

sudo systemctl stop postgresql

## Очищаем каталог кластера

sudo rm -rf /var/lib/postgresql/16/main
sudo mkdir /var/lib/postgresql/16/main

sudo chown -R postgres:postgres /var/lib/postgresql/16/main
sudo chmod -R 700 /var/lib/postgresql/16/main

sudo pg_basebackup -h 192.168.122.198 -D /var/lib/postgresql/16/main -U replicator -Fp -Xs -P -R

sudo vim /etc/postgresql/16/main/postgresql.conf
```
listen_addresses = '*'
primary_conninfo = 'host=192.168.122.198 port=5432 user=replicator password=replicator_pass application_name=postgres3'
hot_standby = on
```

sudo vim /etc/postgresql/16/main/pg_hba.conf
```
local   all             postgres                                md5

# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     md5
```

# Проверим репликацию на postgres1

SELECT * FROM pg_stat_replication;

Видим что репликация с postgres2 не синхронная и имя сервера не совпадает, зададим параметры вручную.

ALTER SYSTEM SET primary_conninfo = 
  'user=replicator password=replicator_pass host=192.168.122.253 port=5432 application_name=postgres2';

# Сервер Client для pgpool-II (tekassh1@192.168.122.192):

sudo apt install pgpool2 -y

sudo vim /etc/pgpool2/pgpool.conf

```
backend_hostname0 = '192.168.122.253'
backend_port0 = 5432
backend_weight0 = 1
backend_data_directory0 = '/var/lib/postgresql/16/main'
backend_flag0 = 'ALWAYS_PRIMARY'

backend_hostname1 = '192.168.122.198'
backend_port1 = 5432
backend_weight1 = 1
backend_data_directory1 = '/var/lib/postgresql/16/main'
backend_flag1 = 'ALLOW_TO_FAILOVER'

backend_hostname2 = '192.168.122.192'
backend_port2 = 5432
backend_weight2 = 1
backend_data_directory2 = '/var/lib/postgresql/16/main'
backend_flag2 = 'DISALLOW_TO_FAILOVER'


enable_pool_hba = on
pool_passwd = 'pool_passwd'

load_balance_mode = off
master_slave_mode = on
master_slave_sub_mode = 'stream'


#------------------------------------------------------------------------------
# HEALTH CHECK GLOBAL PARAMETERS
#------------------------------------------------------------------------------

health_check_period = 10
                                   # Health check period
                                   # Disabled (0) by default
#health_check_timeout = 20
                                   # Health check timeout
                                   # 0 means no timeout
health_check_user = 'postgres'
                                   # Health check user
health_check_password = 'postgres'
                                   # Password for health check user
                                   # Leaving it empty will make Pgpool-II to first look for the
                                   # Password in pool_passwd file before using the empty password

health_check_database = 'postgres'



# This is used when logging to stderr:
logging_collector = on
                                        # Enable capturing of stderr
                                        # into log files.
                                        # (change requires restart)

# -- Only used if logging_collector is on ---

log_directory = '/tmp/pgpool_logs'
                                        # directory where log files are written,
                                        # can be absolute
log_filename = 'pgpool-%Y-%m-%d_%H%M%S.log'


```

Узнаем IP на клиентской машине

ip a | grep inet

```
inet 127.0.0.1/8 scope host lo
inet6 ::1/128 scope host noprefixroute 
inet 192.168.122.34/24 metric 100 brd 192.168.122.255 scope global dynamic enp1s0
inet6 fe80::5054:ff:fede:969b/64 scope link 
```

настроим пароли для pgpool

sudo chown postgres:postgres /etc/pgpool2/pool_passwd
sudo chmod 640 /etc/pgpool2/pool_passwd
sudo chmod 644 /etc/pgpool2/pgpool.conf

tekassh1@postgres-client:~$ sudo pg_md5 --md5auth --username=postgres postgres
tekassh1@postgres-client:~$ sudo cat /etc/pgpool2/pool_passwd
postgres:md53175bce1d3201d16594cebf9d7eb3f9d

## Для всех машин разрешим подключение с клиента

Поменяем аутентификацию на всех нодах на md5, а так же добавим строку для подключения с сервера pgpool

postgresql.conf
```
password_encryption = md5
```

sudo vim /etc/postgresql/16/main/pg_hba.conf
```
host    all             all             192.168.122.34/32       md5
```


Убедимся в корректности алгоритма хеширования на всех нодах

SHOW password_encryption;

## Проверим статус pgpool

psql -h localhost -p 9999 -U postgres -c "show pool_nodes;"



# Проверим репликацию

Присоеденимся к БД через pgpool и создадим таблицы с данными

```
psql -p 9999 -U postgres

tekassh1@postgres-client:~$ psql -p 9999 -U postgres
psql (16.8 (Ubuntu 16.8-0ubuntu0.24.04.1))
Type "help" for help.

postgres=# \dt
Did not find any relations.
postgres=# CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    price NUMERIC
);
CREATE TABLE
postgres=# CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id),
    quantity INT,
    created_at TIMESTAMP DEFAULT now()
);
CREATE TABLE
postgres=# BEGIN;
BEGIN
postgres=*# INSERT INTO products (name, price) VALUES 
('Laptop', 1200.00), 
('Phone', 600.00);
INSERT 0 2
postgres=*# INSERT INTO orders (product_id, quantity) VALUES 
(1, 2), 
(2, 1);
INSERT 0 2
postgres=*# COMMIT;
COMMIT
postgres=# \dt
          List of relations
 Schema |   Name   | Type  |  Owner   
--------+----------+-------+----------
 public | orders   | table | postgres
 public | products | table | postgres
(2 rows)

postgres=# SELECT * FROM orders;
 id | product_id | quantity |         created_at         
----+------------+----------+----------------------------
  1 |          1 |        2 | 2025-05-19 09:40:17.585473
  2 |          2 |        1 | 2025-05-19 09:40:17.585473
(2 rows)

postgres=# SELECT * FROM products;
 id |  name  |  price  
----+--------+---------
  1 | Laptop | 1200.00
  2 | Phone  |  600.00
(2 rows)
```

Убеждаемся что на репликах всё продублировано

```
tekassh1@postgres1:~$ psql -U postgres
Password for user postgres: 
psql (16.8 (Ubuntu 16.8-0ubuntu0.24.04.1))
Type "help" for help.

postgres=# \dt
          List of relations
 Schema |   Name   | Type  |  Owner   
--------+----------+-------+----------
 public | orders   | table | postgres
 public | products | table | postgres
(2 rows)

postgres=# SELECT * FROM products;
 id |  name  |  price  
----+--------+---------
  1 | Laptop | 1200.00
  2 | Phone  |  600.00
(2 rows)

postgres=# SELECT * FROM orders;
 id | product_id | quantity |         created_at         
----+------------+----------+----------------------------
  1 |          1 |        2 | 2025-05-19 09:40:17.585473
  2 |          2 |        1 | 2025-05-19 09:40:17.585473
(2 rows)
```

=================
Debug
psql -U postgres -c "ALTER SYSTEM SET primary_conninfo TO 'host=192.168.122.198 port=5432 user=replicator password=replicator_pass application_name=postgres3';"
=================

Убеждаемся в задержке репликации

Проверка синхронности реплик

```
SELECT                  
  application_name,
  state,
  sync_state
FROM pg_stat_replication;
 application_name |   state   | sync_state 
------------------+-----------+------------
 postgres3        | streaming | async
(1 row)
```


Узел A:
```
postgres=# SELECT                         
  application_name,
  client_addr,
  state,
  sync_state,
  sent_lsn,
  write_lsn,
  flush_lsn,
  replay_lsn,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replication_lag_bytes,
  replay_lag
FROM pg_stat_replication;
 application_name |   client_addr   |   state   | sync_state |  sent_lsn  | write_lsn  | flush_lsn  | replay_lsn | replication_lag_bytes | replay_lag 
------------------+-----------------+-----------+------------+------------+------------+------------+------------+-----------------------+------------
 postgres2        | 192.168.122.198 | streaming | sync       | 0/29390EE0 | 0/29390EE0 | 0/29390EE0 | 0/29390EE0 |                     0 | 
(1 row)

```

replay_lag отсутствует

Узел B:

```
postgres=# SELECT                         
  application_name,
  client_addr,
  state,
  sync_state,
  sent_lsn,
  write_lsn,
  flush_lsn,
  replay_lsn,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replication_lag_bytes,
  replay_lag
FROM pg_stat_replication;
 application_name |   client_addr   |   state   | sync_state |  sent_lsn  | write_lsn  | flush_lsn  | replay_lsn | replication_lag_bytes |   replay_lag    
------------------+-----------------+-----------+------------+------------+------------+------------+------------+-----------------------+-----------------
 postgres3        | 192.168.122.192 | streaming | async      | 0/29390EA8 | 0/29390EA8 | 0/29390EA8 | 0/29390EA8 |                     0 | 00:00:00.041515
(1 row)

```

## Создаем клиентов

CREATE ROLE client1 WITH LOGIN PASSWORD 'client1_password';
CREATE ROLE client2 WITH LOGIN PASSWORD 'client2_password';

GRANT ALL PRIVILEGES ON DATABASE postgres TO client1;
GRANT ALL PRIVILEGES ON DATABASE postgres TO client2;

GRANT CREATE ON SCHEMA public TO client1;
GRANT CREATE ON SCHEMA public TO client2;


sudo pg_md5 --md5auth --username=client1 client1_password
sudo pg_md5 --md5auth --username=client2 client2_password





## Чтобы сделать up для всех

pcp_attach_node -h localhost -p 9898 -U postgres -n 0
pcp_attach_node -h localhost -p 9898 -U postgres -n 1
pcp_attach_node -h localhost -p 9898 -U postgres -n 2

# Балансировка нагрузки

По умолчанию балансировка у postgres идёт на уровне подключений, а не на уровне запросов, поэтому запросы с одного подключения
по умолчанию идут на одну ноду.
Чтобы убедиться в балансировке нагрузки, мы может создать несколько подключений и следить за распределением запросов делая
большое количество SELECT с разных подключений (например client1 и client2).

CREATE TABLE cats (id SERIAL PRIMARY KEY);
SELECT * FROM cats;

Либо же, указать в `/etc/pgpool2/pgpool.conf` backend_weight0/1/2 больший, чем у других нод, чтобы большая часть запросов шла к нему.


Отказоустойчивость с failover:

Настраиваем `/etc/pgpool2/pgpool.conf`:

```
#------------------------------------------------------------------------------
# FAILOVER AND FAILBACK
#------------------------------------------------------------------------------

failover_command = '/etc/pgpool2/failover.sh %d %h %p %D %m %H %P %M %r %R'
failover_on_backend_error = on
failover_on_backend_shutdown = off
```

Скрипт восстановления - `/etc/pgpool2/failover.sh`

Логи восстановления - `/var/log/pgpool/failover.log`

Проверка pgpool - `show pool_nodes;`

Проверка режиме кластера в данный момент - `SELECT pg_is_in_recovery();`

Сигнал что реплика - `touch /var/lib/postgresql/16/main/standby.signal`

Старт самого приложения `sudo systemctl start postgresql@16-main`

Проверка состояния реплик:

```
SELECT                  
  application_name,
  state,
  sync_state
FROM pg_stat_replication;
```


# Симуляция сбоя

tekassh1@postgres1:~$ sudo -u postgres -s
postgres@postgres1:/home/tekassh1$ cd /var/lib/postgresql/16/main
postgres@postgres1:~/16/main$ dd if=/dev/zero of=diskfill bs=1M status=progress

Видим что основной узел отказал:

```
tekassh1@postgres1:~$ psql -U postgres
postgres=# CREATE TABLE disk_test(id serial);
ERROR:  could not extend file "base/5/16491": No space left on device
HINT:  Check free disk space.
```

Видим сообщения об ошибках в /var/lib/postgresql/16/main/log

```
May 19 12:40:02 postgres1 postgresql@16-main[104234]: Error: /usr/lib/postgresql/16/bin/pg_ctl /usr/lib/postgresql/16/bin/pg_ctl start -D /var/lib/postgresql/16/main -l /var/log/postgresql/>
May 19 12:40:02 postgres1 postgresql@16-main[104234]: 2025-05-19 12:40:02.486 UTC [104239] FATAL:  could not write lock file "postmaster.pid": No space left on device
```

Останавливаем основной сервер

`sudo systemctl stop postgresql`

pgpool переключается на реплику сначала в режиме read-only, но через время ~10 сек появляется возможность записи

## Восстановление основной ноды

Удалим мусорные файлы

`sudo rm /var/lib/postgresql/16/main/diskfill`

```
sudo bash recover_from_replica.sh
pass1 - replicator_pass
```

* Скрипт recover_from_replica.sh:
```
#!/bin/bash

sudo systemctl stop postgresql
sudo rm -rf /var/lib/postgresql/16/main/*
sudo rm -rf /var/lib/postgresql/16/main
sudo -u postgres mkdir /var/lib/postgresql/16/main
sudo chmod 700 /var/lib/postgresql/16/main
sudo chown -R postgres:postgres /var/lib/postgresql/16/main
sudo -u postgres pg_basebackup -h 192.168.122.198 -D /var/lib/postgresql/16/main -U replicator -P -R

sudo systemctl start postgresql

sudo -u postgres /usr/lib/postgresql/16/bin/pg_ctl -D /var/lib/postgresql/16/main promote
```

(Сервер B) Убираем primary с сервера:

```
sudo bash recover_replica.sh
pass1 - replicator_pass
pass2 - postgres
```

* Скрипт `recover_replica.sh`
```
#!/bin/bash

sudo systemctl stop postgresql
sudo rm -rf /var/lib/postgresql/16/main/*
sudo rm -rf /var/lib/postgresql/16/main
sudo -u postgres mkdir /var/lib/postgresql/16/main
sudo chmod 700 /var/lib/postgresql/16/main
sudo chown -R postgres:postgres /var/lib/postgresql/16/main
sudo -u postgres pg_basebackup -h 192.168.122.253 -D /var/lib/postgresql/16/main -U replicator -P -R

sudo systemctl start postgresql
sudo -u postgres psql -c "ALTER SYSTEM SET primary_conninfo = 'user=replicator password=replicator_pass host=192.168.122.253 port=5432 application_name=postgres2';"
sudo systemctl restart postgresql
```


(Сервер C) Восстанавливаем реплику

```
sudo bash recover_replica.sh
pass1 - replicator_pass
pass2 - postgres
```

* Скрипт `recover_replica.sh`
```
#!/bin/bash

sudo systemctl stop postgresql
sudo rm -rf /var/lib/postgresql/16/main/*
sudo rm -rf /var/lib/postgresql/16/main
sudo -u postgres mkdir /var/lib/postgresql/16/main
sudo chmod 700 /var/lib/postgresql/16/main
sudo chown -R postgres:postgres /var/lib/postgresql/16/main
sudo -u postgres pg_basebackup -h 192.168.122.198 -D /var/lib/postgresql/16/main -U replicator -P -R

sudo systemctl start postgresql
sudo -u postgres psql -c "ALTER SYSTEM SET primary_conninfo = 'user=replicator password=replicator_pass host=192.168.122.198 port=5432 application_name=postgres3';"
sudo systemctl restart postgresql
```

## Клиентский сервер:

```
pcp_attach_node -h localhost -p 9898 -U postgres -n 0       # password - potsgres
pcp_attach_node -h localhost -p 9898 -U postgres -n 1
pcp_attach_node -h localhost -p 9898 -U postgres -n 2


psql -p 9999 -U postgres
show pool_nodes;
```