# https://github.com/Shopify/liquid/wiki/Introduction-to-Drops
module PackageService
  class Templater::PackageDrop < ::Liquid::Drop
    def initialize(package)
      @package = package
      super()
    end

    def name
      @package.name
    end

    def title
      @package.title
    end

    def url
      @package.url
    end

    def description
      @package.description
    end
  end
end
