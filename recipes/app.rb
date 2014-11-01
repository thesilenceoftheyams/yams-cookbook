#
# Cookbook Name:: wfpblife
# Recipe:: app
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

dbs = search(:node, 'roles:wfpblife-db')

unless dbs && dbs.first['fqdn']
  fail 'Could not find a database server in the node list.'
end

unless dbs.count == 1
  fail "There are #{dbs.count} database servers instead of exactly one. There should be only one databse server."
end

wp_db = data_bag_item('wp', 'db')

node.override[:wordpress][:db][:pass] = wp_db['password']
node.default[:wordpress][:db][:host] = dbs.first['fqdn']
node.default[:wordpress][:db][:user] = wp_db['user']
node.default[:wordpress][:db][:name] = wp_db['name']

include_recipe 'apt'
include_recipe 'wordpress'
include_recipe 'wp-cli'

directory "#{node[:wordpress][:dir]}/health_check" do
  owner node['apache']['user']
  group node['apache']['user']
  recursive true
end

template "#{node[:wordpress][:dir]}/health_check/index.php" do
  owner node['apache']['user']
  group node['apache']['user']
  source 'health_check.php.erb'
  mode '0644'
end
