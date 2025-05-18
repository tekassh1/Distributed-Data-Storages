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
backend_flag0 = 'ALLOW_TO_FAILOVER'

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

sudo -u postgres pg_md5 -m -u postgres postgres



## Для всех машин разрешим подключение с клиента

sudo vim /etc/postgresql/16/main/pg_hba.conf

Добавим в конец файла строку
host    all             all             192.168.122.34/32       scram-sha-256
