module Webui
  module Kiwi
    class RepositoriesController < Webui::WebuiController
      def index
        @image = ::Kiwi::Image.find(params[:kiwi_image_id])
        @repositories = @image.repositories.order(:order)
        @package = @image.package
        @project = @package.project
      end
    end
  end
end
