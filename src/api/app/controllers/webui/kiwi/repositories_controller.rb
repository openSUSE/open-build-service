module Webui
  module Kiwi
    class RepositoriesController < WebuiController
      before_action :set_image

      def index
        @repositories = @image.repositories.order(:order)
        @package = @image.package
        @project = @package.project
      end

      def edit
        @repositories = @image.repositories.order(:order)
        @package = @image.package
        @project = @package.project
      end

      def update
        ::Kiwi::Image.transaction do
          @image.update_attributes!(image_params)
          @image.write_to_backend
        end
        redirect_to action: :index
      rescue => e
        flash[:error] = "Cannot update repositories for kiwi image: #{@image.errors.full_messages.to_sentence} #{e.message}"
        redirect_back(fallback_location: root_path)
      end

      private

      def image_params
        params.require(:image).permit(repositories_attributes:
                                      [:id, :priority, :repo_type, :source_path, :alias,
                                       :username, :password, :prefer_license, :imageinclude, :replaceable])
      end

      def set_image
        params.require(:kiwi_image_id)
        load_kiwi_image(params[:kiwi_image_id])
      end
    end
  end
end
