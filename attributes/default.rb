default[:yams][:human_name] = "The Silence of the Yams"
default[:yams][:code_name] = "yams"

if 'ubuntu' == node['platform']
  default[:newrelic][:php_agent][:config_file] = '/etc/php5/mods-available/newrelic.ini'
else
  fail 'unsupported platform'
end

default['yams']['backup_file_prefix'] = 'yams-backup'
default['yams']['backup_bucket'] = 'yams-db-backups'
