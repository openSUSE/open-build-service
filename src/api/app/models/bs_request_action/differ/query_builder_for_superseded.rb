class BsRequestAction
  module Differ
    class QueryBuilderForSuperseded
      include ActiveModel::Model
      attr_accessor :superseded_bs_request_action, :bs_request_action, :source_package_name

      def build
        query = {}
        if accepted?
          query[:rev] = bs_request_action_accept_info.oxsrcmd5 || bs_request_action_accept_info.osrcmd5 || '0'
          query[:orev] = superseded_bs_request_action.source_rev
          query[:oproject] = superseded_bs_request_action.source_project
          query[:opackage] = superseded_bs_request_action.source_package
        else
          query[:rev] = bs_request_action.source_rev || '0'
          query[:orev] = superseded_bs_request_action.source_rev || '0'
          unless same_source_package?
            query[:oproject] = superseded_bs_request_action.source_project
            query[:opackage] = superseded_bs_request_action.source_package
          end
        end
        query
      end

      def project_name
        if accepted?
          bs_request_action_accept_info.oproject.presence || bs_request_action.target_project
        else
          bs_request_action.source_project
        end
      end

      def package_name
        if accepted?
          bs_request_action_accept_info.opackage.presence || bs_request_action.target_package
        else
          bs_request_action.source_package
        end
      end

      private

      def bs_request_action_accept_info
        bs_request_action.bs_request_action_accept_info
      end

      def accepted?
        bs_request_action_accept_info.present?
      end

      def same_source_package?
        superseded_bs_request_action.source_project == bs_request_action.source_project &&
          superseded_bs_request_action.source_package == source_package_name
      end
    end
  end
end
