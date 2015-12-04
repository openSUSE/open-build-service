require 'api_exception'
require 'xmlhash'

class InconsistentData < APIException; end

class ConsistencyCheckJob < ActiveJob::Base
  def fix
    perform(true)
  end

  def perform(fix = nil)
    User.current ||= User.get_default_admin
    errors = ""
    errors = project_existens_consistency_check(fix)
    Project.all.each do |prj|
      errors << package_existens_consistency_check(prj, fix)
      errors << project_meta_check(prj, fix)
    end
    unless errors.blank?
      Rails.logger.error("Detected problems during consistency check")
      Rails.logger.error(errors)
      raise InconsistentData.new(errors)
    end
    nil
  end

  def project_meta_check(prj, fix = nil)
    errors=""
    # WARNING: this is using the memcache content. should maybe dropped before
    api_meta = prj.to_axml
    begin
      backend_meta = Suse::Backend.get("/source/#{prj.name}/_meta").body
    rescue ActiveXML::Transport::NotFoundError
      # project disappeared ... may happen in running system
      return ""
    end

    backend_hash = Xmlhash.parse(backend_meta)
    api_hash = Xmlhash.parse(api_meta)
    # ignore description and title
    backend_hash['title'] = api_hash['title'] = nil
    backend_hash['description'] = api_hash['description'] = nil

    diff = hash_diff(api_hash, backend_hash)
    if diff.size > 0
      errors << "Project meta is different in backend for #{prj.name}\n#{diff}\n"
      if fix
        # Assume that api is right
        prj.store({login: "Admin", comment: "out-of-sync fix"})
      end
    end

    errors
  end

  def project_existens_consistency_check(fix = nil)
    errors=""
    # compare projects
    project_list_api = Project.all.pluck(:name).sort
    begin
      project_list_backend = dir_to_array(Xmlhash.parse(Suse::Backend.get("/source").body))
    rescue ActiveXML::Transport::NotFoundError
      # project disappeared ... may happen in running system
      return ""
    end

    diff = project_list_api - project_list_backend
    unless diff.empty?
      errors << "Additional projects in api:\n #{diff}\n"
      if fix
        # just delete ... if it exists in backend it can be undeleted
        diff.each do |project|
          prj = Project.find_by_name project
          prj.destroy if prj
        end
      end
    end

    diff = project_list_backend - project_list_api
    unless diff.empty?
      errors << "Additional projects in backend:\n #{diff}\n"

      if fix
        # restore from backend
        diff.each do |project|
          begin
            meta = Suse::Backend.get("/source/#{project}/_meta").body
            prj = Project.new(name: project)
            prj.update_from_xml(Xmlhash.parse(meta))
            prj.save!
          rescue ActiveRecord::RecordInvalid,
                 ActiveXML::Transport::NotFoundError
            Suse::Backend.delete("/source/#{project}")
            errors << "DELETED in backend due to invalid data #{project}\n"
          end
        end
      end
    end

    errors
  end

  def package_existens_consistency_check(prj, fix = nil)
    errors=""
    # compare all packages
    package_list_api = prj.packages.pluck(:name)

    package_list_backend = dir_to_array(Xmlhash.parse(Suse::Backend.get("/source/#{prj.name}").body))

    diff = package_list_api - package_list_backend
    unless diff.empty?
      errors << "Additional in api of project #{prj.name}:\n #{diff}\n"
      if fix
        # delete database object, can be undeleted
        diff.each do |package|
          pkg = prj.packages.where(name: package).first
          pkg.destroy if pkg
        end
      end
    end

    diff = package_list_backend - package_list_api
    unless diff.empty?
      errors << "Additional in backend of project #{prj.name}:\n #{diff}\n"

      if fix
        # restore from backend
        diff.each do |package|
          begin
            meta = Suse::Backend.get("/source/#{prj.name}/#{package}/_meta").body
            pkg = prj.packages.new(name: package)
            pkg.update_from_xml(Xmlhash.parse(meta))
            pkg.save!
          rescue ActiveRecord::RecordInvalid,
                 ActiveXML::Transport::NotFoundError
            Suse::Backend.delete("/source/#{prj.name}/#{package}")
            errors << "DELETED in backend due to invalid data #{prj.name}/#{package}\n"
          end
        end
      end
    end
    errors
  end

  def dir_to_array(xmlhash)
    array=[]
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
      if k == "person" and a_.kind_of? Array
        a_ = a_.map{ |i| "#{i['userid']}/#{i['role']}" }.sort
        b_ = b_.map{ |i| "#{i['userid']}/#{i['role']}" }.sort
      end
      if k == "group" and a_.kind_of? Array
        a_ = a_.map{ |i| "#{i['groupid']}/#{i['role']}" }.sort
        b_ = b_.map{ |i| "#{i['groupid']}/#{i['role']}" }.sort
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
