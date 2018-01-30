# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box_check_update = false

  # Work around a problem where ssh.forward_agent fails for root
  config.vm.provision :shell do |shell|
    shell.inline = "touch $1 && chmod 0440 $1 && echo $2 > $1"
    shell.args = %q{/etc/sudoers.d/root_ssh_agent "Defaults    env_keep += \"SSH_AUTH_SOCK\""}
  end

  config.vm.box = "ubuntu/xenial64"
  config.vm.provision :shell, :path => "VagrantProvision.sh", privileged: false
  config.ssh.forward_agent = true
  config.ssh.forward_x11 = true
  
  # Include a customized vagrant file for customizing things like RAM
  Vagrantcustom = File.join(File.expand_path(File.dirname(__FILE__)), 'Vagrantcustom')
  if File.exists?(Vagrantcustom) then
    eval(IO.read(Vagrantcustom), binding)
  end
  
  # Include an auto-generated file containing VM shares
  Vagrantshares = File.join(File.expand_path(File.dirname(__FILE__)), 'Vagrantshares')
  if File.exists?(Vagrantshares) then
    eval(IO.read(Vagrantshares), binding)
  end
  
  # Default NAT's DNS for Linux VM within MS-Windows VM does not always 
  # work, so the fix:
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end
  
end