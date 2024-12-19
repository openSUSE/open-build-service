module Webui
  module Packages
    class BsRequestsController < Webui::WebuiController
      before_action :set_project
      before_action :require_package
      include Webui::RequestsFilter

      def index
        if Flipper.enabled?(:request_index, User.session)
          filter_requests

          @url = packages_requests_path(@project, @package)
          @bs_requests = @bs_requests.order('number DESC').page(params[:page])
          @bs_requests = @bs_requests.includes(:bs_request_actions, :comments, :reviews)
          @bs_requests = @bs_requests.includes(:labels) if Flipper.enabled?(:labels, User.session)
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

      def filter_by_direction(direction)
        return filter_by_direction_staging_project(direction) if staging_projects.present?

        case direction
        when 'all'
          target = BsRequest.with_actions_and_reviews.where(bs_request_actions: { target_project: @project.name, target_package: @package.name })
          source = BsRequest.with_actions_and_reviews.where(bs_request_actions: { source_project: @project.name, source_package: @package.name })
          reviews = BsRequest.with_actions_and_reviews.where(reviews: { package: @package })
          target.or(source).or(reviews)
        when 'incoming'
          BsRequest.with_actions.where(bs_request_actions: { target_project: @project.name, target_package: @package.name })
        when 'outgoing'
          BsRequest.with_actions.where(bs_request_actions: { source_project: @project.name, source_package: @package.name })
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
    end
  end
end
