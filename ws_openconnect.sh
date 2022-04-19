#!/bin/bash
cp /usr/share/zoneinfo/Asia/Dubai /etc/localtime

#Database Details
db_host='82.223.165.66';
db_user='xvpnbuild_vpn';
db_pass='xvpnbuild_vpn';
db_name='xvpnbuild_vpn';

install_require()
{
  clear
  echo "Updating your system."
  {
    apt-get -o Acquire::ForceIPv4=true update
  } &>/dev/null
  clear
  echo "Installing dependencies."
  {
    apt-get -o Acquire::ForceIPv4=true install stunnel4 squid ocserv -y
    apt-get -o Acquire::ForceIPv4=true install dos2unix nano curl unzip jq virt-what net-tools mysql-client -y
    apt-get -o Acquire::ForceIPv4=true install freeradius freeradius-mysql freeradius-utils python -y
    apt-get -o Acquire::ForceIPv4=true install gnutls-bin pwgen screen -y
  } &>/dev/null
}

install_freeradius()
{
clear
echo "Preparing authentication module."
{
  rm /etc/freeradius/3.0/sites-available/default
  rm /etc/freeradius/3.0/mods-available/sql
  rm /etc/freeradius/3.0/sites-available/inner-tunnel
  echo 'sql {

    dialect = "mysql"
    driver = "rlm_sql_mysql"

    sqlite {

      filename = "/tmp/freeradius.db"
      busy_timeout = 200
      bootstrap = "${modconfdir}/${..:name}/main/sqlite/schema.sql"

    }

    mysql {
      tls {
        #ca_file = "/etc/ssl/certs/my_ca.crt"
        #ca_path = "/etc/ssl/certs/"
        #certificate_file = "/etc/ssl/certs/private/client.crt"
        #private_key_file = "/etc/ssl/certs/private/client.key"
        #cipher = "DHE-RSA-AES256-SHA:AES128-SHA"

        tls_required = no
        tls_check_cert = no
        tls_check_cert_cn = no
      }

      warnings = auto
    }

    postgresql {

      send_application_name = yes

    }' >> /etc/freeradius/3.0/mods-available/sql
 echo "
    server = "$db_host"
    port = 3306
    login = "$db_user"
    password = "$db_pass"
    radius_db = "$db_name"
    " >> /etc/freeradius/3.0/mods-available/sql
 echo 'acct_table1 = "radacct"
   acct_table2 = "radacct"
   postauth_table = "radpostauth"
   authcheck_table = "radcheck"
   groupcheck_table = "radgroupcheck"
   authreply_table = "radreply"
   groupreply_table = "radgroupreply"
   usergroup_table = "radusergroup"
   delete_stale_sessions = yes

    pool {

      start = ${thread[pool].start_servers}
      min = ${thread[pool].min_spare_servers}
      max = ${thread[pool].max_servers}
      spare = 1
      uses = 1
      retry_delay = 30
      lifetime = 5
      idle_timeout = 10

    }

    read_clients = yes
    client_table = "nas"
    group_attribute = "SQL-Group"
    $INCLUDE ${modconfdir}/${.:name}/main/${dialect}/queries.conf
  }
' >> /etc/freeradius/3.0/mods-available/sql
  sudo ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/
  sudo chgrp -h freerad /etc/freeradius/3.0/mods-available/sql
  sudo chown -R freerad:freerad /etc/freeradius/3.0/mods-enabled/sql
  cd /etc/freeradius/3.0/sites-available/
  wget --no-check-certificate https://pastebin.com/raw/Z2Qjhe4p -O default
  wget --no-check-certificate https://pastebin.com/raw/5UT82ghN -O inner-tunnel
  cd /etc/freeradius/3.0/; rm clients.conf
  echo "client localhost {

    ipaddr = 127.0.0.1
    proto = *
    secret = m7xjOM5PQZa5yXz4GPVFtdFHnyKxGsu9
    require_message_authenticator = no
    nas_type   = other
    limit {
      max_connections = 0
      lifetime = 0
      idle_timeout = 30
    }
  }
  client localhost_ipv6 {
    ipv6addr  = ::1
    secret    = testing123
  }
  client vpn.example.ca {

         ipaddr          = $(curl -s https://api.ipify.org)
         secret          = BMzQztmR18EF6bsqB4fD3fCqgv1C9Eff

  }
" >> clients.conf
  cd /etc/freeradius/3.0/certs/ && make
  chmod g+r /etc/freeradius/3.0/certs/server.pem
  cd /etc/radcli/; rm servers; rm radiusclient.conf
  echo "$(curl -s https://api.ipify.org) BMzQztmR18EF6bsqB4fD3fCqgv1C9Eff" >> /etc/radcli/servers
  echo "nas-identifier ocserv
authserver $(curl -s https://api.ipify.org)
acctserver $(curl -s https://api.ipify.org)
servers /etc/radcli/servers
dictionary /etc/radcli/dictionary
default_realm
radius_timeout 10
radius_retries 3
bindaddr *" >> /etc/radcli/radiusclient.conf
systemctl enable freeradius.service
systemctl start freeradius.service
systemctl restart freeradius.service
}&>/dev/null
}

install_squid()
{
clear
echo "Installing proxy."
{
