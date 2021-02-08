class BsRequestAction
  module Differ
    class ForSource
      include ActiveModel::Model

      # FIXME: this default either must be changed in backend
      # or it should only be used for specific views
      DEFAULT_FILE_LIMIT = 10_000

      attr_accessor :bs_request_action, :source_package_names
      attr_writer :options

      def perform
        source_package_names.map do |source_package_name|
          diff(source_package_name)
        end.join
      end

      private

      def diff(source_package_name)
        if superseded_bs_request_action.present?
          query_builder = QueryBuilderForSuperseded.new(
            superseded_bs_request_action: superseded_bs_request_action,
            bs_request_action: bs_request_action,
            source_package_name: source_package_name
          )
          source_diff(query_builder.project_name, query_builder.package_name, query.merge(query_builder.build))
        elsif bs_request_action.bs_request_action_accept_info.present?
          query_builder = QueryBuilderForAcceptinfo.new(
            bs_request_action_accept_info: bs_request_action.bs_request_action_accept_info
          )
          source_diff(bs_request_action.target_project, target_package_name, query.merge(query_builder.build))
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
        if options[:nodiff].present?
          query[:nodiff] = 1
        else
          query[:filelimit] = options[:filelimit] ? options[:filelimit].to_i : DEFAULT_FILE_LIMIT
          query[:tarlimit] = options[:tarlimit] ? options[:tarlimit].to_i : DEFAULT_FILE_LIMIT
        end
        query
      end

      def source_diff(project_name, package_name, query)
        Backend::Api::Sources::Package.source_diff(project_name, package_name, query)
      rescue Timeout::Error
        raise BsRequestAction::Errors::DiffError, "Timeout while diffing #{project_name}/#{package_name}"
      rescue Backend::Error => e
        raise BsRequestAction::Errors::DiffError, "The diff call for #{project_name}/#{package_name} failed: #{e.summary}"
      end

      def superseded_bs_request_action
        options[:superseded_bs_request_action]
      end

      def accepted?
        # We need to check for the BsRequestActionAcceptInfo
        # Checking only for the state is not enough
        # as there was no BsRequestActionAcceptInfo in OBS version < 2.1
        bs_request_action.bs_request_action_accept_info.present?
      end

      def target_package_name
        return bs_request_action.target_package if bs_request_action.target_package.present?

        if bs_request_action.is_maintenance_incident?
          pkg = Package.find_by_project_and_name(bs_request_action.source_project, bs_request_action.source_package)
          # local link handling is needed? usually there should be no maintenance_incident projects for them ...
          return pkg.linkinfo['package'] if pkg&.linkinfo
        end
        nil
      end

      def target_project_name
        return bs_request_action.target_releaseproject if bs_request_action.is_maintenance_incident?

        return bs_request_action.target_project if bs_request_action.target_project.present?

        pkg = Package.get_by_project_and_name(bs_request_action.source_project, bs_request_action.source_package)
        return pkg.origin_container({ local: false }).project.name if pkg

        nil
      end

      def options
        @options || {}
      end
    end
  end
end
