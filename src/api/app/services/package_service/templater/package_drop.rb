# https://github.com/Shopify/liquid/wiki/Introduction-to-Drops
module PackageService
  class Templater::PackageDrop < ::Liquid::Drop
    def initialize(package)
      @package = package
      super()
    end

    delegate :name, to: :@package

    delegate :title, to: :@package

    delegate :url, to: :@package

    delegate :description, to: :@package
  end
end
