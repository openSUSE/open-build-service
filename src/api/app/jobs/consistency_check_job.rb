# frozen_string_literal: true

require 'api_exception'
require 'xmlhash'

class ConsistencyCheckJob < ApplicationJob
  queue_as :consistency_check

  def perform(fix = nil)
    init
    @errors = project_existence_consistency_check(fix)
    Project.find_each(batch_size: 100) do |project|
      unless Project.valid_name? project.name
        @errors << "Invalid project name #{project.name}\n"
        if fix
          # just remove it, the backend won't accept it anyway
          project.commit_opts = { no_backend_write: 1 }
          project.destroy
        end
        next
      end
      @errors << package_existence_consistency_check(project, fix)
      @errors << project_meta_check(project, fix)
    end
    if @errors.present?
      @errors = "FIXING the following errors:\n" << @errors if fix
      Rails.logger.error('Detected problems during consistency check')
      Rails.logger.error(@errors)

      AdminMailer.error(@errors).deliver_now
    end
    nil
  end

  # for manual fixing by admin via rails command
  def fix_project
    init
    check_project(true)
  end

  def check_project(fix = nil)
    init
    if ENV['project'].blank?
      puts "Please specify the project with 'project=MyProject' on CLI"
      return
    end
    # check api side
    begin
      project = Project.get_by_name(ENV['project'])
      @errors << project_meta_check(project, fix)
    rescue Project::UnknownObjectError
      # specified but does not exist in api. does it also not exist in backend?
      answer = import_project_from_backend(ENV['project'])
      if answer.present?
        @errors << answer
        return
      end
      project = Project.get_by_name(ENV['project'])
    end
    # check backend side
    begin
      Backend::Api::Sources::Project.packages(project.name)
    rescue ActiveXML::Transport::NotFoundError
      @errors << "Project #{project.name} lost on backend"
      project.commit_opts = { no_backend_write: 1 }
      project.destroy if fix
    end
    @errors << package_existence_consistency_check(project, fix)
    puts @errors if @errors.present?
  end

  private

  def fix
    perform(true)
  end

  def init
    User.current ||= User.get_default_admin
    @errors = ''
  end

  def project_meta_check(project, fix = nil)
    errors = ''
    # WARNING: this is using the memcache content. should maybe dropped before
    api_meta = project.to_axml
    begin
      backend_meta = Backend::Api::Sources::Project.meta(project.name)
    rescue ActiveXML::Transport::NotFoundError
      # project disappeared ... may happen in running system
      return ''
    end

    backend_hash = Xmlhash.parse(backend_meta)
    api_hash = Xmlhash.parse(api_meta)
    # ignore description and title
    backend_hash['title'] = api_hash['title'] = nil
    backend_hash['description'] = api_hash['description'] = nil

    diff = hash_diff(api_hash, backend_hash)
    unless diff.empty?
      errors << "Project meta is different in backend for #{project.name}\n#{diff}\n"
      if fix
        # Assume that api is right
        project.store(login: 'Admin', comment: 'out-of-sync fix')
      end
    end

    errors
  end

  def project_existence_consistency_check(fix = nil)
    errors = ''
    # compare projects
    project_list_api = Project.all.pluck(:name).sort
    begin
      project_list_backend = dir_to_array(Xmlhash.parse(Backend::Api::Sources::Project.list))
    rescue ActiveXML::Transport::NotFoundError
      # project disappeared ... may happen in running system
      return ''
    end

    diff = project_list_api - project_list_backend
    unless diff.empty?
      errors << "Additional projects in api:\n #{diff}\n"
      if fix
        # just delete ... if it exists in backend it can be undeleted
        diff.each do |project|
          project = Project.find_by_name project
          project.destroy if project
        end
      end
    end

    diff = project_list_backend - project_list_api
    unless diff.empty?
      errors << "Additional projects in backend:\n #{diff}\n"

      if fix
        diff.each do |project|
          errors << import_project_from_backend(project)
        end
      end
    end

    errors
  end

  def import_project_from_backend(project)
    meta = Backend::Api::Sources::Project.meta(project)
    project = Project.new(name: project)
    project.commit_opts = { no_backend_write: 1 }
    project.update_from_xml!(Xmlhash.parse(meta))
    project.save!
    return ''
  rescue APIException => e
    return "Invalid project meta data hosted in src server for project #{project}: #{e}"
  rescue ActiveRecord::RecordInvalid
    Backend::Api::Sources::Project.delete(project)
    return "DELETED #{project} on backend due to invalid data\n"
  rescue ActiveXML::Transport::NotFoundError
    return "specified #{project} does not exist on backend\n"
  end

  def package_existence_consistency_check(project, fix = nil)
    errors = ''
    begin
      project.reload
    rescue ActiveRecord::RecordNotFound
      # project disappeared ... may happen in running system
      return ''
    end

    # valid package names?
    package_list_api = project.packages.pluck(:name)
    package_list_api.each do |name|
      next if Package.valid_name? name
      errors << "Invalid package name #{name} in project #{project.name}\n"
      next unless fix
      # just remove it, the backend won't accept it anyway
      pkg = project.packages.find_by(name: name)
      pkg.commit_opts = { no_backend_write: 1 }
      pkg.destroy
      next
    end

    # compare all packages
    package_list_api = project.packages.pluck(:name)
    begin
      plb = dir_to_array(Xmlhash.parse(Backend::Api::Sources::Project.packages(project.name)))
    rescue ActiveXML::Transport::NotFoundError
      # project disappeared ... may happen in running system
      return ''
    end
    # filter multibuild source container
    package_list_backend = plb.map { |e| e.start_with?('_patchinfo:', '_product:') ? e : e.gsub(/:.*$/, '') }

    diff = package_list_api - package_list_backend
    unless diff.empty?
      errors << "Additional package in api project #{project.name}:\n #{diff}\n"
      if fix
        # delete database object, can be undeleted
        diff.each do |package|
          pkg = project.packages.where(name: package).first
          pkg.destroy if pkg
        end
      end
    end

    diff = package_list_backend - package_list_api
    unless diff.empty?
      errors << "Additional package in backend project #{project.name}:\n #{diff}\n"

      if fix
        # restore from backend
        diff.each do |package|
          begin
            meta = Backend::Api::Sources::Project.meta(project.name)
            pkg = project.packages.new(name: package)
            pkg.commit_opts = { no_backend_write: 1 }
            pkg.update_from_xml(Xmlhash.parse(meta), true) # ignore locked project
            pkg.save!
          rescue ActiveRecord::RecordInvalid,
                 ActiveXML::Transport::NotFoundError
            Backend::Api::Sources::Package.delete(project.name, package)
            errors << "DELETED in backend due to invalid data #{project.name}/#{package}\n"
          end
        end
      end
    end
    errors
  end

  def dir_to_array(xmlhash)
    array = []
    xmlhash.elements('entry') do |e|
      array << e['name']
    end
    array.sort
  end

  def hash_diff(a, b)
    # ignore the order inside of the hash
    (a.keys.sort | b.keys.sort).each_with_object({}) do |diff, k|
      a_ = a[k]
      b_ = b[k]
      # we need to ignore the ordering in some cases
      # old xml generator wrote them in a different order
      # but in other cases the order of elements matters
      if k == 'person' && a_.is_a?(Array)
        a_ = a_.map { |i| "#{i['userid']}/#{i['role']}" }.sort
        b_ = b_.map { |i| "#{i['userid']}/#{i['role']}" }.sort
      end
      if k == 'group' && a_.is_a?(Array)
        a_ = a_.map { |i| "#{i['groupid']}/#{i['role']}" }.sort
        b_ = b_.map { |i| "#{i['groupid']}/#{i['role']}" }.sort
      end
      if a_ != b_
        if a[k].class == Hash && b[k].class == Hash
          diff[k] = hash_diff(a[k], b[k])
        else
          diff[k] = [a[k], b[k]]
        end
      end
      diff
    end
  end
end
