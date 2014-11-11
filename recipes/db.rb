#
# Cookbook Name:: wfpblife
# Recipe:: db
#
# Copyright (C) 2014 Kevin J. Dickerson
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

bag = {}
bag[:db] = data_bag_item('wp', 'db')
bag[:mysql_aws_backup] = data_bag_item('mysql_aws_backup', 'aws_credentials')

node.override['mysql']['server_root_password'] = bag[:db]['root_password']
node.override['mysql']['service_name'] = 'wfpblife_mysql'

include_recipe 'apt'
include_recipe 'mysql::server'
include_recipe 'database::mysql'

db_credentials = { host: '127.0.0.1', port: 3306, username: 'root',
                   password: node['mysql']['server_root_password'] }

# Create a mysql database
mysql_database bag[:db]['name'] do
  connection db_credentials
  action :create
end

# grant all privileges on all databases/tables from any address
mysql_database_user bag[:db]['user'] do
  connection db_credentials
  password bag[:db]['password']
  database_name bag[:db]['name']
  host '%'
  action :grant
end

# Query a database
mysql_database 'flush the privileges' do
  connection db_credentials
  sql 'flush privileges'
  action :query
end

template '/etc/mysql/conf.d/wfpblife.cnf' do
  source 'wfpblife.cnf.erb'
  mode '0644'
  owner 'mysql'
  group 'mysql'
  notifies :restart, 'mysql_service[wfpblife_mysql]'
end

gem_package 'aws-sdk' do
  version '1.57.0'
  action :install
end

gem_package 'resque' do
  action :install
end

gem_package 'mysql-aws-backup' do
  action :install
end

directory "/var/log/mysql-aws-backup" do
  owner 'root'
  group 'root'
  recursive true
end

user 'worker' do
  comment 'e.g. for cron jobs'
  system true
  home '/home/worker'
  supports manage_home: true
  action :create
end

file "/var/log/mysql-aws-backup/log.txt" do
  owner 'worker'
  group 'worker'
  mode '0755'
  action :create
end

mysql_aws_backup_env = { MYSQL_AWS_BACKUP_HOST:'127.0.0.1',
                         MYSQL_AWS_BACKUP_MYSQL_USER:'root',
                         MYSQL_AWS_BACKUP_MYSQL_PASSWORD:node['mysql']['server_root_password'],
                         MYSQL_AWS_BACKUP_FILE_PREFIX:'wfpblife-backup',
                         MYSQL_AWS_BACKUP_BUCKET:'wfpblife-db-backups',
                         MYSQL_AWS_BACKUP_DATABASE:bag[:db]['name'],
                         MYSQL_AWS_BACKUP_AWS_ACCESS_KEY_ID:bag[:mysql_aws_backup]['aws_id'],
                         MYSQL_AWS_BACKUP_AWS_SECRET_ACCESS_KEY:bag[:mysql_aws_backup]['aws_secret'],
                         MYSQL_AWS_BACKUP_AWS_REGION:bag[:mysql_aws_backup]['aws_region'] }

cron 'mysql_aws_backup' do
  action :create
  user 'worker'
  minute '0'
  hour '2'
  weekday '*'
  home '/home/worker'
  environment mysql_aws_backup_env
  command '/opt/chef/embedded/bin/mysql-aws-backup 2>&1 | tee --append /var/log/mysql-aws-backup/log.txt'
end
