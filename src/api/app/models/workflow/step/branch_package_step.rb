class Workflow
  module Step
    class BranchPackageStep
      include ActiveModel::Model

      attr_reader :errors

      validates :source_project, :source_package, presence: true

      def initialize(step_instructions:, pr_number:)
        @step_instructions = step_instructions
        @pr_number = pr_number
        @errors = []
      end

      def call
        branch
      end

      private

      def source_project
        @step_instructions['source_project']
      end

      def source_package
        @step_instructions['source_package']
      end

      def destination_package
        return @step_instructions['destination_package'] if @step_instructions['destination_package'].present?

        source_package
      end

      def destination_project
        source_project + ":PR-#{@pr_number}"
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
                            target_project: destination_project,
                            target_package: destination_package }).branch

        Event::BranchCommand.create(project: source_project, package: source_package,
                                    targetproject: destination_project,
                                    targetpackage: destination_package,
                                    user: User.session.login)

        Package.find_by_project_and_name(destination_project, destination_package)
      rescue BranchPackage::DoubleBranchPackageError
        @errors << 'You have already branched this package'
      rescue CreateProjectNoPermission
        @errors << 'Sorry, you are not authorized to create this Project.'
      rescue ArgumentError, Package::UnknownObjectError, Project::UnknownObjectError, APIError, ActiveRecord::RecordInvalid => e
        @errors << "Failed to branch: #{e.message}"
      end
    end
  end
end
