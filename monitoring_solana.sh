#!/bin/bash

# Проверка наличия имени узла и сети
if [ -z "$NODENAME" ]; then
    read -p "Enter node name: " NODENAME
fi
echo 'Your node name: ' $NODENAME
sleep 1

if [ -z "$CHAIN" ]; then
    read -p "testnet or mainnet???: " CHAIN
fi
echo 'Your chain is: ' $CHAIN
sleep 1

# Установка ключа и репозитория
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys D8FF8E1F7DF8B07E

echo "deb https://repos.influxdata.com/ubuntu bionic stable" | sudo tee /etc/apt/sources.list.d/influxdata.list

# Установка необходимых пакетов
sudo apt-get -y install gnupg1 gnupg2
sudo curl -sL https://repos.influxdata.com/influxdb.key | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install telegraf jq bc git

# Добавление пользователя telegraf в группы sudo и adm
sudo adduser telegraf sudo
sudo adduser telegraf adm

# Настройка sudo для пользователей telegraf и solana
echo "telegraf ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
echo "solana ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers

# Настройка telegraf
sudo cp /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.orig
sudo rm -rf /etc/telegraf/telegraf.conf

git clone https://github.com/stakeconomy/solanamonitoring/
cd solanamonitoring
git checkout 830f7ddeca92924dc8e2c557770031c15b33553c
chmod +x monitor.sh

cat <<EOF | sudo tee /etc/telegraf/telegraf.conf
[agent]
  hostname = "$NODENAME-$CHAIN"
  flush_interval = "15s"
  interval = "15s"

# Input Plugins
[[inputs.cpu]]
    percpu = true
    totalcpu = true
    collect_cpu_time = false
    report_active = false
[[inputs.disk]]
    ignore_fs = ["devtmpfs", "devfs"]
#[[inputs.io]]
[[inputs.mem]]
[[inputs.net]]
[[inputs.system]]
[[inputs.swap]]
[[inputs.netstat]]
[[inputs.processes]]
[[inputs.kernel]]
[[inputs.diskio]]

# Output Plugin InfluxDB
[[outputs.influxdb]]
  database = "metricsdb"
  urls = [ "http://metrics.stakeconomy.com:8086" ]
  username = "metrics"
  password = "password"

[[inputs.exec]]
  commands = ["sudo su -c '$HOME/solanamonitoring/monitor.sh' -s /bin/bash $USER"]
  interval = "30s"
  timeout = "30s"
  data_format = "influx"
  data_type = "integer"
EOF

sed -i.bak -e "s/^solanaPrice=\$(curl.*/solanaPrice=\$(curl -s 'https:\/\/api.margus.one\/solana\/price\/'| jq -r .price)/" $HOME/solanamonitoring/monitor.sh

sudo systemctl enable --now telegraf
sudo systemctl is-enabled telegraf
sudo systemctl restart telegraf
