module MultibuildPackage
  extend ActiveSupport::Concern

  class_methods do
    def striping_multibuild_suffix(name)
      # exception for package names used to have a collon
      return name if name.start_with?('_patchinfo:', '_product:')

      name.gsub(/:.*$/, '')
    end

    def multibuild_flavor(name)
      # exception for package names used to have a collon
      return if name.start_with?('_patchinfo:', '_product:')
      return unless name.include?(':')

      name.gsub(/^.*:/, '')
    end
  end

  def multibuild?
    file_exists?('_multibuild', expand: 1)
  end

  def multibuild_flavor?(name)
    return false unless multibuild?

    # Support passing both with and without prefix.
    # Like package:flavor or just flavor
    name = name.split(':', 2).last
    multibuild_flavors.include?(name)
  end

  def multibuild_flavors
    return [] unless multibuild?

    flavors = Xmlhash.parse(source_file('_multibuild'))['flavor']
    return [flavors] if flavors.is_a?(String)

    flavors
  end
end
