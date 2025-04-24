#!/bin/bash

### Check user id (script MUST RUN as root user)
USER_ID=`id -u`

if [ $USER_ID -gt 0 ]; then
    echo "Must run as root user (or from sudo)"
    exit 1
fi

###
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NOCOLOR='\033[0m'
###




clear;
echo -e "${GREEN}WELCOME TO EXPASYS QUESTIONNAIRE STUDIO PRO INSTALLER (v2024.3.3) ${NOCOLOR}"



# Добавление недостающих путей в переменную PATH Ruben

# Функция для установки пакетов с использованием apt
install_packages() {
  for package in "$@"; do
    sudo apt install -y "$package"
  done
}

# Установка необходимых утилит, если они отсутствуют
echo "Установка необходимых утилит..."
install_packages libc-bin wget

# Проверяем и добавляем пути в переменную PATH для root в файле .bashrc
BASHRC_FILE="$HOME/.bashrc"

echo "Проверка и настройка переменной PATH..."

# Путевые переменные, которые нужно добавить
NEW_PATHS=(
    "/usr/local/sbin"
    "/usr/sbin"
    "/sbin"
)

# Проверка и добавление в .bashrc
for NEW_PATH in "${NEW_PATHS[@]}"; do
    # Проверка, если путь уже добавлен
    if ! grep -q "$NEW_PATH" "$BASHRC_FILE"; then
        echo "Добавление $NEW_PATH в $BASHRC_FILE"
        echo "export PATH=\$PATH:$NEW_PATH" >> "$BASHRC_FILE"
    else
        echo "$NEW_PATH уже есть в $BASHRC_FILE"
    fi
done

# Применение изменений
source "$BASHRC_FILE"

тилит ldconfig и start-stop-daemon
if ! command -v ldconfig &> /dev/null; then
    echo "ldconfig не найден, переустанавливаем libc-bin..."
    sudo apt install --reinstall -y libc-bin
fi

if ! command -v start-stop-daemon &> /dev/null; then
    echo "start-stop-daemon не найден. Убедитесь, что он установлен."
    # Если start-stop-daemon недоступен, возможно, нужно установить пакет
    # sudo apt install -y <пакет, который содержит start-stop-daemon, например, sysvinit-utils>
fi

# Обновите список пакетов
echo "Обновление списка пакетов..."
sudo apt update

# Установка необходимых утилит
echo "Установка необходимых утилит..."
install_packages libc-bin wget adduser

# Создайте системного пользователя
echo "Создание системного пользователя qspro..."
sudo adduser --system --no-create-home qspro






### Define variables for installer

IP=$(ip addr show | grep global | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
DEBIAN_ID=$(env -i bash -c '. /etc/os-release; echo $VERSION_ID')
DEBIAN_CODENAME=$(env -i bash -c '. /etc/os-release; echo $VERSION_CODENAME')
FONTS_DIR=/usr/local/share/fonts/truetype
PROTECTIONKEY=$(cat /proc/sys/kernel/random/uuid | sed -e 's/-//g')
QSPRO_SERVICENAME="qspro.service"
QSPRO_STATUS=$(systemctl is-active $QSPRO_SERVICENAME)
QSPRO_CONFIGFILE="/opt/qspro/appsettings.json"
QSPROUSER=qspro
QSPROUSER_PASSWORD=$(cat /proc/sys/kernel/random/uuid | sed -e 's/-//g')
POSTGRES_QSPRO_USER=qspro
POSTGRES_QSPRO_DATABASE=qspro
POSTGRES_QSPRO_PASSWORD=$(cat /proc/sys/kernel/random/uuid | sed -e 's/-//g')
INSTALLATION_LOG=/opt/qspro_install.log

function option1 {
	clear;
	read -p "Would you like to install Expasys Questionnaire Studio Pro? [Y/N] " QUESTION
                QUESTION=${QUESTION,,}
                if [ $QUESTION = y ]; then
			if [[ "$QSPRO_STATUS" == "active" || -f "$QSPRO_CONFIGFILE" ]]; then
				echo -e "${RED}Expasys Questionnaire Studio Pro is already installed. Exiting.${NOCOLOR}"
				exit 1
			else
				echo -e "${GREEN}INSTALLING Expasys Questionnaire Studio Pro ${NOCOLOR}"
				### Installing dependencies and fonts
				echo -e "${YELLOW} [!] Installing dependencies and fonts... ${NOCOLOR}"
				apt update && apt upgrade -y && apt install -y sudo curl debian-keyring debian-archive-keyring apt-transport-https zip gnupg gpg fontconfig
				if [[ ! -d "$FONTS_DIR" ]]; then
					wget https://repo.expasys.ru/fonts.zip
					unzip fonts.zip -d /usr/local/share/fonts/
					rm fonts.zip
					dpkg-reconfigure fontconfig
				fi
				echo -e "${GREEN} [v] Success. ${NOCOLOR}"
				### Add Qspro repository to apt
				echo -e "${YELLOW} [!] Add Expasys Questionnaire Studio Pro repository and installing QSPRO... ${NOCOLOR}"
				touch /etc/apt/sources.list.d/qspro.list
				if [ $DEBIAN_ID = 11 ]; then
					echo 'deb https://repo.expasys.ru bullseye main' > /etc/apt/sources.list.d/qspro.list
					wget --quiet -O - https://repo.expasys.ru/qspro.asc | apt-key add -
				else
					echo 'deb https://repo.expasys.ru bookworm main' > /etc/apt/sources.list.d/qspro.list
					wget --quiet -O - https://repo.expasys.ru/qspro.asc | apt-key add -
					cp /etc/apt/trusted.gpg /etc/apt/trusted.gpg.d/
				fi
                                ### Add official Microsoft dotnet repository to apt
                                echo -e "${YELLOW} [!] Add Microsoft dotnet repository... ${NOCOLOR}"
                                if [ $DEBIAN_ID = 11 ]; then
                                        wget https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
                                else
                                        wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
                                fi
                                dpkg -i packages-microsoft-prod.deb
                                rm packages-microsoft-prod.deb
                                echo -e "${GREEN} [v] Success. ${NOCOLOR}"
				### Install Qspro
				apt update && apt install -y qspro
				echo -e "${GREEN} [v] Success. ${NOCOLOR}"
				### Add parameters in sysctl.conf
				echo -e "${YELLOW} [!] Add some changes in sysctl.conf... ${NOCOLOR}"
				echo -e 'fs.inotify.max_user_instances=524288\nfs.inotify.max_user_watches=1048576\nfs.inotify.max_queued_events=163840' >> /etc/sysctl.conf
				echo -e "${GREEN} [v] Success. ${NOCOLOR}"
				### Change patameters in system.conf
				echo -e "${YELLOW} [!] Add some changes in system.conf... ${NOCOLOR}"
				echo 'DefaultTasksMax=infinity' >> /etc/systemd/system.conf
				echo -e "${GREEN} [v] Success. ${NOCOLOR}"
				### Add user/group qspro/qspro
				echo -e "${YELLOW} [!] Create systemuser qspro... ${NOCOLOR}"
				adduser --gecos Qspro --disabled-password "$QSPROUSER"
				echo "$QSPROUSER:$QSPROUSER_PASSWORD" | chpasswd
				### usermod -aG sudo "$QSPROUSER"
				echo -e "${GREEN} User $QSPROUSER added with password $QSPROUSER_PASSWORD ${NOCOLOR}"
				echo -e "${GREEN} [v] Success. ${NOCOLOR}"
				### Change Qspro directory permissions
				echo -e "${YELLOW} [!] Change qspro directory permissions... ${NOCOLOR}"
				chown -R qspro:qspro /opt/qspro
				echo -e "${GREEN} [v] Success. ${NOCOLOR}"
				### Create qspro.service
				echo -e "${YELLOW} [!] Create qspro.service... ${NOCOLOR}"
				touch /etc/systemd/system/qspro.service
				echo -e '[Unit]\nDescription=Expasys Questionnaire Studio Pro\n\n[Service]\nWorkingDirectory=/opt/qspro/\nExecStart=/usr/bin/dotnet ./QuestionnaireStudioPro.dll\nRestart=always\nRestartSec=10\nSyslogIdentifier=ExpasysQSPRO\nUser=qspro\nEnvironment=ASPNETCORE_ENVIRONMENT=Production\n\n[Install]\nWantedBy=multi-user.target' > /etc/systemd/system/qspro.service
				chmod 755 /etc/systemd/system/qspro.service
				systemctl daemon-reload
				echo -e "${GREEN} [v] Success. ${NOCOLOR}"
				### Add official Caddy reverse-proxy repository to apt
				echo -e "${YELLOW} [!] Add Caddy reverse-proxy repository and installing caddy... ${NOCOLOR}"
				#curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
				#curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
				wget https://repo.expasys.ru/caddy2-9-1.deb
				### Install caddy reverse-proxy
				dpkg -i caddy2-9-1.deb
				rm caddy2-9-1.deb
				#apt update && apt install -y caddy
				### Create caddy config
				echo -e "http://$IP:80 {\n		reverse_proxy 127.0.0.1:5000\n}" > /etc/caddy/Caddyfile
				### Caddy restart
				service caddy restart
				echo -e "${GREEN} [v] Success. ${NOCOLOR}"
				### Add official PostgreSQL repository to apt
				echo -e "${YELLOW} [!] Add PostgreSQL repository and installing postgresql-14 and pgbouncer... ${NOCOLOR}"
				touch /etc/apt/sources.list.d/pgdg.list
				if [ $DEBIAN_CODENAME = "bullseye" ]; then
					echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list
					wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
				else
					echo "deb http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list
					wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
				fi
				### Install PostgreSQL-14 and PGbouncer
				apt-get update && apt-get install -y postgresql-14 pgbouncer
				echo -e "${GREEN} [v] Success. ${NOCOLOR}"
				### Change postgresql.conf file
				echo -e "${YELLOW} [!] Add some changes in postgresql.conf, pgbouncer.ini and userlist.txt... ${NOCOLOR}"
				echo "log_timezone = 'Europe/Moscow'" >> /etc/postgresql/14/main/postgresql.conf
				echo "datestyle = 'iso, dmy'" >> /etc/postgresql/14/main/postgresql.conf
				echo "timezone = 'Europe/Moscow'" >> /etc/postgresql/14/main/postgresql.conf
				echo "client_encoding = 'UTF8'" >> /etc/postgresql/14/main/postgresql.conf
				### Change pg_hba.conf file
				echo -e '# Database administrative login by Unix domain socket\nlocal   all             postgres                                trust\n\n# TYPE  DATABASE        USER            ADDRESS                 METHOD\n\n# "local" is for Unix domain socket connections only\nlocal   all             all                                     peer\n# IPv4 local connections:\nhost    all             all             127.0.0.1/32            scram-sha-256\n# IPv6 local connections:\nhost    all             all             ::1/128                 scram-sha-256\n# Allow replication connections from localhost, by a user with the\n# replication privilege.\nlocal   replication     all                                     peer\nhost    replication     all             127.0.0.1/32            scram-sha-256\nhost    replication     all             ::1/128                 scram-sha-256' > /etc/postgresql/14/main/pg_hba.conf
				### Stop pgbouncer and restart postgres service
				service pgbouncer stop
				service postgresql restart
				### Add user qspro and create database qspro
				psql -U postgres -c "CREATE USER ${POSTGRES_QSPRO_USER} WITH PASSWORD '${POSTGRES_QSPRO_PASSWORD}';"
				psql -U postgres -c "CREATE DATABASE ${POSTGRES_QSPRO_DATABASE};"
				psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_QSPRO_DATABASE} TO ${POSTGRES_QSPRO_USER};"
				psql -U postgres -c "ALTER DATABASE ${POSTGRES_QSPRO_DATABASE} OWNER TO ${POSTGRES_QSPRO_USER};"
				psql -U postgres -c "ALTER ROLE ${POSTGRES_QSPRO_USER} CREATEROLE;"
				psql -U postgres -c "ALTER ROLE ${POSTGRES_QSPRO_USER} SUPERUSER;"
				### Add credentials to /etc/pgbouncer/userlist.txt
				echo "\"$POSTGRES_QSPRO_USER\" \"$POSTGRES_QSPRO_PASSWORD\"" > /etc/pgbouncer/userlist.txt
				### Change /etc/pgbouncer/pgbouncer.ini
				echo -e "[databases]\nqspro = host = 127.0.0.1 dbname=qspro port=5432 password=$POSTGRES_QSPRO_PASSWORD\n\n[pgbouncer]\nlogfile = /var/log/postgresql/pgbouncer.log\npidfile = /var/run/postgresql/pgbouncer.pid\nlisten_addr = 127.0.0.1\nlisten_port = 6432\nunix_socket_dir = /var/run/postgresql\nauth_type = md5\nauth_file = /etc/pgbouncer/userlist.txt\npool_mode = transaction\nmax_client_conn = 300\nmax_db_connections = 300\ndefault_pool_size = 30\nmin_pool_size = 5\nreserve_pool_size = 5\nlog_connections = 0\nlog_disconnections = 0\nlog_pooler_errors = 1\n\n;; Read additional config from other file\n;%include /etc/pgbouncer/pgbouncer-other.ini" > /etc/pgbouncer/pgbouncer.ini
				### Restart pgbouncer service
				service pgbouncer restart
				echo -e "${GREEN} [v] Success. ${NOCOLOR}"
				### Change connection string in /opt/qspro/appsettings.json
				echo -e "${YELLOW} [!] Add some changes in appsettings.json... ${NOCOLOR}"
                                #echo -e "{\n  \"Kestrel\": {\n    \"Endpoints\": {\n      \"MyHttpEndpoint\": {\n        \"Url\": \"http://*:5000\"\n      }\n    }\n  },\n  \"Data\": {\n    \"DefaultConnection\": {\n      \"ConnectionString\": \"Server=127.0.0.1;Port=6432;Database=$POSTGRES_QSPRO_DATABASE;User Id=$POSTGRES_QSPRO_USER;Password=$POSTGRES_QSPRO_PASSWORD;\"\n    }\n  },\n  \"ProxySettings\": {\n    \"UseProxy\": false,\n    \"ForwardLimit\": 1,\n    \"Proxies\": [ \"\" ]\n  },\n  \"FolderSettings\": {\n    \"UseAnotherContentDirectory\": false,\n    \"DirectoryPath\": \"\"\n  },\n  \"EnableClustering\": false,\n  \"EnableCodeAuthorization\": false,\n  \"DataProtectionKey\": \"$PROTECTIONKEY\",\n  \"CookieDomain\": \"\",\n  \"CookieName\": \"\",\n  \"ViewMode\": \"B-Data,copp\",\n \"Serilog\": {\n  \"Using\": [\n    \"Serilog.Sinks.PostgreSQL.Configuration\",\n    \"Serilog.Sinks.File\",\n    \"Serilog.Enrichers.ClientInfo\"\n  ],\n  \"MinimumLevel\": {\n    \"Default\": \"Information\",\n    \"Override\": {\n      \"Microsoft\": \"Error\",\n      \"Microsoft.Hosting.Lifetime\": \"Error\"\n    }\n  },\n  \"Enrich\": [\n    \"WithMachineName\",\n    \"WithClientIp\",\n    {\n      \"Name\": \"WithRequestHeader\",\n      \"Args\": { \"headerName\": \"User-Agent\" }\n    }\n  ],\n  \"WriteTo\": [\n    {\n      \"Name\": \"Console\",\n      \"Args\": {\n        \"theme\": \"Serilog.Sinks.SystemConsole.Themes.AnsiConsoleTheme::Code, Serilog.Sinks.Console\",\n        \"outputTemplate\": \"[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj} <s:{SourceContext}>{NewLine}{Exception}\"\n      }\n    },\n    {\n      \"Name\": \"PostgreSQL\",\n      \"Args\": {\n        \"connectionString\": \"Server=127.0.0.1;Port=6432;Database=$POSTGRES_QSPRO_DATABASE;User Id=$POSTGRES_QSPRO_USER;Password=$POSTGRES_QSPRO_PASSWORD;\",\n        \"tableName\": \"EventLogs\",\n        \"needAutoCreateTable\": true\n      }\n    },\n    {\n      \"Name\": \"File\",\n      \"Args\": {\n        \"path\": \"logs/log-.txt\",\n        \"rollingInterval\": \"Day\",\n        \"outputTemplate\": \"{NewLine}{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}]{NewLine}{Message:lj}{NewLine}{Exception}Properties: {Properties}{NewLine}\",\n        \"fileSizeLimitBytes\": 209715200,\n        \"retainedFileCountLimit\": 15,\n        \"shared\": true\n      }\n    }\n  ]\n},\n\"Columns\": {\n  \"Message\": \"RenderedMessageColumnWriter\",\n  \"MessageTemplate\": \"MessageTemplateColumnWriter\",\n  \"Level\": {\n    \"Name\": \"LevelColumnWriter\",\n    \"Args\": {\n      \"renderAsText\": true,\n      \"dbType\": \"Varchar\"\n    }\n  },\n  \"Timestamp\": \"TimestampColumnWriter\",\n  \"Exception\": \"ExceptionColumnWriter\",\n  \"Properties\": {\n    \"Name\": \"PropertiesColumnWriter\",\n    \"Args\": { \"dbType\": \"Json\" }\n  },\n  \"MachineName\": {\n    \"Name\": \"SinglePropertyColumnWriter\",\n    \"Args\": {\n      \"propertyName\": \"MachineName\",\n      \"writeMethod\": \"Raw\"\n    }\n  }\n},  \"Environment\": \"notContainer\",\n  \"Logging\": {\n    \"IncludeScopes\": false,\n    \"LogLevel\": {\n      \"Default\": \"Error\",\n      \"System\": \"Error\",\n      \"Microsoft\": \"Error\"\n    }\n    },\n  \"SecurityCodeGeneratorOptions\": {\n    \"SecurityCodeLength\": \"6\",\n    \"CharsCount\": \"6\",\n    \"UtfCharsStart\": \"65\",\n    \"UtfCharsEnd\": \"90\"\n  }\n}" > /opt/qspro/appsettings.json
				echo -e "{\n \"Kestrel\": {\n   \"Endpoints\": {\n     \"MyHttpEndpoint\": {\n       \"Url\": \"http://*:5000\"\n     }\n   }\n },\n \"ConnectionStrings\": {\n   \"DefaultConnection\": \"Server=127.0.0.1;Port=6432;Database=$POSTGRES_QSPRO_DATABASE;User Id=$POSTGRES_QSPRO_USER;Password=$POSTGRES_QSPRO_PASSWORD;\"\n },\n \"PostgreSqlAnalyticsString\": \"Server=[SERVER];Port=5432;Database=[DATABASE];User Id=[USER];Password=[PASSWORD];Search Path = [SCHEMA];\",\n \"DataProtectionKey\": \"$PROTECTIONKEY\",\n \"ViewMode\": \"B-Data\",\n \"EnableClustering\": false,\n \"Logging\": {\n   \"IncludeScopes\": false,\n   \"LogLevel\": {\n     \"Default\": \"Information\",\n     \"System\": \"Information\",\n     \"Microsoft\": \"Information\",\n     \"Microsoft.EntityFrameworkCore.Database.Command\": \"Information\"\n   }\n },\n \"EnableCodeAuthorization\": false,\n \"SecurityCodeGeneratorOptions\": {\n   \"SecurityCodeLength\": \"6\",\n   \"CharsCount\": \"6\",\n   \"UtfCharsStart\": \"65\",\n   \"UtfCharsEnd\": \"90\"\n },\n \"CookieDomain\": \"\",\n \"CookieName\": \"\",\n \"FolderSettings\": {\n   \"UseAnotherContentDirectory\": false,\n   \"DirectoryPath\": \"\"\n },\n \"ProxySettings\": {\n   \"UseProxy\": false,\n   \"ForwardLimit\": 1,\n   \"Proxies\": [\n     \"\"\n   ]\n },\n \"Serilog\": {\n   \"Using\": [\n     \"Serilog.Sinks.PostgreSQL.Configuration\",\n     \"Serilog.Sinks.File\",\n     \"Serilog.Enrichers.ClientInfo\"\n   ],\n   \"MinimumLevel\": {\n     \"Default\": \"Information\",\n     \"Override\": {\n       \"Microsoft\": \"Error\",\n       \"Microsoft.Hosting.Lifetime\": \"Error\"\n     }\n   },\n   \"Enrich\": [\n     \"WithMachineName\",\n     \"WithClientIp\",\n     {\n       \"Name\": \"WithRequestHeader\",\n       \"Args\": {\n         \"headerName\": \"User-Agent\"\n       }\n     }\n   ],\n   \"WriteTo\": [\n     {\n       \"Name\": \"Console\",\n       \"Args\": {\n         \"theme\": \"Serilog.Sinks.SystemConsole.Themes.AnsiConsoleTheme::Code, Serilog.Sinks.Console\",\n         \"outputTemplate\": \"[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj} <s:{SourceContext}>{NewLine}{Exception}\"\n       }\n     },\n     {\n       \"Name\": \"PostgreSQL\",\n       \"Args\": {\n         \"connectionString\": \"DefaultConnection\",\n         \"tableName\": \"EventLogs\",\n         \"needAutoCreateTable\": true\n       }\n     },\n     {\n       \"Name\": \"File\",\n       \"Args\": {\n         \"path\": \"logs/log-.txt\",\n         \"rollingInterval\": \"Day\",\n         \"outputTemplate\": \"{NewLine}{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}]{NewLine}{Message:lj}{NewLine}{Exception}Properties: {Properties}{NewLine}\",\n         \"fileSizeLimitBytes\": 209715200,\n         \"retainedFileCountLimit\": 15,\n         \"shared\": true\n       }\n     }\n   ]\n },\n \"Columns\": {\n   \"Message\": \"RenderedMessageColumnWriter\",\n   \"MessageTemplate\": \"MessageTemplateColumnWriter\",\n   \"Level\": {\n     \"Name\": \"LevelColumnWriter\",\n     \"Args\": {\n       \"renderAsText\": true,\n       \"dbType\": \"Varchar\"\n     }\n   },\n   \"Timestamp\": \"TimestampColumnWriter\",\n   \"Exception\": \"ExceptionColumnWriter\",\n   \"Properties\": {\n     \"Name\": \"PropertiesColumnWriter\",\n     \"Args\": {\n       \"dbType\": \"Json\"\n     }\n   },\n   \"MachineName\": {\n     \"Name\": \"SinglePropertyColumnWriter\",\n     \"Args\": {\n       \"propertyName\": \"MachineName\",\n       \"writeMethod\": \"Raw\"\n     }\n   }\n }\n}" > /opt/qspro/appsettings.json
				### Restart qspro.service
				systemctl enable qspro.service
				service qspro start
				echo -e "${GREEN} [v] Success. ${NOCOLOR}"
				### Add config file in /etc/apt/apt.conf.d/
				touch /etc/apt/apt.conf.d/99qspro
				echo -e "Dpkg::Options {\n  \"--force-confold\";\n}" > /etc/apt/apt.conf.d/99qspro
				### Add installation logfile
				touch /opt/qspro_install.log
				chmod 400 /opt/qspro_install.log
				echo -e '### Caddy reverse_proxy configuration (/etc/caddy/Caddyfile)\n' >> /opt/qspro_install.log
				cat /etc/caddy/Caddyfile >> /opt/qspro_install.log
				echo -e '\n### Pgbouncer main configuration (/etc/pgbouncer/pgbouncer.ini)\n' >> /opt/qspro_install.log
				cat /etc/pgbouncer/pgbouncer.ini >> /opt/qspro_install.log
				echo -e '\n### Pgbouncer access configuration (/etc/pgbouncer/userlist.txt)\n' >> /opt/qspro_install.log
				cat /etc/pgbouncer/userlist.txt >> /opt/qspro_install.log
				echo -e '\n### PostgreSQL access configuration (/etc/postgresql/14/main/pg_hba.conf)\n' >> /opt/qspro_install.log
				cat /etc/postgresql/14/main/pg_hba.conf >> /opt/qspro_install.log
				echo -e '\n### Expasys Questionnaire Studio Pro configuration (/opt/qspro/appsettings.json)\n' >> /opt/qspro_install.log
				cat /opt/qspro/appsettings.json >> /opt/qspro_install.log
				echo -e '\n### Other users and access configuration: \n' >> /opt/qspro_install.log
				echo -e " Expasys Questionnaire Studio Pro service user username: "$QSPROUSER"\n " >> /opt/qspro_install.log
				echo -e " Expasys Questionnaire Studio Pro service user password: "$QSPROUSER_PASSWORD"\n " >> /opt/qspro_install.log
				echo -e " PostgreSQL database name: qspro\n " >> /opt/qspro_install.log
				echo -e " PostgreSQL database user username: "$POSTGRES_QSPRO_USER"\n " >> /opt/qspro_install.log
				echo -e " PostgreSQL database user password: "$POSTGRES_QSPRO_PASSWORD"\n " >> /opt/qspro_install.log
				### Print final system configs
				clear
				echo -e "Congratulations! Expasys Questionnaire Studio Pro system was succesfully installed on server. Please go to ${GREEN}http://"$IP"/install${NOCOLOR} in your web-browser to initialize application"
				echo "Your system user for Expasys Questionnaire Studio Pro is $QSPROUSER with password $QSPROUSER_PASSWORD"
				echo "Your database user for PostgreSQL is qspro with password $POSTGRES_QSPRO_PASSWORD"
				echo "See more details about this installation in /opt/qspro_install.log"
			fi
		fi
                if [ $QUESTION = n ]; then
			clear
			echo -e "${YELLOW}CANCEL INSTALL ${NOCOLOR}"
		fi
                if [[ $QUESTION != y && $QUESTION != n ]]; then
			clear
			echo -e "Choose ${GREEN}Y${NOCOLOR} to start installation or ${RED}N${NOCOLOR} to exit from installation."
		fi
}

function option2 {
	clear;
	if [ -f "$INSTALLATION_LOG" ]; then
			echo -e "${GREEN}List of current Expasys Questionnaire Studio Pro and related components configurations. ${NOCOLOR}"
			cat /opt/qspro_install.log
		else
			echo -e "${YELLOW}Nothing to show. Expasys Questionnaire Studio Pro not installed.${NOCOLOR}"
	fi
}

function option3 {
	clear;
    echo -e "${GREEN}Check for system updates.${NOCOLOR}"
	apt update
}

function option4 {
	clear;
	read -p "Would you like to remove Expasys Questionnaire Studio Pro and related components? [Y/N] " QUESTION
		QUESTION=${QUESTION,,}
		if [ $QUESTION = y ]; then
			if [[ "$QSPRO_STATUS" == "active" || -f "$QSPRO_CONFIGFILE" ]]; then
				clear
				echo -e "${GREEN}REMOVING Expasys Questionnaire Studio Pro and related components! ${NOCOLOR}"
				systemctl disable qspro.service
				systemctl stop qspro.service
				apt purge -y qspro caddy pgbouncer postgresql-14
				apt autoremove -y
				rm -rf /opt/qspro
				rm /etc/apt/apt.conf.d/99qspro
				rm /opt/qspro_install.log
				echo -e "${GREEN}Expasys Questionnaire Studio Pro and related components succesfully uninstalled. ${NOCOLOR}"
			else
				echo -e "${RED}Nothing to remove. Exiting. ${NOCOLOR}"
				exit 1
			fi
		fi
		if [ $QUESTION = n ]; then
			echo -e "${YELLOW}CANCEL UNINSTALL ${NOCOLOR}"
		fi
		if [[ $QUESTION != y && $QUESTION != n ]]; then
			clear
			echo -e "Choose ${GREEN}Y${NOCOLOR} to start uninstall or ${RED}N${NOCOLOR} to exit from uninstall."
		fi
}

while true; do
    # Show menu
    echo "Choose option:"
    echo "1. Install Expasys Questionnaire Studio Pro "
    echo "2. Show current config "
    echo "3. Check for updates "
    echo "4. Delete Expasys Questionnaire Studio Pro "
    echo "0. Exit "

    # Select option from user
    read -p "Enter option number: " CHOICE

    case $CHOICE in
        1)
            option1
            ;;
        2)
            option2
            ;;
        3)
            option3
            ;;
        4)
            option4
            ;;
        0)
            echo -e "${GREEN}Exit from installer.${NOCOLOR}"
            exit 0
            ;;
        *)
            clear
		echo -e "${YELLOW}Wrong option number. Please, enter number 0 to 4.${NOCOLOR}"
            ;;


    esac
done
