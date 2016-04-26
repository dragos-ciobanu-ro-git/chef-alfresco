
bash 'setup hostname' do
    user 'root'
    code <<-EOH
    svccfg -s system/identity:node setprop config/nodename="sergiutest"
    svccfg -s system/identity:node setprop config/loopback="sergiutest"
    svccfg -s system/identity:node refresh
    svcadm restart system/identity:node
  EOH
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

directory node['weblogic']['oracle_home'] do
  owner 'oracle'
  group 'wls'
  recursive true
  action :create
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

remote_file "#{node['weblogic']['oracle_home']}/java.tar.gz" do
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
    cwd node['weblogic']['oracle_home']
    code <<-EOH
  tar xvf java.tar.gz
  export PATH=#{node['weblogic']['oracle_home']}/#{node['java']['java_folder']}/bin:$PATH
  export JAVA_HOME=#{node['weblogic']['oracle_home']}/#{node['java']['java_folder']}
  EOH
  not_if 'cat $JAVA_HOME/release | grep 1.8'
end

remote_file "#{node['weblogic']['oracle_home']}/weblogic.jar" do
    source node['weblogic']['installer']
    owner 'oracle'
    group 'wls'
    mode '644'
    action :create_if_missing
end

environment_setup = { PATH: "#{node['weblogic']['oracle_home']}/#{node['java']['java_folder']}/bin:$PATH",
                      WL_HOME: "#{node['weblogic']['oracle_home']}/Oracle_Home/wlserver",
                      CONFIG_JVM_ARGS: "\"-Djava.security.egd=file:/dev/./urandom\"",
                      JAVA_HOME: "#{node['weblogic']['oracle_home']}/#{node['java']['java_folder']}"}

environment_setup.each do |propName, propValue|
  file_replace_line "replace-#{propName}-on-.profile" do
    path "#{node['weblogic']['oracle_home']}/.profile"
    replace "#{propName}="
    with "#{propName}=#{propValue}"
    only_if "test -f #{node['weblogic']['oracle_home']}/.profile"
  end
  file_append "append #{propName} to .profile" do
    path "#{node['weblogic']['oracle_home']}/.profile"
    line "export #{propName}=#{propValue}"
    only_if "test -f #{node['weblogic']['oracle_home']}/.profile"
  end
end

template "#{node['weblogic']['oracle_home']}/oraInst.loc" do
    source 'weblogic/oraInst.loc.erb'
    variables(
        oracle_home: "#{node['weblogic']['oracle_home']}/oraInventory"
    )
    owner 'oracle'
    group 'wls'
    mode '644'
end

template "#{node['weblogic']['oracle_home']}/owlscInstall.rsp" do
    source 'weblogic/owlscInstall.rsp.erb'
    variables(
        oracle_home: "#{node['weblogic']['oracle_home']}/Oracle_Home"
    )
    owner 'oracle'
    group 'wls'
    mode '644'
end

execute 'Install weblogic' do
    command "su - oracle -c \"#{node['weblogic']['oracle_home']}/#{node['java']['java_folder']}/bin/java -d64 -jar #{node['weblogic']['oracle_home']}/weblogic.jar -silent -invPtrLoc #{node['weblogic']['oracle_home']}/oraInst.loc -responseFile #{node['weblogic']['oracle_home']}/owlscInstall.rsp\""
    not_if { File.exist?("#{node['weblogic']['oracle_home']}/Oracle_Home/wlserver/common/bin/wlst.sh") }
    user 'root'
end

template "#{node['weblogic']['oracle_home']}/create_domain.py" do
    source 'weblogic/create_domain.py.erb'
    variables(
        wlserver_home: "#{node['weblogic']['oracle_home']}/Oracle_Home/wlserver",
        weblogic_password: 'alfresco1',
        domain_home: "#{node['weblogic']['oracle_home']}/alf_domain",
        weblogic_port: '7001',
        weblogic_ssl_port: '7002'
    )
    owner 'oracle'
    group 'wls'
    mode '644'
end

execute "su - oracle -c \"#{node['weblogic']['oracle_home']}/Oracle_Home/wlserver/common/bin/wlst.sh #{node['weblogic']['oracle_home']}/create_domain.py\"" do
    user 'root'
    not_if { File.exist?("#{node['weblogic']['oracle_home']}/alf_domain/config/config.xml") }
end

// # TODO: implement proper services to handle startup/shutdown
bash 'restart weblogic' do
    user 'oracle'
    cwd "#{node['weblogic']['oracle_home']}"
    code <<-EOH
#{node['weblogic']['oracle_home']}/alf_domain/bin/stopWebLogic.sh && #{node['weblogic']['oracle_home']}/alf_domain/bin/startWebLogic.sh &
  EOH
end

bash 'restart nodemanager' do
    user 'oracle'
    cwd "#{node['weblogic']['oracle_home']}"
    code <<-EOH
#{node['weblogic']['oracle_home']}/alf_domain/bin/stopNodeManager.sh && #{node['weblogic']['oracle_home']}/alf_domain/bin/startNodeManager.sh &
  EOH
end

# remote_file "#{node['weblogic']['oracle_home']}/alfresco-ear.zip" do
#   source node['weblogic']['alfresco-ear']
#   owner 'oracle'
#   group 'oracle'
# end
