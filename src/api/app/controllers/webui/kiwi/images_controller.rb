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

        redirect_to kiwi_image_repositories_path(package.kiwi_image)
      end

      def show
        render json: { is_outdated: @image.package.kiwi_image_outdated? }
      end

      private

      def set_image
        params.require(:id)
        load_kiwi_image(params[:id])
      end
    end
  end
end
