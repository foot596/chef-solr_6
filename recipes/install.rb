# frozen_string_literal: true
#
# Cookbook Name:: solr_6
# Recipe:: install
#
# Copyright (c) 2016 ECHO Inc, All Rights Reserved.

if node['solr']['install_java']
  include_recipe 'yum::dnf_yum_compat' if platform?('fedora')
  include_recipe 'yum'
  include_recipe 'java'
end

# Solr Installation script reuquires lsof on Red Hat
yum_package 'lsof' if platform_family?(%w(rhel fedora))

src_filename = ::File.basename(node['solr']['url'])
src_filepath = "#{Chef::Config['file_cache_path']}/#{src_filename}"

# Create Group (unless it is root)
group node['solr']['group'] do
  not_if { node['solr']['group'] == 'root' }
  only_if { node['solr']['create_group'] }
end

# Create User (unless it is root)
user node['solr']['user'] do
  home "/home/#{node['solr']['user']}/"
  manage_home true
  shell '/bin/bash'
  group node['solr']['group']
  not_if { node['solr']['user'] == 'root' }
  only_if { node['solr']['create_user'] }
end

# Create Data Dir
directory node['solr']['data_dir'] do
  owner node['solr']['user']
  group node['solr']['group']
  recursive true
  action :create
end

# Create Include File Dir
directory '/etc/default' do
  owner 'root'
  action :create
end

# Create Include File From Template
template '/etc/default/solr.in.sh' do
  source ::File.join('install', 'solr.in.sh.erb')
end

service 'solr' do
  action :nothing
end

# Download install_solr_service.sh script
remote_file "#{::File.dirname(src_filepath)}/install_solr_service.sh" do
  source node['solr']['install_solr_service_url']
  mode '0750'
  action :create_if_missing
end

# Download Solr
remote_file src_filepath do
  source node['solr']['url']
  action :create_if_missing
  notifies :run, 'bash[install_solr]', :immediately
end

# Install and start Solr
bash 'install_solr' do
  action :nothing
  cwd ::File.dirname(src_filepath)
  code <<-EOH
        ./install_solr_service.sh #{src_filename} -u #{node['solr']['user']} -p #{node['solr']['port']} -d #{node['solr']['data_dir']} -i #{node['solr']['dir']} -f -n
    EOH
  notifies :restart, 'service[solr]', :delayed
end
