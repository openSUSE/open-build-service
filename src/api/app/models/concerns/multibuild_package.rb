module MultibuildPackage
  extend ActiveSupport::Concern

  class_methods do
    def valid_multibuild_name?(name)
      valid_name?(name, true)
    end

    def striping_multibuild_suffix(name)
      # exception for package names used to have a collon
      return name if name.start_with?('_patchinfo:', '_product:')

      name.gsub(/:.*$/, '')
    end
  end

  def multibuild?
    @multibuild_flavors ||= Xmlhash.parse(Backend::Api::Sources::Package.multibuild_flavors(project, name)).elements('entry').collect { |x| x['name'] }
    return false if @multibuild_flavors.blank?

    true
  end

  def multibuild_flavor?(name)
    return false unless multibuild?

    # Support passing both with and without prefix.
    # Like package:flavor or just flavor
    name = name.split(':', 2).last
    @multibuild_flavors.include?(name)
  end

  def multibuild_flavors
    return [] unless multibuild?

    @mulitbuild_flavors
  end
end
