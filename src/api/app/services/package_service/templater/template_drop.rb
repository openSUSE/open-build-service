# https://github.com/Shopify/liquid/wiki/Introduction-to-Drops
module PackageService
  class Templater::TemplateDrop < ::Liquid::Drop
    def initialize(data)
      @data = data

      super()
    end

    def liquid_method_missing(method)
      return @data[method] if @data.key?(method)

      super
    end
  end
end
