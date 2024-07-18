module Webui
  module Packages
    class BranchesController < Webui::WebuiController
      before_action :require_login
      before_action :set_project, only: %i[new into]
      before_action :set_package, only: [:new]

      after_action :verify_authorized, except: [:create]

      def new
        authorize @package, :create_branch?

        @revision = params[:revision] || @package.rev
      end

      def into
        authorize Package.new(project: @project), :create_branch?

        @remote_projects = Project.where.not(remoteurl: nil).pluck(:id, :name, :title)
      end

      # FIXME: We should completely and solely rely on Pundit for authorization instead of some custom authorization code in the BranchPackage model
      def create
        # FIXME: We should use strong parameters instead of this custom implementation
        params.fetch(:linked_project) { raise ArgumentError, 'Linked Project parameter missing' }
        params.fetch(:linked_package) { raise ArgumentError, 'Linked Package parameter missing' }

        # Full permission check happens in BranchPackage.new(branch_params).branch command
        # Are we linking a package from a remote instance?
        # Then just try, the remote instance will handle checking for existence authorization etc.
        if Project.find_remote_project(params[:linked_project])
          source_project_name = params[:linked_project]
          source_package_name = params[:linked_package]
        else
          source_package = Package.get_by_project_and_name(params[:linked_project], params[:linked_package], use_source: false, follow_multibuild: true)
          source_project_name = source_package.project.name
          source_package_name = source_package.name
          authorize source_package, :create_branch?
        end

        branch_params = {
          project: source_project_name,
          package: source_package_name
        }

        # Set the branch to the current revision if revision is present
        if params[:current_revision].present?
          options = { project: source_project_name, package: source_package_name, expand: 1 }
          options[:rev] = params[:revision] if params[:revision].present?
          dirhash = Directory.hashed(options)
          branch_params[:rev] = dirhash['xsrcmd5'] || dirhash['rev']

          unless branch_params[:rev]
            flash[:error] = dirhash['error'] || 'Package has no source revision yet'
            redirect_back_or_to root_path
            return
          end
        end

        branch_params[:target_project] = params[:target_project] if params[:target_project].present?
        branch_params[:target_package] = params[:target_package] if params[:target_package].present?
        branch_params[:add_repositories_rebuild] = params[:add_repositories_rebuild] if params[:add_repositories_rebuild].present?
        branch_params[:autocleanup] = params[:autocleanup] if params[:autocleanup].present?

        branched_package = BranchPackage.new(branch_params).branch
        created_project_name = branched_package[:data][:targetproject]
        created_package_name = branched_package[:data][:targetpackage]

        Event::BranchCommand.create(project: source_project_name, package: source_package_name,
                                    targetproject: created_project_name, targetpackage: created_package_name,
                                    user: User.session.login)

        branched_package_object = Package.find_by_project_and_name(created_project_name, created_package_name)

        if request.env['HTTP_REFERER'] == image_templates_url && branched_package_object.kiwi_image?
          redirect_to(import_kiwi_image_path(branched_package_object.id))
        else
          flash[:success] = 'Successfully branched package'
          redirect_to(package_show_path(project: created_project_name, package: created_package_name))
        end
      rescue BranchPackage::DoubleBranchPackageError => e
        flash[:notice] = 'You have already branched this package'
        redirect_to(package_show_path(project: e.project, package: e.package))
      rescue CreateProjectNoPermission
        flash[:error] = 'Sorry, you are not authorized to create this project.'
        redirect_back_or_to root_path
      rescue ArgumentError, Package::UnknownObjectError, Project::UnknownObjectError, APIError, ActiveRecord::RecordInvalid => e
        flash[:error] = "Failed to branch: #{e.message}"
        redirect_back_or_to root_path
      end
    end
  end
end
