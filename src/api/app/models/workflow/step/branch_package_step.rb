class Workflow
  module Step
    class BranchPackageStep
      include ActiveModel::Model

      validates :source_project, :source_package, presence: true

      def initialize(step_instructions:, scm_extractor_payload:)
        @step_instructions = step_instructions.with_indifferent_access
        @scm_extractor_payload = scm_extractor_payload.with_indifferent_access
      end

      def allowed_event_and_action?
        new_pull_request?
      end

      def call
        return unless valid? && new_pull_request?

        branched_package = branch
        return unless branched_package

        add_branch_request_file(package: branched_package)

        branched_package
      end

      private

      def source_project
        @step_instructions['source_project']
      end

      def source_package
        @step_instructions['source_package']
      end

      def target_package
        return @step_instructions['target_package'] if @step_instructions['target_package'].present?

        source_package
      end

      def target_project
        source_project + ":PR-#{@scm_extractor_payload[:pr_number]}"
      end

      def remote_source?
        return true if Project.find_remote_project(source_project)

        false
      end

      def check_source_access
        return if remote_source?

        options = { use_source: false, follow_project_links: true, follow_multibuild: true }
        src_package = Package.get_by_project_and_name(source_project, source_package, options)

        raise Pundit::NotAuthorizedError unless PackagePolicy.new(User.session, src_package).create_branch?
      end

      def branch
        check_source_access

        BranchPackage.new({ project: source_project, package: source_package,
                            target_project: target_project,
                            target_package: target_package }).branch

        Event::BranchCommand.create(project: source_project, package: source_package,
                                    targetproject: target_project,
                                    targetpackage: target_package,
                                    user: User.session.login)

        Package.find_by_project_and_name(target_project, target_package)
      rescue BranchPackage::DoubleBranchPackageError, CreateProjectNoPermission,
             ArgumentError, Package::UnknownObjectError,
             Project::UnknownObjectError, APIError, ActiveRecord::RecordInvalid
        nil
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

      def add_branch_request_file(package:)
        branch_request_file = case @scm_extractor_payload[:scm]
                              when 'github'
                                branch_request_file_github
                              when 'gitlab'
                                branch_request_file_gitlab
                              end

        package.save_file({ file: branch_request_file, filename: '_branch_request' })
      end

      def branch_request_file_github
        {
          action: @scm_extractor_payload[:action],
          pull_request: {
            head: {
              repo: { full_name: @scm_extractor_payload[:source_repository_full_name] },
              sha: @scm_extractor_payload[:commit_sha]
            }
          }
        }.to_json
      end

      def branch_request_file_gitlab
        { object_kind: @scm_extractor_payload[:object_kind],
          project: { http_url: @scm_extractor_payload[:http_url] },
          object_attributes: { source: { default_branch: @scm_extractor_payload[:commit_sha] } } }.to_json
      end
    end
  end
end
