# -*- mode: ruby -*-
# vi: set ft=ruby :

dev_mem = ENV["OBS_VAGRANT_MEM"] ? ENV["OBS_VAGRANT_MEM"] : 2048
dev_cpu = ENV["OBS_VAGRANT_CPU"] ? ENV["OBS_VAGRANT_CPU"] : 2

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = '2'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Calculate memory allocation
  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.define "development", primary: true do |fe|
    fe.vm.box = 'opensuse/openSUSE-42.2-x86_64'
    # Provision the box with a simple shell script
    fe.vm.provision :shell, inline: '/vagrant/contrib/bootstrap.sh'
    fe.vm.provision :shell, inline: 'mount /vagrant/src/api/tmp', run: "always"
    fe.vm.provision :shell, inline: 'chown -R vagrant:users /vagrant/src/api/tmp', run: "always"

    # Execute commands in the frontend directory
    fe.exec.commands %w(rails rake rspec bundle foreman), directory: '/vagrant/src/api'
    fe.exec.commands %w(rails rake rspec bundle foreman), env: {'PATH' => './bin:$PATH'}
    fe.exec.commands 'script/start_test_backend', directory: '/vagrant/src/api'
    fe.exec.commands 'contrib/start_development_backend', directory: '/vagrant'
    fe.exec.commands '*', directory: '/vagrant'
    fe.vm.network :forwarded_port, guest: 3000, host: 3000
    fe.vm.network :forwarded_port, guest: 3306, host: 3306
  end

  # Use 1Gb of RAM for Vagrant box (otherwise bundle will go to swap)
  config.vm.provider :virtualbox do |vb|
    vb.customize ['modifyvm', :id, '--memory', dev_mem]
    vb.customize ['modifyvm', :id, '--cpus', dev_cpu]
    vb.destroy_unused_network_interfaces = true
  end
end
