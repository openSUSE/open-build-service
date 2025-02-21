module Webui
  module Packages
    class BsRequestsController < Webui::WebuiController
      include Webui::RequestsFilter

      before_action :set_project
      before_action :require_package
      before_action :redirect_legacy
      before_action :set_bs_requests

      def index
        if Flipper.enabled?(:request_index, User.session)
          # FIXME: Once we roll out filter_requests should become a before_action
          filter_requests
          @bs_requests = @bs_requests.page(params[:page])

          @url = packages_requests_path(@project, @package)
        else
          parsed_params = BsRequest::DataTable::ParamsParserWithStateAndType.new(params).parsed_params
          requests_query = BsRequest::DataTable::FindForPackageQuery.new(@project, @package, parsed_params)
          @requests_data_table = BsRequest::DataTable::Table.new(requests_query, params[:draw])

          respond_to do |format|
            format.json { render 'webui/shared/bs_requests/index' }
          end
        end
      end

      private

      def set_bs_requests
        return unless Flipper.enabled?(:request_index, User.session)

        @bs_requests = @package.bs_requests
      end

      def filter_involvement
        @filter_involvement = params[:involvement].presence
        return unless %w[incoming outgoing].include?(@filter_involvement)

        @bs_requests = case @filter_involvement
                       when 'incoming'
                         @bs_requests.to_project(@project.name).to_package(@package.name)
                       when 'outgoing'
                         @bs_requests.from_project(@project.name).from_package(@package.name)
                       when 'review'
                         @bs_requests.where(reviews: { by_package: name })
                       end
      end

      def filter_by_direction_staging_project(direction)
        case direction
        when 'all'
          target = BsRequest.with_actions_and_reviews.where(staging_project: staging_projects, bs_request_actions: { target_project: @project.name, target_package: @package.name })
          source = BsRequest.with_actions_and_reviews.where(staging_project: staging_projects, bs_request_actions: { source_project: @project.name, source_package: @package.name })
          reviews = BsRequest.with_actions_and_reviews.where(staging_project: staging_projects, reviews: { package: @package })
          target.or(source).or(reviews)
        when 'incoming'
          BsRequest.with_actions.where(staging_project: staging_projects, bs_request_actions: { target_project: @project.name, target_package: @package.name })
        when 'outgoing'
          BsRequest.with_actions.where(staging_project: staging_projects, bs_request_actions: { source_project: @project.name, source_package: @package.name })
        end
      end

      def redirect_legacy
        redirect_to(package_requests_path(@project, @package)) unless Flipper.enabled?(:request_index, User.session) || request.format.json?
      end
    end
  end
end
