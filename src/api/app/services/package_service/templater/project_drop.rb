# https://github.com/Shopify/liquid/wiki/Introduction-to-Drops
module PackageService
  class Templater::ProjectDrop < ::Liquid::Drop
    def initialize(project)
      @project = project
      super()
    end

    def name
      @project.name
    end

    def title
      @project.title
    end

    def url
      @project.url
    end

    def description
      @project.description
    end
  end
end
