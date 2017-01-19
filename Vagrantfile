# -*- mode: ruby -*-
# vi: set ft=ruby :

dev_mem = (ENV["OBS_VAGRANT_MEM"]) ? ENV["OBS_VAGRANT_MEM"] : 2048
dev_cpu = (ENV["OBS_VAGRANT_CPU"]) ? ENV["OBS_VAGRANT_CPU"] : 2

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = '2'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  #calculate memory allocation
  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.define "development" , primary: true do |fe|
    fe.vm.box = 'opensuse/openSUSE-42.1-x86_64'
    # Provision the box with a simple shell script
    fe.vm.provision :shell, inline: '/vagrant/contrib/bootstrap.sh'
    fe.vm.provision :shell, inline: 'mount /vagrant/src/api/tmp', run: "always"
    fe.vm.provision :shell, inline: 'chown -R vagrant:users /vagrant/src/api/tmp', run: "always"

    # Execute commands in the frontend directory
    fe.exec.commands %w(rails rake rspec bundle), directory: '/vagrant/src/api'
    fe.exec.commands %w(rails rake rspec bundle), env: {'PATH' => './bin:$PATH'}
    fe.exec.commands 'script/start_test_backend', directory: '/vagrant/src/api'
    fe.exec.commands 'contrib/start_development_backend', directory: '/vagrant'
    fe.exec.commands '*', directory: '/vagrant'
    fe.vm.network :forwarded_port, guest: 3000, host: 3000

    # FIXME: Setting group/owner is a temporary fix for
    # https://github.com/mitchellh/vagrant/issues/7616
    fe.vm.synced_folder "src/api/tmp/capybara/", "/vagrant/src/api/tmp/capybara", create: true, owner: "vagrant", group: 100
    fe.vm.synced_folder ".", "/vagrant", owner: "vagrant", group: 100
  end

  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
  # config.vm.box_url = "http://domain.com/path/to/above.box"

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network :private_network, ip: '10.0.2.15', virtualbox__intnet: true

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network :public_network

  # If true, then any SSH connections made will enable agent forwarding.
  # Default value: false
  # config.ssh.forward_agent = true

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Use 1Gb of RAM for Vagrant box (otherwise bundle will go to swap)
  config.vm.provider :virtualbox do |vb|
    vb.customize ['modifyvm', :id, '--memory', dev_mem]
    vb.customize ['modifyvm', :id, '--cpus', dev_cpu]
    vb.destroy_unused_network_interfaces = true

    config.vm.provision :shell, inline: <<SCRIPT
. /vagrant/contrib/common.sh
SCRIPT
  end

  config.vm.provider :libvirt do |lv|
      # Still having permissions problems with synced_folder 9p but keeping this
      # for documentation purpose
      # config.vm.synced_folder './', '/vagrant', type: '9p', disabled: false
  end

end
