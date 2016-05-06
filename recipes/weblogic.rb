
bash 'Setup svc hostname' do
    user 'root'
    code <<-EOH
    svccfg -s system/identity:node setprop config/nodename="#{node['weblogic']['hostname']}"
    svccfg -s system/identity:node setprop config/loopback="#{node['weblogic']['hostname']}"
    svccfg -s system/identity:node refresh
    svcadm restart system/identity:node
  EOH
  not_if "svccfg -s system/identity:node listprop config | grep #{node['weblogic']['hostname']}"
end

file_replace_line "modify ipv4 /etc/hosts" do
  path "/etc/hosts"
  replace "127.*"
  with "127.0.0.1       localhost       localhost.localdomain   loghost"
end
file_replace_line "modify ipv6 /etc/hosts" do
  path "/etc/hosts"
  replace "::1.*"
  with "::1             localhost"
end
file_append "append hostname to /etc/hosts" do
  path "/etc/hosts"
  line "#{node['ipaddress']}  #{node['weblogic']['hostname']}    #{node['weblogic']['hostname']}.alfness.com"
  not_if "cat /etc/hosts | grep '#{node['weblogic']['hostname']}'"
end

bash 'setup hostname ipv4' do
    user 'root'
    code <<-EOH
    sed '/^127./ s/$/ #{node['weblogic']['hostname']}/' /etc/hosts > ./hoststmp; mv ./hoststmp /etc/hosts
  EOH
  not_if "cat /etc/hosts | grep '::1.* #{node['weblogic']['hostname']}'"
end

group 'wls'

user 'oracle' do
  comment 'default Oracle user'
  group 'wls'
  home '/export/home/oracle'
  shell '/usr/bin/bash'
  password 'alfresco'
end

group 'wls' do
    members ['oracle']
    append true
end

directory node['weblogic']['oracle_user_home'] do
  owner 'oracle'
  group 'wls'
  recursive true
end

bash 'setup user files from skeleton' do
    user 'oracle'
    group 'wls'
    code <<-EOH
  cp -rf /etc/skel/.bashrc /export/home/oracle/
  cp -rf /etc/skel/.profile /export/home/oracle/
  cp -rf /etc/skel/* /export/home/oracle/
  EOH
end

remote_file "#{node['weblogic']['oracle_user_home']}/java.tar.gz" do
    source node['java_8_download_path']
    owner 'oracle'
    group 'wls'
    mode '644'
    action :create_if_missing
    not_if 'cat $JAVA_HOME/release | grep 1.8'
end

bash 'install_java' do
    user 'oracle'
    group 'wls'
    cwd node['weblogic']['oracle_user_home']
    code <<-EOH
  tar xvf java.tar.gz
  export PATH=#{node['weblogic']['oracle_user_home']}/#{node['java']['java_folder']}/bin:$PATH
  export JAVA_HOME=#{node['weblogic']['oracle_user_home']}/#{node['java']['java_folder']}
  EOH
  not_if 'cat $JAVA_HOME/release | grep 1.8'
end

remote_file "#{node['weblogic']['oracle_user_home']}/weblogic.jar" do
    source node['weblogic']['installer']
    owner 'oracle'
    group 'wls'
    mode '644'
    action :create_if_missing
end

environment_setup = { PATH: "#{node['weblogic']['oracle_user_home']}/#{node['java']['java_folder']}/bin:$PATH",
                      WL_HOME: "#{node['weblogic']['oracle_user_home']}/Oracle_Home/wlserver",
                      CONFIG_JVM_ARGS: "\"-Djava.security.egd=file:/dev/./urandom\"",
                      JAVA_HOME: "#{node['weblogic']['oracle_user_home']}/#{node['java']['java_folder']}"}

environment_setup.each do |propName, propValue|
  file_replace_line "replace-#{propName}-on-.profile" do
    path "#{node['weblogic']['oracle_user_home']}/.profile"
    replace "#{propName}="
    with "#{propName}=#{propValue}"
    only_if "test -f #{node['weblogic']['oracle_user_home']}/.profile"
  end
  file_append "append #{propName} to .profile" do
    path "#{node['weblogic']['oracle_user_home']}/.profile"
    line "export #{propName}=#{propValue}"
    only_if "test -f #{node['weblogic']['oracle_user_home']}/.profile"
  end
end

template "#{node['weblogic']['oracle_user_home']}/oraInst.loc" do
    source 'weblogic/oraInst.loc.erb'
    variables(
        oracle_home: "#{node['weblogic']['oracle_user_home']}/oraInventory"
    )
    owner 'oracle'
    group 'wls'
    mode '644'
end

template "#{node['weblogic']['oracle_user_home']}/owlscInstall.rsp" do
    source 'weblogic/owlscInstall.rsp.erb'
    variables(
        oracle_home: "#{node['weblogic']['oracle_user_home']}/Oracle_Home"
    )
    owner 'oracle'
    group 'wls'
    mode '644'
end

execute 'Install weblogic' do
    command "su - oracle -c \"#{node['weblogic']['oracle_user_home']}/#{node['java']['java_folder']}/bin/java -d64 -jar #{node['weblogic']['oracle_user_home']}/weblogic.jar -silent -invPtrLoc #{node['weblogic']['oracle_user_home']}/oraInst.loc -responseFile #{node['weblogic']['oracle_user_home']}/owlscInstall.rsp\""
    not_if { File.exist?("#{node['weblogic']['oracle_user_home']}/Oracle_Home/wlserver/common/bin/wlst.sh") }
    user 'root'
end

template "#{node['weblogic']['oracle_user_home']}/config.py" do
    source 'weblogic/config.py.erb'
    variables(
      serverIp: node['ipaddress'],
      AlfrescoExplodedLocation: '/opt/AlfrescoServer/alfresco/sample.war',
      DomainName: 'alf_domain',
      DomainRootPath: "#{node['weblogic']['oracle_user_home']}",
      NodeManagerPath: "#{node['weblogic']['oracle_user_home']}/alf_domain/nodemanager",
      DefaultPassword: 'alfresco1',
      WeblogicInstallPath: "#{node['weblogic']['oracle_user_home']}/Oracle_Home",
      Alfresco_port: '8080'
    )
    owner 'oracle'
    group 'wls'
    mode '644'
end

directory '/opt/AlfrescoServer/alfresco' do
  owner 'oracle'
  group 'wls'
  recursive true
end

remote_file "/opt/AlfrescoServer/alfresco-ear.zip" do
  source node['weblogic']['alfresco-ear']
  owner 'oracle'
  group 'wls'
  action :create_if_missing
end

template "/opt/AlfrescoServer/explode-ear.sh" do
    source 'weblogic/explode-ear.sh.erb'
    owner 'oracle'
    group 'wls'
    mode '644'
end

directory "#{node['weblogic']['oracle_user_home']}/alf_domain" do
  owner 'oracle'
  group 'wls'
  recursive true
end

template "#{node['weblogic']['oracle_user_home']}/alf_domain/alfresco-global.properties" do
    source 'weblogic/alfresco-global.properties.erb'
    owner 'oracle'
    group 'wls'
    mode '644'
end

bash 'Move artifacts' do
    user 'oracle'
    group 'wls'
    cwd "/opt/AlfrescoServer/"
    code <<-EOH
  unzip alfresco-ear.zip
  rm -rf bin licenses myfaces*.zip README.txt
  mv web-server/classpath/alfresco #{node['weblogic']['oracle_user_home']}/alf_domain/
  EOH
end

execute 'Explode ear' do
    command "su - oracle -c \"cd /opt/AlfrescoServer && sh explode-ear.sh alfresco-*.ear\""
    user 'root'
end

execute 'Configure Alfresco Domain' do
    command "su - oracle -c \"#{node['weblogic']['oracle_user_home']}/Oracle_Home/wlserver/common/bin/wlst.sh #{node['weblogic']['oracle_user_home']}/config.py >> #{node['weblogic']['oracle_user_home']}/config.log\""
    user 'root'
end

execute 'Waiting for configuration to finish' do
  user 'root'
  command "tail -5 #{node['weblogic']['oracle_user_home']}/config.log | grep \"Exiting WebLogic Scripting Tool.\""
  action :run
  retries 30
  retry_delay 2
  returns 0
end

#Service configuration
template "#{node['weblogic']['oracle_user_home']}/nodemanager-service.xml" do
    source 'weblogic/serviceManifest.xml.erb'
    variables(
      ServiceName: 'wlnodemanager',
      StartCommand: "nohup #{node['weblogic']['oracle_user_home']}/alf_domain/bin/startNodeManager.sh &amp;",
      StopCommand: "#{node['weblogic']['oracle_user_home']}/alf_domain/bin/stopNodeManager.sh"
    )
    owner 'oracle'
    group 'wls'
    mode '644'
end

template "#{node['weblogic']['oracle_user_home']}/adminserver-service.xml" do
    source 'weblogic/serviceManifest.xml.erb'
    variables(
      ServiceName: 'wladminserver',
      StartCommand: "nohup #{node['weblogic']['oracle_user_home']}/alf_domain/bin/startWebLogic.sh &amp;",
      StopCommand: "#{node['weblogic']['oracle_user_home']}/alf_domain/bin/stopWebLogic.sh"
    )
    owner 'oracle'
    group 'wls'
    mode '644'
end

template "#{node['weblogic']['oracle_user_home']}/alfrescoserver-service.xml" do
    source 'weblogic/serviceManifest.xml.erb'
    variables(
      ServiceName: 'wlalfrescoserver',
      StartCommand: "nohup #{node['weblogic']['oracle_user_home']}/alf_domain/bin/startManagedWebLogic.sh AlfrescoServer &amp;",
      StopCommand: "#{node['weblogic']['oracle_user_home']}/alf_domain/bin/stopManagedWebLogic.sh AlfrescoServer"
    )
    owner 'oracle'
    group 'wls'
    mode '644'
end

bash 'Import Service configuration' do
    user 'root'
    code <<-EOH
  svccfg import #{node['weblogic']['oracle_user_home']}/nodemanager-service.xml
  svccfg import #{node['weblogic']['oracle_user_home']}/adminserver-service.xml
  svccfg import #{node['weblogic']['oracle_user_home']}/alfrescoserver-service.xml
  EOH
end

service 'wlnodemanager' do
  action :start
end

service 'wladminserver' do
  action :start
end

execute 'Waiting for AdminServer to start' do
  user 'root'
  command "tail -5 /var/svc/log/wladminserver*.log | grep \"Server state changed to RUNNING.\""
  action :run
  retries 50
  retry_delay 2
  returns 0
end

service 'wlalfrescoserver' do
  action :nothing
end

directory "#{node['weblogic']['oracle_user_home']}/alf_domain/servers/AlfrescoServer/security" do
  owner 'oracle'
  group 'wls'
  recursive true
end

file "#{node['weblogic']['oracle_user_home']}/alf_domain/servers/AlfrescoServer/security/boot.properties" do
  content "username=weblogic\npassword=alfresco1"
  owner 'oracle'
  group 'wls'
  mode '644'
  notifies :start, 'service[wlalfrescoserver]', :immediately
end
