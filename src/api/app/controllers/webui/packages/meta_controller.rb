module Webui
  module Packages
    class MetaController < Webui::WebuiController
      before_action :set_project
      before_action :set_package

      before_action :validate_xml, only: :update
      before_action :check_sourceaccess, only: :update
      before_action :changed_project, only: :update
      before_action :changed_package, only: :update

      after_action :verify_authorized, only: :update

      def show
        if @project.scmsync.present?
          flash.now[:error] = "Package sources for project #{@project.name} are received through scmsync." \
                              'This is not supported by the OBS frontend'
          render :show, status: :not_found
        else
          @meta = @package.render_xml
        end
      end

      def update
        authorize @package, :save_meta_update?

        begin
          @package.update_from_xml(@meta_xml)
          flash.now[:success] = 'The Meta file has been successfully saved.'
          status = 200
        rescue Backend::Error, NotFoundError, Package::Errors::SaveError => e
          flash.now[:error] = "Error while saving the Meta file: #{e}."
          status = 400
        end

        render layout: false, status: status, partial: 'layouts/webui/flash', object: flash
      end

      private

      def validate_xml
        Suse::Validator.validate('package', params[:meta])
        @meta_xml = Xmlhash.parse(params[:meta])
      rescue Suse::ValidationError => e
        flash.now[:error] = "Error while saving the Meta file: #{e}."
        render layout: false, status: :bad_request, partial: 'layouts/webui/flash', object: flash
      end

      def check_sourceaccess
        return unless FlagHelper.xml_disabled_for?(@meta_xml, 'sourceaccess')

        flash.now[:error] = 'Error while saving the Meta file: admin rights are required to raise the protection level of a package.'
        render layout: false, status: :bad_request, partial: 'layouts/webui/flash', object: flash
      end

      def changed_project
        return unless @meta_xml['project'] && @meta_xml['project'] != @project.name

        flash.now[:error] = 'Error while saving the Meta file: project name in xml data does not match resource path component.'
        render layout: false, status: :bad_request, partial: 'layouts/webui/flash', object: flash
      end

      def changed_package
        return unless @meta_xml['name'] && @meta_xml['name'] != @package.name

        flash.now[:error] = 'Error while saving the Meta file: package name in xml data does not match resource path component.'
        render layout: false, status: :bad_request, partial: 'layouts/webui/flash', object: flash
      end
    end
  end
end
