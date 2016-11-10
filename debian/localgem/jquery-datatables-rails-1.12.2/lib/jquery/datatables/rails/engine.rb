# Configure for Rails 3.1
module Jquery
  module Datatables
    if defined?(::Rails) and Gem::Requirement.new('>= 3.1').satisfied_by?(Gem::Version.new ::Rails.version)
      module Rails
        class Engine < ::Rails::Engine
        end
      end
    end
  end
end
