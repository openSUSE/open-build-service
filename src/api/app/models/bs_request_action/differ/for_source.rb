class BsRequestAction
  module Differ
    class ForSource
      include ActiveModel::Model
      attr_accessor :bs_request_action, :source_package_names
      attr_writer :options

      def perform
        source_package_names.map do |source_package_name|
          diff(source_package_name)
        end.join
      end

      private

      def diff(source_package_name)
        if accepted?
          query_builder = QueryBuilderForAccepted.new(
            bs_request_action_accept_info: bs_request_action.bs_request_action_accept_info
          )
          source_diff(target_project_name, target_package_name, query.merge(query_builder.build))
        else
          query_builder = QueryBuilder.new(
            action: bs_request_action,
            target_project: target_project_name,
            target_package: target_package_name,
            source_package: source_package_name
          )
          source_diff(bs_request_action.source_project, source_package_name, query.merge(query_builder.build))
        end
      end

      def query
        query = {}
        query[:view] = :xml if options[:view].to_s == 'xml'
        query[:withissues] = 1 if options[:withissues].present?
        query[:filelimit] = options[:filelimit] ? options[:filelimit].to_i : 10_000
        query[:tarlimit] = options[:tarlimit] ? options[:tarlimit].to_i : 10_000
        query
      end

      def source_diff(project_name, package_name, query)
        Backend::Api::Sources::Package.source_diff(project_name, package_name, query)
      rescue Timeout::Error
        raise DiffError, "Timeout while diffing #{project_name}/#{package_name}"
      rescue ActiveXML::Transport::Error => e
        raise DiffError, "The diff call for #{project_name}/#{package_name} failed: #{e.summary}"
      end

      def accepted?
        # We need to check for the BsRequestActionAcceptInfo
        # Checking only for the state is not enough
        # as there was no BsRequestActionAcceptInfo in OBS version < 2.1
        bs_request_action.bs_request_action_accept_info.present?
      end

      def target_package_name
        bs_request_action.target_package
      end

      def target_project_name
        bs_request_action.target_project
      end

      def options
        @options || {}
      end
    end
  end
end
