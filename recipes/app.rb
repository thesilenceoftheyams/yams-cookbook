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

bag = {}
bag[:db] = data_bag_item('wp', 'db')
bag[:setup] = data_bag_item('wp', 'setup')
bag[:w3tc] = data_bag_item('wp', 'w3tc')

fail 'Could not find a database server in the node list.' unless dbs && dbs.first['fqdn']

fail "There should be exactly 1 database node, but there are #{dbs.count}." unless dbs.count == 1

fail "Required data bag wp::setup is not configured correctly. #{bag[:setup].to_json}" \
  unless bag[:setup] &&
         bag[:setup]['domain'] &&
         bag[:setup]['title'] &&
         bag[:setup]['admin_user'] &&
         bag[:setup]['admin_password'] &&
         bag[:setup]['admin_email']

fail "Required data bag wp::w3tc is not configured correctly. #{bag[:w3tc].to_json}" unless bag[:w3tc]

node.override[:wordpress][:db][:pass] = bag[:db]['password']
node.default[:wordpress][:db][:host] = dbs.first['fqdn']
node.default[:wordpress][:db][:user] = bag[:db]['user']
node.default[:wordpress][:db][:name] = bag[:db]['name']

node.default[:w3tc][:cloudfront_key] = bag[:w3tc]['cloudfront_key']
node.default[:w3tc][:cloudfront_secret] = bag[:w3tc]['cloudfront_secret']
node.default[:w3tc][:cloudfront_id] = bag[:w3tc]['cloudfront_id']

include_recipe 'apt'
include_recipe 'php'

package 'php5-curl' do
  action :install
end

package 'memcached' do
  action :install
end

package 'php5-memcache' do
  action :install
end

include_recipe 'wordpress'
include_recipe 'wp-cli'

execute 'ensure core wordpress is initialized' do
  command <<-CMD
    wp core install --url="#{bag[:setup]['domain']}" --title="#{bag[:setup]['title']}" --admin_user="#{bag[:setup]['admin_user']}" --admin_password="#{bag[:setup]['admin_password']}" --admin_email="#{bag[:setup]['admin_email']}"
  CMD
  cwd node[:wordpress][:dir]
  user node[:apache][:user]
  action :run
end

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

execute 'install the w3-total-cache plugin' do
  command 'wp plugin install w3-total-cache'
  cwd node[:wordpress][:dir]
  user node[:apache][:user]
  action :run
end

execute 'activate the w3-total-cache plugin' do
  command 'wp plugin activate w3-total-cache'
  cwd node[:wordpress][:dir]
  user node[:apache][:user]
  action :run
end

directory "#{node[:wordpress][:dir]}/wp-content/w3tc-config" do
  owner node['apache']['user']
  group node['apache']['user']
  recursive true
end

template "#{node[:wordpress][:dir]}/wp-content/w3tc-config/master.php" do
  owner node['apache']['user']
  group node['apache']['user']
  source 'w3tc_config_master.php.erb'
  mode '0644'
end

template "#{node[:wordpress][:dir]}/wp-content/w3tc-config/master-admin.php" do
  owner node['apache']['user']
  group node['apache']['user']
  source 'w3tc_config_master_admin.php.erb'
  mode '0644'
end

file "#{node[:wordpress][:dir]}/wp-content/w3tc-config/index.html" do
  owner node['apache']['user']
  group node['apache']['user']
  mode '0644'
  action :create
end
