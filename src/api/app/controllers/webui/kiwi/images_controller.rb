module Webui
  module Kiwi
    class ImagesController < WebuiController
      before_action :set_image, except: [:import_from_package]

      def import_from_package
        package = Package.find(params[:package_id])

        kiwi_file = package.kiwi_image_file

        unless kiwi_file
          redirect_back fallback_location: root_path, error: 'There is no KIWI file'
          return
        end

        package.kiwi_image.destroy if package.kiwi_image && package.kiwi_image_outdated?

        if package.kiwi_image.blank? || package.kiwi_image.destroyed?
          package.kiwi_image = ::Kiwi::Image.build_from_xml(package.source_file(kiwi_file), package.kiwi_file_md5)
          unless package.save
            errors = ["Kiwi File '#{kiwi_file}' has errors:", package.kiwi_image.errors.full_messages].join('<br />')
            redirect_back fallback_location: root_path, error: errors
            return
          end
        end

        redirect_to kiwi_image_path(package.kiwi_image)
      end

      def show
        respond_to do |format|
          format.html do
            @repositories = @image.repositories.order(:order)
            @package = @image.package
            @project = @package.project
          end
          format.json { render json: { is_outdated: @image.outdated? } }
        end
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
        redirect_to action: :show
      rescue ActiveRecord::RecordInvalid, Timeout::Error => e
        flash[:error] = "Cannot update repositories for kiwi image: #{@image.errors.full_messages.to_sentence} #{e.message}"
        redirect_back(fallback_location: root_path)
      end

      private

      def image_params
        params.require(:kiwi_image).permit(repositories_attributes:
                                      [:id, :priority, :repo_type, :source_path, :alias,
                                       :username, :password, :prefer_license, :imageinclude, :replaceable])
      end

      def set_image
        @image = ::Kiwi::Image.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        flash[:error] = "KIWI image '#{params[:id]}' does not exist"
        redirect_back(fallback_location: root_path)
      end
    end
  end
end
