class BsRequestAction
  module Differ
    class SourcePackageFinder
      include ActiveModel::Model
      attr_accessor :bs_request_action
      attr_writer :options

      def all
        return [bs_request_action.source_package] if bs_request_action.bs_request_action_accept_info # the old package can be gone

        if bs_request_action.source_package
          bs_request_action.source_access_check! unless skip_access_check?
          return [bs_request_action.source_package]
        else
          project = Project.find_by_name(bs_request_action.source_project)
          return [] unless project

          return project.packages.map do |package|
            package.check_source_access! unless skip_access_check?
            package.name
          end
        end
      end

      private

      def options
        @options || {}
      end

      def skip_access_check?
        options[:skip_access_check] == true
      end
    end
  end
end
