module Webui
  module Packages
    class MetaController < WebuiController
      before_action :set_project
      before_action :require_package
      before_action :validate_xml, only: :update
      after_action :verify_authorized, only: :update

      def show
        @meta = @package.render_xml
      end

      def update
        errors = []

        authorize @package, :save_meta_update?

        if FlagHelper.xml_disabled_for?(@meta_xml, 'sourceaccess')
          errors << 'admin rights are required to raise the protection level of a package'
        end

        if @meta_xml['project'] && @meta_xml['project'] != @project.name
          errors << 'project name in xml data does not match resource path component'
        end

        if @meta_xml['name'] && @meta_xml['name'] != @package.name
          errors << 'package name in xml data does not match resource path component'
        end

        if errors.empty?
          begin
            @package.update_from_xml(@meta_xml)
            flash.now[:success] = 'The Meta file has been successfully saved.'
            status = 200
          rescue Backend::Error, NotFoundError => e
            flash.now[:error] = "Error while saving the Meta file: #{e}."
            status = 400
          end
        else
          flash.now[:error] = "Error while saving the Meta file: #{errors.compact.join("\n")}."
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
        render layout: false, status: 400, partial: 'layouts/webui/flash', object: flash
      end
    end
  end
end
