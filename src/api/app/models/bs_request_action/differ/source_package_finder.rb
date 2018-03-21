class BsRequestAction
  module Differ
    class SourcePackageFinder
      include ActiveModel::Model
      attr_accessor :bs_request_action

      def all
        return [bs_request_action.source_package] if bs_request_action.bs_request_action_accept_info # the old package can be gone

        if bs_request_action.source_package
          bs_request_action.source_access_check!
          return [bs_request_action.source_package]
        else
          project = Project.find_by_name(bs_request_action.source_project)
          return [] unless project

          return project.packages.map do |package|
            package.check_source_access!
            package.name
          end
        end
      end
    end
  end
end
