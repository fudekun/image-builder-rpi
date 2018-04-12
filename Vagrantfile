# -*- mode: ruby -*-
# vi: set ft=ruby :
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'virtualbox'

Vagrant.configure(2) do |config|
  #config.vm.box = "boxcutter/ubuntu1404"
  config.vm.box = "bento/ubuntu-16.04"

  config.vm.network "forwarded_port", guest: 2376, host: 2376, auto_correct: true
  config.vm.synced_folder ".", "#{`pwd`.chomp}"

  config.vm.provider "vmware_fusion" do |v|
    # Customize the amount of memory on the VM:
    v.memory = "8192"
  end

  config.vm.provider "virtualbox" do |vb|
    # Customize the amount of memory on the VM:
    #vb.memory = "2048"
    vb.customize ["modifyvm", :id, "--memory", "8192", "--cpus", "4", "--ioapic", "on"]
  end

  config.vm.provision "shell", inline: <<-SHELL
     #sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
     #echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" > /etc/apt/sources.list.d/docker.list
     #sudo apt-get update
     #sudo apt-get install -y linux-image-extra-$(uname -r)
     #sudo apt-get install -y docker-engine
     sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
     curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
     sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
     sudo apt-get update
     sudo apt-get install -y linux-image-extra-$(uname -r)
     sudo apt-get install -y docker-ce
  SHELL
end
