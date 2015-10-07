# Rsyslog defaults are only used if component includes "rsyslog"
node.default['rsyslog']['file_inputs']['solr1']['file'] = '/var/log/tomcat-solr/solr.log'
node.default['rsyslog']['file_inputs']['solr1']['severity'] = 'info'
node.default['rsyslog']['file_inputs']['solr1']['priority'] = 54
node.default['rsyslog']['file_inputs']['solr2']['file'] = '/var/log/tomcat-solr/catalina.out.*'
node.default['rsyslog']['file_inputs']['solr2']['severity'] = 'info'
node.default['rsyslog']['file_inputs']['solr2']['priority'] = 55

# Artifact deployer attributes
node.default['artifacts']['solrhome']['groupId'] = node['alfresco']['groupId']
node.default['artifacts']['solrhome']['artifactId'] = "alfresco-solr4"
node.default['artifacts']['solrhome']['version'] = node['alfresco']['version']
node.default['artifacts']['solrhome']['destination'] = node['alfresco']['properties']['dir.root']
node.default['artifacts']['solrhome']['owner'] = node['alfresco']['user']
node.default['artifacts']['solrhome']['unzip'] = true
node.default['artifacts']['solrhome']['type'] = "zip"

node.default['artifacts']['solrhome']['classifier'] = "config"

node.default['artifacts']['solr4']['groupId'] = node['alfresco']['groupId']
node.default['artifacts']['solr4']['artifactId'] = "alfresco-solr4"
node.default['artifacts']['solr4']['version'] = node['alfresco']['version']
node.default['artifacts']['solr4']['type'] = "war"
node.default['artifacts']['solr4']['owner'] = node['alfresco']['user']
node.default['artifacts']['solr4']['unzip'] = false

# Solr Pointers to Alfresco
node.default['alfresco']['solrproperties']['alfresco.host'] = node['alfresco']['internal_hostname']
node.default['alfresco']['solrproperties']['alfresco.port.ssl'] = node['alfresco']['internal_portssl']
node.default['alfresco']['solrproperties']['alfresco.port'] = node['alfresco']['internal_port']

# Log4j location
node.default['alfresco']['solr-log4j']['log4j.appender.File.File'] = "#{node['tomcat']['log_dir']}/solr.log"

# Solr WAR destination
if node['tomcat']['run_base_instance']
  node.default['artifacts']['solr4']['destination'] = node['tomcat']['webapp_dir']
elsif
  node.default['artifacts']['solr4']['destination'] = "#{node['alfresco']['home']}-solr/webapps"
end
