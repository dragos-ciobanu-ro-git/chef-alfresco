# TODO - build-essential shouldnt really be here. move it to default (or essentials.rb)
if node['platform_family'] == "ubuntu" || node['platform_family'] == "rhel"

  include_recipe "build-essential::default"
  include_recipe "imagemagick::default"

  if node['alfresco']['use_libreoffice_os_repo']
    if node['platform'] == 'redhat'
      yum_repos = [
        'rhui-REGION-rhel-server-extras',
        'rhui-REGION-rhel-server-optional',
        'rhui-REGION-rhel-server-source-optional'
      ]
      yum_repos.each do |repo|
        execute "enable-yum-repo-#{repo}" do
          command "yum-config-manager --enable #{repo}"
        end
      end
    end
    include_recipe "libreoffice::default"
  else
    libre_office_name = node['alfresco']['libre_office_name']
    libre_office_tar_name = node['alfresco']['libre_office_tar_name']
    libre_office_tar_url = node['alfresco']['libre_office_tar_url']

    remote_file "#{Chef::Config[:file_cache_path]}/#{libre_office_tar_name}" do
      source libre_office_tar_url
      owner 'root'
      group 'root'
    end

    execute 'unpack-libreoffice' do
      cwd Chef::Config[:file_cache_path]
      command "tar -xf #{libre_office_tar_name}"
      creates "#{Chef::Config[:file_cache_path]}/#{libre_office_name}"
      not_if "test -d #{Chef::Config[:file_cache_path]}/#{libre_office_name}"
    end

    execute 'install-libreoffice' do
      cwd Chef::Config[:file_cache_path]
      command "yum -y localinstall #{Chef::Config[:file_cache_path]}/#{libre_office_name}/RPMS/*.rpm"
      not_if "yum list installed | grep libreoffice"
    end
  end

  if node['platform_family'] == "ubuntu"
    include_recipe "ffmpeg::default"
    include_recipe "swftools::default"
  elsif node['platform_family'] == "rhel"
    install_fonts = node['alfresco']['install_fonts']
    exclude_font_packages = node['alfresco']['exclude_font_packages']

    # TODO - implement it also for Ubuntu using apt-get
    execute "install-all-fonts" do
      command "yum install -y *fonts.noarch --exclude='#{exclude_font_packages}'"
      only_if { install_fonts and node['platform_family'] == "rhel" }
    end

    #Taken from https://www.centos.org/forums/viewtopic.php?f=48&t=50232
    bash 'install_swftools' do
      user 'root'
      cwd '/tmp'
      code <<-EOH
      yum install -y wget zlib zlib-devel freetype-devel jpeglib-devel giflib-devel libjpeg-turbo-devel
      wget http://www.swftools.org/swftools-2013-04-09-1007.tar.gz -O swftools-2013-04-09-1007.tar.gz
      tar -zvxf swftools-2013-04-09-1007.tar.gz
      cd swftools-2013-04-09-1007
      ./configure --libdir=/usr/lib64 --bindir=/usr/local/bin
      make && make install
      EOH
      not_if "test -f /usr/local/bin/pdf2swf"
      only_if { node['alfresco']['install_swftools'] }
    end
  end

  package "perl-Image-ExifTool" do
    action :install
  end

elsif node['platform_family'] == "solaris2"

  template '/opt/opencsw.sh' do
    source 'transformations/opencsw.sh.erb'
    owner 'root'
    group 'root'
    mode 00755
    not_if { File.exist?('/opt/csw/bin/pkgutil') }
  end

  bash 'Install opencsw' do
    user 'root'
    cwd '/opt'
    code <<-EOH
  expect opencsw.sh
    EOH
    not_if { File.exist?('/opt/csw/bin/pkgutil') }
  end

  package 'gcc-45' do
    action :install
  end

  remote_file '/opt/freetype-2.5.5.tar.gz' do
    source node['alfresco']['freetype']
    owner 'root'
    group 'root'
    mode 00775
    action :create_if_missing
    sensitive true
    not_if { File.exist?('/usr/local/bin/freetype-config') }
  end

  bash 'Install freetype' do
    user 'root'
    cwd '/opt'
    code <<-EOH
    tar xvf freetype-2.5.5.tar.gz
    cd freetype-2.5.5 && ./configure && gmake && gmake install
      EOH
    not_if { File.exist?('/usr/local/bin/freetype-config') }
  end
  
  remote_file '/opt/jpegsrc.v9.tar.gz' do
    source node['alfresco']['jpegsrc']
    owner 'root'
    group 'root'
    mode 00775
    action :create_if_missing
    not_if { File.exist?('/usr/local/bin/jpegtran') }
  end

  bash 'Install jpegsrc' do
    user 'root'
    cwd '/opt'
    code <<-EOH
    tar xvf jpegsrc.v9.tar.gz
    cd jpeg-9 && ./configure && gmake && gmake install
      EOH
    not_if { File.exist?('/usr/local/bin/jpegtran') }
  end

  remote_file '/opt/ghostscript.tar.gz' do
    source node['alfresco']['ghostscript']
    owner 'root'
    group 'root'
    mode 00775
    action :create_if_missing
    not_if { File.exist?('/usr/local/bin/gs') }
  end

  bash 'Install ghostscript' do
    user 'root'
    cwd '/opt'
    code <<-EOH
    tar xvf ghostscript.tar.gz
    cd ghostscript-9.15
    ./configure --without-gnu-make && make && make install
      EOH
    not_if { File.exist?('/usr/local/bin/gs') }
  end

  bash 'Install ImageMagick' do
    user 'root'
    cwd '/opt'
    code <<-EOH
  /opt/csw/bin/pkgutil -y -i imagemagick
    EOH
    not_if { File.exist?('/opt/csw/bin/convert') }
  end

  remote_file '/opt/openOffice.tar.gz' do
    source node['alfresco']['openOffice']
    owner 'root'
    group 'root'
    mode '775'
    action :create_if_missing
    not_if { File.exist?('/opt/openOffice/openoffice.org3/program/soffice') }
  end

  bash 'Install openOffice' do
    user 'root'
    cwd '/opt'
    code <<-EOH
    tar xvf openOffice.tar.gz
    mv Apache_OpenOffice_incubating_3.4.0_Solaris_x86_install-arc_en-US openOffice
    chmod -R 700 openOffice
      EOH
    not_if { File.exist?('/opt/openOffice/openoffice.org3/program/soffice') }
  end

  bash 'cleanup zip files' do
    user 'root'
    cwd '/tmp'
    code <<-EOH
    rm -rf /opt/freetype*
    rm -rf /opt/openOffice.tar.gz
    rm -rf /opt/jpeg*
    rm -rf /opt/ghostscript*
    EOH
  end

end
  