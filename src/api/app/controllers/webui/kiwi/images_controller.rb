module Webui
  module Kiwi
    class ImagesController < WebuiController
      before_action -> { feature_active?(:kiwi_image_editor) }
      before_action :set_image, except: [:import_from_package]
      before_action :authorize_update, except: [:import_from_package]

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
            redirect_to package_view_file_path(project: package.project, package: package, filename: kiwi_file), error: errors
            return
          end
        end

        redirect_to kiwi_image_path(package.kiwi_image)
      end

      def show
        respond_to do |format|
          format.html
          format.json { render json: { is_outdated: @image.outdated? } }
        end
      end

      def update
        ::Kiwi::Image.transaction do
          cleanup_non_project_repositories!

          @image.update_attributes!(image_params) unless params[:kiwi_image].empty?
          @image.write_to_backend
        end
        redirect_to action: :show
      rescue ActiveRecord::RecordInvalid, Timeout::Error => e
        flash[:error] = "Cannot update kiwi image: #{@image.errors.full_messages.to_sentence} #{e.message}"
        redirect_back(fallback_location: root_path)
      end

      def autocomplete_binaries
        binaries = @image.find_binaries_by_name(params[:term])
        autocomplete_result = []
        binaries.each do |package, _|
          autocomplete_result << {id: package, label: package, value: package}
        end
        render json: autocomplete_result
      end

      private

      def image_params
        repositories_attributes = [
          :id,
          :_destroy,
          :priority,
          :repo_type,
          :source_path,
          :alias,
          :username,
          :password,
          :prefer_license,
          :imageinclude,
          :replaceable,
          :order
        ]

        package_groups_attributes = [
          :id,
          :_destroy,
          packages_attributes: [:id, :name, :arch, :replaces, :bootdelete, :bootinclude, :_destroy]
        ]

        params.require(:kiwi_image).permit(
          :use_project_repositories,
          repositories_attributes: repositories_attributes,
          package_groups_attributes: package_groups_attributes
        )
      end

      def set_image
        @image = ::Kiwi::Image.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        flash[:error] = "KIWI image '#{params[:id]}' does not exist"
        redirect_back(fallback_location: root_path)
      end

      def authorize_update
        authorize @image, :update?
      end

      def cleanup_non_project_repositories!
        return unless params[:kiwi_image][:use_project_repositories] == '1'

        @image.repositories.delete_all
        params[:kiwi_image].delete(:repositories_attributes)
      end
    end
  end
end
