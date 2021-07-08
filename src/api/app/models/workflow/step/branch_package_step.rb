# rubocop:disable Metrics/ClassLength
# This class will be refactored to use a ActiveModel::Validator
class Workflow
  module Step
    class BranchPackageStep
      include ActiveModel::Model

      validates :source_project_name, :source_package_name, presence: true

      def initialize(step_instructions:, scm_extractor_payload:, token:)
        @step_instructions = step_instructions.with_indifferent_access
        @scm_extractor_payload = scm_extractor_payload.with_indifferent_access
        @token = token
      end

      def allowed_event_and_action?
        new_pull_request? || updated_pull_request?
      end

      def call(options = {})
        # TODO: Raise to let user know that their workflow configuration is wrong
        return unless valid? && allowed_event_and_action?

        branched_package = find_or_create_branched_package

        add_or_update_branch_request_file(package: branched_package)

        workflow_filters = options.fetch(:workflow_filters, [])
        create_or_update_subscriptions(branched_package, workflow_filters)

        workflow_repositories(target_project_name, workflow_filters).each do |repository|
          # TODO: Fix n+1 queries
          workflow_architectures(repository, workflow_filters).each do |architecture|
            # We cannot report multibuild flavors here... so they will be missing from the initial report
            SCMStatusReporter.new({ project: target_project_name, package: target_package_name, repository: repository.name, arch: architecture.name },
                                  @scm_extractor_payload, @token.scm_token).call
          end
        end

        branched_package
      end

      def source_project_name
        @step_instructions['source_project']
      end

      def source_package_name
        @step_instructions['source_package']
      end

      def target_package_name
        return @step_instructions['target_package'] if @step_instructions['target_package'].present?

        source_package_name
      end

      def target_project_name
        "home:#{@token.user.login}:#{source_project_name}:PR-#{@scm_extractor_payload[:pr_number]}"
      end

      private

      def target_package
        Package.find_by_project_and_name(target_project_name, target_package_name)
      end

      def find_or_create_branched_package
        return target_package if updated_pull_request? && target_package.present?

        branch
      end

      def remote_source?
        return true if Project.find_remote_project(source_project_name)

        false
      end

      def check_source_access
        return if remote_source?

        options = { use_source: false, follow_project_links: true, follow_multibuild: true }

        begin
          src_package = Package.get_by_project_and_name(source_project_name, source_package_name, options)
        rescue Package::UnknownObjectError
          raise BranchPackage::Errors::CanNotBranchPackageNotFound, "Package #{source_project_name}/#{source_package_name} not found, it could not be branched."
        end

        Pundit.authorize(@token.user, src_package, :create_branch?)
      end

      def branch
        check_source_access

        begin
          BranchPackage.new({ project: source_project_name, package: source_package_name,
                              target_project: target_project_name,
                              target_package: target_package_name }).branch
        rescue BranchPackage::InvalidArgument, InvalidProjectNameError, ArgumentError => e
          raise BranchPackage::Errors::CanNotBranchPackage, "Package #{source_project_name}/#{source_package_name} could not be branched: #{e.message}"
        rescue Project::WritePermissionError, CreateProjectNoPermission => e
          raise BranchPackage::Errors::CanNotBranchPackageNoPermission,
                "Package #{source_project_name}/#{source_package_name} could not be branched due to missing permissions: #{e.message}"
        end

        Event::BranchCommand.create(project: source_project_name, package: source_package_name,
                                    targetproject: target_project_name,
                                    targetpackage: target_package_name,
                                    user: @token.user.login)

        target_package
      end

      def github_pull_request?
        @scm_extractor_payload[:scm] == 'github' && @scm_extractor_payload[:event] == 'pull_request'
      end

      def gitlab_merge_request?
        @scm_extractor_payload[:scm] == 'gitlab' && @scm_extractor_payload[:event] == 'Merge Request Hook'
      end

      def new_pull_request?
        (github_pull_request? && @scm_extractor_payload[:action] == 'opened') ||
          (gitlab_merge_request? && @scm_extractor_payload[:action] == 'open')
      end

      def updated_pull_request?
        (github_pull_request? && @scm_extractor_payload[:action] == 'synchronize') ||
          (gitlab_merge_request? && @scm_extractor_payload[:action] == 'update')
      end

      def add_or_update_branch_request_file(package:)
        branch_request_file = case @scm_extractor_payload[:scm]
                              when 'github'
                                branch_request_content_github
                              when 'gitlab'
                                branch_request_content_gitlab
                              end

        package.save_file({ file: branch_request_file, filename: '_branch_request' })
      end

      def branch_request_content_github
        {
          # TODO: change to @scm_extractor_payload[:action]
          # when check_for_branch_request method in obs-service-tar_scm accepts other actions than 'opened'
          # https://github.com/openSUSE/obs-service-tar_scm/blob/2319f50e741e058ad599a6890ac5c710112d5e48/TarSCM/tasks.py#L145
          action: 'opened',
          pull_request: {
            head: {
              repo: { full_name: @scm_extractor_payload[:source_repository_full_name] },
              sha: @scm_extractor_payload[:commit_sha]
            }
          }
        }.to_json
      end

      def branch_request_content_gitlab
        { object_kind: @scm_extractor_payload[:object_kind],
          project: { http_url: @scm_extractor_payload[:http_url] },
          object_attributes: { source: { default_branch: @scm_extractor_payload[:commit_sha] } } }.to_json
      end

      def create_or_update_subscriptions(branched_package, workflow_filters)
        ['Event::BuildFail', 'Event::BuildSuccess'].each do |build_event|
          subscription = EventSubscription.find_or_create_by!(eventtype: build_event,
                                                              receiver_role: 'reader', # We pass a valid value, but we don't need this.
                                                              user: @token.user,
                                                              channel: 'scm',
                                                              enabled: true,
                                                              token: @token,
                                                              package: branched_package)
          subscription.update!(payload: @scm_extractor_payload.merge({ workflow_filters: workflow_filters }))
        end
      end

      # TODO: This could be in a query object
      def workflow_repositories(target_project_name, filters)
        repositories = Project.get_by_name(target_project_name).repositories
        return repositories if filters.blank?

        return repositories.where(name: filters[:repositories][:only]) if filters[:repositories][:only]

        return repositories.where.not(name: filters[:repositories][:ignore]) if filters[:repositories][:ignore]

        repositories
      end

      # TODO: This could be in a query object
      def workflow_architectures(repository, filters)
        architectures = repository.architectures
        return architectures if filters.blank?

        return architectures.where(name: filters[:architectures][:only]) if filters[:architectures][:only]

        return architectures.where.not(name: filters[:architectures][:ignore]) if filters[:architectures][:ignore]

        architectures
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
