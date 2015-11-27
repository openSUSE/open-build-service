
require 'api_exception'
require 'xmlhash'

module AdminHelper

  def consistency_check(fix = nil)
    errors = ""
    errors = project_existens_consistency_check(fix)
    Project.all.each do |prj|
      errors << package_existens_consistency_check(prj, fix)
      errors << project_meta_check(prj, fix)
    end
    unless errors.blank?
      Rails.logger.warn("Detected problems during consistency check")
      Rails.logger.warn(errors)
      raise APIException.new(errors)
    end
    nil
  end

  def project_meta_check(prj, fix = nil)
    errors=""
    # WARNING: this is using the memcache content. should maybe dropped before
    api_meta = prj.to_axml
    backend_meta = Suse::Backend.get("/source/#{prj.name}/_meta").body
    # ignore whitespace instead of nil object due to former broken rendering
    backend_meta.gsub!("<title></title>", "<title/>")
    backend_meta.gsub!("<description></description>", "<description/>")

    diff = hash_diff(Xmlhash.parse(api_meta), Xmlhash.parse(backend_meta))
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
    project_list_backend = dir_to_array(Xmlhash.parse(Suse::Backend.get("/source").body))

    diff = project_list_api - project_list_backend
    unless diff.empty?
      errors << "Additional projects in api:\n #{diff}\n"
      if fix
        # just delete ... if it exists in backend it can be undeleted
        diff.each do |project|
          prj = Project.find_by_name project
          prj.delete if prj
        end
      end
    end

    diff = project_list_backend - project_list_api
    unless diff.empty?
      errors << "Additional projects in backend:\n #{diff}\n"

      if fix
        # restore from backend
        diff.each do |project|
        meta = Suse::Backend.get("/source/#{project}/_meta").body
        prj = Project.new(name: project)
        prj.update_from_xml(Xmlhash.parse(meta))
        prj.save!
        end
      end
    end

    errors
  end

  def package_existens_consistency_check(prj, fix = nil)
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
        pkg.delete if pkg
        end
      end
    end

    diff = package_list_backend - package_list_api
    unless diff.empty?
      errors << "Additional in backend of project #{prj.name}:\n #{diff}\n"

      if fix
        # restore from backend
        diff.each do |package|
        meta = Suse::Backend.get("/source/#{prj.name}/#{package}/_meta").body
        pkg = prj.packages.new(name: package)
        pkg.update_from_xml(Xmlhash.parse(meta))
        pkg.save!
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
      if a[k] != b[k]
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


