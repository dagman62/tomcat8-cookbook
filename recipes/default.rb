#
# Cookbook:: tomcat8
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

include_recipe 'tar::default'
platform = node['platform']

$tcver = node['tomcat']['version']
$tchome = node['tomcat']['home']
$tcbase = node['tomcat']['base']
$tcver = node['tomcat']['version']
$nativehome = node['tomcat']['native']['home']
$nativever = node['tomcat']['native']['version']
$aprver = node['tomcat']['apr']['version']
$javahome = node['tomcat']['java']['home']
$javaver = node['tomcat']['java']['version']

if platform == 'centos' || platform == 'fedora'
  package %w(apr-devel openssl-devel libtool) do 
    action :install
  end
else
  package %w(libapr1.0-dev libssl-dev libtool-bin)  do 
    action :install
  end
end

tar_extract "http://falcon.example.com/archives/apache-tomcat-#{$tcver}.tar.gz" do
  target_dir '/opt'
  creates "/opt/apache-tomcat-#{$tcver}/bin/catalina.sh"
end

link "#{$tchome}" do
  to "/opt/apache-tomcat-#{$tcver}"
  link_type :symbolic
end

tar_package "http://falcon.example.com/archives/apr-#{$aprver}.tar.gz" do
  prefix "#{$nativehome}"
  creates "#{$nativehome}/bin/apr-1-config"
end

tar_extract "http://falcon.example.com/archives/jdk-#{$javaver}-linux-x64.tar.gz" do 
  target_dir '/opt'
  creates "#{$javahome}/bin/java"
end

execute 'Register JDK Libraries' do
  command "libtool --finish #{$javahome}/lib"
  action :run
end

tar_extract "http://falcon.example.com/archives/tomcat-native-#{$nativever}-src.tar.gz" do 
  target_dir '/usr/local/src'
  creates "/usr/local/src/tomcat-native-#{$nativever}-src/native/configure"
end

bash 'Build Native Libraries' do
  code <<-EOH
  cd /usr/local/src/tomcat-native-#{$nativever}-src/native
  ./configure \
    --with-apr=#{$nativehome}/bin/apr-1-config \
    --with-java-home=#{$javahome} \
    --with-ssl 
    make 
    make install
  EOH
  action :run
end

cookbook_file "#{$tchome}/bin/wrapper" do
  source 'wrapper'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

template "#{$tchome}/bin/wrapper.sh" do
  source 'sh.script.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables ({
    :appname      =>  node['tomcat']['appname'],
    :longappname  =>  node['tomcat']['longappname'],
    :tchome       =>  node['tomcat']['home'],
  })
  action :create
end

cookbook_file "#{$tchome}/lib/libwrapper.so" do
  source 'libwrapper.so'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

cookbook_file "#{$tchome}/lib/wrapper.jar" do
  source 'wrapper.jar'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

template "#{$tchome}/conf/wrapper.conf" do
  source 'wrapper.conf.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables ({
    :javahome => node['tomcat']['java']['home'],
    :tchome   => node['tomcat']['home'],
  })
  action :create
end

cookbook_file "#{$tchome}/lib/mysql-connector-java-5.1.44-bin.jar" do
  source 'mysql-connector-java-5.1.44-bin.jar'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

template "#{$tchome}/conf/tomcat-users.xml" do
  source 'tomcat-users.xml.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables ({
    :tcuser =>  node['tomcat']['user'],
    :tcpass =>  node['tomcat']['password'],
  })
  action :create
end

template "/etc/systemd/system/tomcat.service" do
  source 'tomcat.service.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables ({
    :javahome => node['tomcat']['java']['home'],
    :tchome   => node['tomcat']['home'],
  })
  action :create
end

service 'tomcat' do
  action [:enable, :start]
end

