module ProjectStatusControllerService
  class AttribValuesFinder
    attr_reader :packages, :name, :namespace

    def initialize(packages, namespace, name)
      @packages = packages
      @name = name
      @namespace = namespace
    end

    def self.call
      raise AbstractMethodCalled
    end

    def attribute_values
      AttribValue.where(attrib_id: package_ids_by_attribute_type).joins(:attrib).pluck('attribs.package_id, value')
    end

    private

    def attribute_type
      @attribute_type ||= AttribType.find_by_namespace_and_name(@namespace, @name)
    end

    def package_ids_by_attribute_type
      return if attribute_type.nil?

      attribute_type.attribs.where(package_id: @packages)
    end
  end
end
