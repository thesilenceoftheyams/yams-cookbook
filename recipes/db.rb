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

wp_db = data_bag_item('wp', 'db')

node.override['mysql']['server_root_password'] = wp_db['root_password']
node.override['mysql']['service_name'] = 'wfpblife_mysql'

include_recipe 'apt'
include_recipe 'mysql::server'
include_recipe 'database::mysql'

db_credentials = { host: '127.0.0.1', port: 3306, username: 'root',
                   password: node['mysql']['server_root_password'] }

# Create a mysql database
mysql_database wp_db['name'] do
  connection db_credentials
  action :create
end

# grant all privileges on all databases/tables from any address
mysql_database_user wp_db['user'] do
  connection db_credentials
  password wp_db['password']
  database_name wp_db['name']
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
