# https://github.com/Shopify/liquid/wiki/Introduction-to-Drops
module PackageService
  class Templater::ProjectDrop < ::Liquid::Drop
    def initialize(project)
      @project = project
      super()
    end

    delegate :name, to: :@project

    delegate :title, to: :@project

    delegate :url, to: :@project

    delegate :description, to: :@project
  end
end
