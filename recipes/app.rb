#
# Cookbook Name:: yams
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

dbs = search(:node, 'roles:yams-db')

fail 'Could not find a database server in the node list.' unless dbs && dbs.first['fqdn']
fail "There should be exactly 1 database node, but there are #{dbs.count}." unless dbs.count == 1

bag = {}
bag[:mysql] = data_bag_item('configurations', 'mysql')
bag[:wp] = data_bag_item('configurations', 'wp')
bag[:aws] = data_bag_item('configurations', 'aws')
bag[:newrelic] = data_bag_item('configurations', 'newrelic')

node.override[:wordpress][:db][:pass] = bag[:mysql]['db_password']
node.default[:wordpress][:db][:host] = dbs.first['fqdn']
node.default[:wordpress][:db][:user] = bag[:mysql]['db_user']
node.default[:wordpress][:db][:name] = bag[:mysql]['db_name']
node.default[:aws][:cloudfront_key] = bag[:aws]['cloudfront_key']
node.default[:aws][:cloudfront_secret] = bag[:aws]['cloudfront_secret']
node.default[:aws][:s3_bucket] = bag[:aws]['s3_bucket']
node.default[:aws][:cloudfront_domain] = 'dtilrwd2esdkz.cloudfront.net'
node.default[:newrelic][:api_key] = bag[:newrelic]['api_key']
node.default[:aws][:cloudfront_subdomain] = bag[:aws]['cloudfront_subdomain']
node.override[:aws][:cloudfront_full_domain] = bag[:aws]['cloudfront_full_domain']

include_recipe 'apt'
include_recipe 'varnish'
include_recipe 'php'

package 'php5-curl'
package 'memcached'
package 'php5-memcache'
package 'php5-fpm'
package 'php5-gd'
package 'ca-certificates'

include_recipe 'wordpress'
include_recipe 'wp-cli'

execute 'ensure core wordpress is initialized' do
  command <<-CMD
    wp core install --url="#{bag[:wp]['domain']}" --title="#{bag[:wp]['title']}" --admin_user="#{bag[:wp]['admin_user']}" --admin_password="#{bag[:wp]['admin_password']}" --admin_email="#{bag[:wp]['admin_email']}"
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

execute 'delete hello plugin' do
  command 'wp plugin delete hello'
  cwd node[:wordpress][:dir]
  user node[:apache][:user]
  action :run
end

execute 'delete akismet plugin' do
  command 'wp plugin delete akismet'
  cwd node[:wordpress][:dir]
  user node[:apache][:user]
  action :run
end

execute 'install the aws-for-wp plugin' do
  command 'wp plugin install aws-for-wp'
  cwd node[:wordpress][:dir]
  user node[:apache][:user]
  action :run
end

execute 'activate the aws-for-wp plugin' do
  command 'wp plugin activate aws-for-wp'
  cwd node[:wordpress][:dir]
  user node[:apache][:user]
  action :run
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

node.override['newrelic']['license_key'] = bag[:newrelic]['key']
node.override['newrelic']['license'] = bag[:newrelic]['key']
node.override['newrelic']['application_monitoring']['license'] = bag[:newrelic]['key']
node.override['newrelic']['server_monitoring']['license'] = bag[:newrelic]['key']
node.default['newrelic']['application_monitoring']['enabled'] = true
node.default['newrelic']['application_monitoring']['app_name'] = "#{default[:blog][:human_name]} App"
node.override['newrelic']['php_agent']['license'] = bag[:newrelic]['key']

include_recipe 'java'
include_recipe 'python'
include_recipe 'newrelic'
include_recipe 'newrelic::php_agent'

file '/etc/php5/apache2/conf.d/newrelic.ini' do
  action :delete
end

tantan_wordpress_s3_json = "a:5:{s:3:\"key\";s:20:\"#{node[:aws][:cloudfront_key]}\";s:6:\"secret\";s:40:\"#{node[:aws][:cloudfront_secret]}\";s:6:\"bucket\";s:18:\"#{node[:aws][:s3_bucket]}\";s:10:\"cloudfront\";s:28:\"#{node[:aws][:cloudfront_full_domain]}\";s:10:\"wp-uploads\";s:1:\"1\";}"
tantan_query = "INSERT INTO wp_options (option_name,option_value,autoload) VALUES ('tantan_wordpress_s3','#{tantan_wordpress_s3_json}}','yes') ON DUPLICATE KEY UPDATE option_name='tantan_wordpress_s3', option_value='#{tantan_wordpress_s3_json}}';"

db_credentials = { host: dbs.first['fqdn'],
                   port: 3306,
                   username: bag[:mysql]['db_user'],
                   password: bag[:mysql]['db_password'] }

mysql_database 'ensure credentials are in db for wp s3 plugin' do
  connection db_credentials
  database_name bag[:mysql]['db_name']
  sql tantan_query
  action :query
end

service 'apache2' do
  action [:stop, :start]
end
