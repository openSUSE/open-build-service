All .rb files in this directory will be required (to require
the engine itself) and after the application routes are setup,
the mount\_it functions are called, so the engines can be mounted

  require '/usr/share/obs_factory/lib/obs_factory.rb'

  class LoadFactoryEngine < OBSEngine::Base
    def self.mount_it
      OBSApi::Application.routes.draw do
        mount ObsFactory::Engine => "/factory"
      end
    end
  end

