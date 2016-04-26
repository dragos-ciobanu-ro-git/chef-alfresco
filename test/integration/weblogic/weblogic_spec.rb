describe file('/opt/opencsw.sh') do
    it { should be_file }
end
describe file('/opt/csw/bin') do
    it { should be_directory }
end
describe file('/opt/csw/bin/pkgutil') do
    it { should be_file }
    it { should be_executable }
end

describe package('gcc-45') do
    it { should be_installed }
end

describe file('/opt/freetype-2.5.5.tar.gz') do
    it { should_not be_file }
end
describe file('/usr/local/bin/freetype-config') do
    it { should be_file }
    it { should be_executable }
end

describe file('/opt/jpegsrc.v9.tar.gz') do
    it { should_not be_file }
end
describe file('/usr/local/bin/jpegtran') do
    it { should be_file }
    it { should be_executable }
end

describe file('/opt/ghostscript.tar.gz') do
    it { should_not be_file }
end
describe file('/usr/local/bin/gs') do
    it { should be_file }
    it { should be_executable }
end

describe file('/opt/csw/bin/convert') do
    it { should be_file }
    it { should be_executable }
end

describe file('/opt/openOffice.tar.gz') do
    it { should_not be_file }
end
describe file('/opt/openOffice/openoffice.org3/program/soffice') do
    it { should be_file }
    it { should be_executable }
end

describe group('wls') do
  it { should exist }
end

describe user('oracle') do
  it { should exist }
  its(:group) { should eq 'wls' }
  its('home') { should eq '/export/home/oracle' }
  its('shell') { should eq '/usr/bin/bash' }
end

describe user('root') do
  it { should exist }
  its(:group) { should eq 'wls' }
  its('home') { should eq '/export/home/oracle' }
  its('shell') { should eq '/usr/bin/bash' }
end

describe file('/opt/java.tar.gz') do
  it { should_not be_file }
end
describe command('java -version') do
  its(:exit_status) { should eq 0 }
  its(:stderr) { should match /1.8.0_40/ }
end

describe file('/opt/weblogic.jar') do
  it { should_not be_file }
end

describe file('/opt/oraInst.loc') do
  it { should be_file }
end
describe file('/opt/owlscInstall.rsp') do
  it { should be_file }
end
