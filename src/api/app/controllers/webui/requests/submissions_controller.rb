module Webui
  module Requests
    class SubmissionsController < Webui::RequestController
      before_action :require_login
      before_action :strip_params, only: [:create]
      before_action :set_project
      before_action :set_package

      after_action :verify_authorized
      after_action :supersede_requests, only: [:create]

      def new
        bs_request_action = BsRequestAction.new(source_package: @package, source_project: @project,
                                                source_rev: params[:revision], type: 'submit')
        @bs_request = BsRequest.new(bs_request_actions: [bs_request_action])
        authorize @bs_request, :new?
      end

      # We rely on the super class. This is here to respect the RuboCop cop "Rails/LexicallyScopedActionFilter"
      def create # rubocop:disable Lint/UselessMethodDefinition
        super
      end

      private

      def strip_params
        # We strip values to avoid human errors... damn humans! (This is primarily for target project and target package)
        params['project_name'].strip!
        params['package_name'].strip!
        params[:bs_request][:bs_request_actions_attributes]['0'].transform_values!(&:strip)
      end

      def bs_request_params
        # We remove any key from the empty nested attribute if its value is empty
        # This is for target_package which might be empty since it's not required
        params[:bs_request][:bs_request_actions_attributes]['0'].compact_blank!

        params.require(:bs_request).permit(:description,
                                           bs_request_actions_attributes: %i[target_package target_project
                                                                             source_project source_package
                                                                             source_rev sourceupdate
                                                                             type])
      end

      # Superseded requests are marked as such after we're done creating the request superseding them
      def supersede_requests
        return unless params.key?(:supersede_request_numbers)

        supersede_errors = []
        params[:supersede_request_numbers].each do |request_number|
          BsRequest.find_by_number!(request_number)
                   .change_state(newstate: 'superseded',
                                 reason: "Superseded by request #{@bs_request.number}",
                                 superseded_by: @bs_request.number)
        rescue APIError => e
          supersede_errors << e.message.to_s
        rescue ActiveRecord::RecordNotFound
          supersede_errors << "Couldn't find request with id '#{request_number}'"
        end

        return if supersede_errors.empty?

        flash[:error] = "Superseding failed: #{supersede_errors.join('. ')}"
      end
    end
  end
end
