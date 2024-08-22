class ConsistencyCheckJob < ApplicationJob
  queue_as :consistency_check

  def perform
    User.default_admin.run_as { _perform(fix: false) }
  end

  def check_one_project(project, fix: false)
    package_existence_consistency_check(project, fix: fix)
    @errors << project_meta_check(project, fix: fix)
    @errors.flatten.compact_blank.join("\n")
  end

  # method called by the rake task `fix_project`
  def fix_project(project)
    User.default_admin.run_as { check_project(project, fix: true) }
  end

  # method called by the rake task `check_project`
  def check_project(project_name, fix: false)
    # check frontend
    begin
      project = Project.get_by_name(project_name)
      @errors << project_meta_check(project, fix: fix)
    rescue Project::UnknownObjectError
      #
      # specified but does not exist in api. does it also not exist in backend?
      answer = import_project_from_backend(project_name)
      if answer.present?
        @errors << answer
        return @errors.flatten.compact_blank.join("\n")
      end
    ensure
      project = Project.get_by_name(project_name)
    end
    # check backend side
    begin
      Backend::Api::Sources::Project.packages(project.name)
    rescue Backend::NotFoundError, Backend::Error
      @errors << "Project #{project.name} lost on backend"
      project.commit_opts = { no_backend_write: 1 }
      project.destroy if fix
    end
    package_existence_consistency_check(project, fix: fix)
    errors
  end

  private

  def errors
    @errors.flatten.compact_blank
  end

  def initialize
    super
    @errors = []
  end

  def _perform(fix: false)
    project_existence_consistency_check(fix: fix)
    Project.local.find_each(batch_size: 100) { |project| check_one_project(project, fix: fix) }
    send_error_email unless errors.empty?
  end

  def send_error_email
    ConsistencyMailer.errors(errors).deliver_now
  end

  def project_meta_check(project, fix: false)
    project_meta_checker = ConsistencyCheckJobService::ProjectMetaChecker.new(project)
    project_meta_checker.call

    project.store(login: User.default_admin.login, comment: 'out-of-sync fix') if !project_meta_checker.errors.empty? && fix

    project_meta_checker.errors
  end

  def project_existence_consistency_check(fix: false)
    project_consistency_checker = ConsistencyCheckJobService::ProjectConsistencyChecker.new.call

    diff = project_consistency_checker.diff_frontend_backend

    #
    # delete projects which exist in the frontend but not in the backend
    #
    unless diff.empty?
      @errors << "Additional projects in frontend:\n #{diff}"
      diff.each { |project_name| Project.find_by_name(name: project_name).destroy } if fix
    end

    diff = project_consistency_checker.diff_backend_frontend

    return if diff.empty?

    @errors << "Additional projects in backend:\n #{diff}"
    diff.each { |project| import_project_from_backend(project) } if fix
  end

  # if there is a package in the backend, but not in frontend
  # we recreate it on frontend using the project meta from backend
  def import_project_from_backend(project)
    backend_project_importer = ConsistencyCheckJobService::BackendProjectImporter.new(project)
    backend_project_importer.call
    @errors << backend_project_importer.errors if backend_project_importer.errors.present?
  end

  def package_existence_consistency_check(project, fix: false)
    begin
      project.reload
    rescue ActiveRecord::RecordNotFound
      # project disappeared ... may happen in running system
      return []
    end

    consistency_checker = ConsistencyCheckJobService::PackageConsistencyChecker.new(project).call

    diff = consistency_checker.diff_frontend_backend

    unless diff.empty?
      @errors << "Additional package in frontend #{project.name}:\n #{diff}"
      # delete package in frontend, can be undeleted
      diff.each { |package_name| project.packages.find_by(name: package_name).destroy } if fix
    end

    diff = consistency_checker.diff_backend_frontend

    return if diff.empty?

    @errors << "Additional package in backend #{project.name}:\n #{diff}"

    return unless fix

    # restore from backend
    diff.each do |package_name|
      backend_package_importer = ConsistencyCheckJobService::BackendPackageImporter.new(project, package_name)
      backend_package_importer.call
      @errors << backend_package_importer.errors unless backend_package_importer.errors.empty?
    end
  end
end
