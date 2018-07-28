require 'api_exception'

class OwnerSearch
  class AttributeNotSetError < APIException
    setup 'attribute_not_set', 400
  end

  def initialize(params = {})
    self.params = params
    self.attribute = AttribType.find_by_name!(params[:attribute] || 'OBS:OwnerRootProject')

    self.limit = params[:limit] || 1
  end

  def for(obj)
    # search in each marked project
    owners = []
    object_projects(obj).each do |project|
      if obj.is_a? String
        owners += find_assignees(project, obj, limit.to_i, !devel_disabled?(project),
                                 (true if params[:webui_mode].present?))
      else
        owners += find_containers(project, obj, !devel_disabled?(project))
      end
    end

    owners
  end

  protected

  attr_accessor :params, :attribute, :limit

  def object_projects(_obj)
    # default project specified
    return [Project.get_by_name(params[:project])] if params[:project]

    # Find all marked projects
    projects = Project.find_by_attribute_type(attribute)
    return projects unless projects.empty?
    raise AttributeNotSetError, "The attribute #{attribute.fullname} is not set to define default projects."
  end

  def project_attrib(project)
    return unless project
    project.attribs.find_by(attrib_type: attribute)
  end

  def filter(project)
    return params[:filter].split(',') if params[:filter]

    attrib = project_attrib(project)
    if attrib && attrib.values.where(value: 'BugownerOnly').exists?
      ['bugowner']
    else
      ['maintainer', 'bugowner']
    end
  end

  def devel_disabled?(project = nil)
    return ['0', 'false'].include?(params[:devel]) if params[:devel]

    attrib = project_attrib(project)
    attrib && attrib.values.where(value: 'DisableDevel').exists?
  end

  def find_assignees(rootproject, binary_name, limit = 1, devel = true, webui_mode = false)
    projects = rootproject.expand_all_projects(allow_remote_projects: false)
    instances_without_definition = []
    maintainers = []
    pkg = nil

    match_all = limit.zero?
    deepest = (limit < 0)

    # binary search via all projects
    data = Xmlhash.parse(Backend::Api::Search.binary(projects.map(&:name), binary_name))
    # found binary package?
    return [] if data['matches'].to_i.zero?

    filter = self.filter(rootproject)
    already_checked = {}
    deepest_match = nil
    projects.each do |prj| # project link order
      data.elements('binary').each do |b| # no order
        next unless b['project'] == prj.name

        package_name = b['package']
        package_name.gsub!(/\.[^\.]*$/, '') if prj.is_maintenance_release?
        pkg = prj.packages.find_by_name(package_name)
        next if pkg.nil? || pkg.is_patchinfo?

        # the "" means any matching relationships will get taken
        m, limit, already_checked = lookup_package_owner(rootproject, pkg, '', limit, devel, deepest, already_checked)
        unless m
          # collect all no matched entries
          m = Owner.new(rootproject: rootproject.name, project: pkg.project.name, package: pkg.name, filter: filter)
          instances_without_definition << m
          next
        end

        # remember as deepest candidate
        if deepest == true
          deepest_match = m
          next
        end

        # add matching entry
        maintainers << m
        limit -= 1
        return maintainers if limit < 1 && !match_all
      end
    end

    return instances_without_definition if webui_mode && maintainers.empty?

    maintainers << deepest_match if deepest_match

    maintainers
  end

  def find_containers(rootproject, owner, devel = true)
    projects = rootproject.expand_all_projects(allow_remote_projects: false)

    roles = []
    filter(rootproject).each do |f|
      roles << Role.find_by_title!(f)
    end

    found_packages = Relationship.where(role_id: roles, package_id: Package.where(project_id: projects).pluck(:id))
    found_projects = Relationship.where(role_id: roles, project_id: projects)
    # fast find packages with defintions
    if owner.class == User
      # user in package object
      found_packages = found_packages.where(user_id: owner)
      # user in project object
      found_projects = found_projects.where(user_id: owner)
    elsif owner.class == Group
      # group in package object
      found_packages = found_packages.where(group_id: owner)
      # group in project object
      found_projects = found_projects.where(group_id: owner)
    else
      raise 'illegal object handed to find_containers'
    end
    if devel == true
      # FIXME: add devel packages, but how do recursive lookup fast in SQL?
    end
    found_packages = found_packages.pluck(:package_id).uniq
    found_projects = found_projects.pluck(:project_id).uniq

    maintainers = []

    Project.where(id: found_projects).pluck(:name).each do |prj|
      maintainers << Owner.new(rootproject: rootproject.name, project: prj)
    end
    Package.where(id: found_packages).find_each do |pkg|
      maintainers << Owner.new(rootproject: rootproject.name, project: pkg.project.name, package: pkg.name)
    end

    maintainers
  end

  def lookup_package_owner(rootproject, pkg, owner, limit, devel, deepest, already_checked = {})
    return nil, limit, already_checked if already_checked[pkg.id]

    # optional check for devel package instance first
    m = nil
    m = extract_maintainer(rootproject, pkg.resolve_devel_package, owner) if devel == true
    m ||= extract_maintainer(rootproject, pkg, owner)

    already_checked[pkg.id] = 1

    # found entry
    return m, (limit - 1), already_checked if m

    # no match, loop about projects below with this package container name
    pkg.project.expand_all_projects(allow_remote_projects: false).each do |prj|
      p = prj.packages.find_by_name(pkg.name)
      next if p.nil? || already_checked[p.id]

      already_checked[p.id] = 1

      m = extract_maintainer(rootproject, p.resolve_devel_package, owner) if devel == true
      m ||= extract_maintainer(rootproject, p, owner)

      break if m && !deepest
    end

    # found entry
    [m, (limit - 1), already_checked]
  end

  def extract_maintainer(rootproject, pkg, objfilter = nil)
    return unless pkg
    return unless Package.check_access?(pkg)
    m = Owner.new

    rolefilter = filter(rootproject)
    m.rootproject = rootproject.name
    m.project = pkg.project.name
    m.package = pkg.name
    m.filter = rolefilter

    # no filter defined, so do not check for roles and just return container
    return m if rolefilter.empty?
    # lookup in package container
    extract_from_container(m, pkg, rolefilter, objfilter)

    # did it it match? if not fallback to project level
    unless m.users || m.groups
      m.package = nil
      extract_from_container(m, pkg.project, rolefilter, objfilter)
    end
    # still not matched? Ignore it
    return unless m.users || m.groups

    m
  end

  def filter_roles(relation, rolefilter)
    return relation if rolefilter.empty?
    role_ids = rolefilter.map { |r| Role.find_by_title!(r).id }
    relation.where(role_id: role_ids)
  end

  def filter_users(owner, container, rolefilter, objfilter)
    rel = filter_roles(container.relationships.users, rolefilter)
    if objfilter.class == User
      rel = rel.where(user: objfilter)
    end
    rel.find_each do |p|
      next unless p.user.state == 'confirmed'
      owner.users ||= {}
      owner.users[p.role.title] ||= []
      owner.users[p.role.title] << p.user.login
    end
  end

  def filter_groups(owner, container, rolefilter, objfilter)
    rel = filter_roles(container.relationships.groups, rolefilter)
    if objfilter.class == Group
      rel = rel.where(group: objfilter)
    end
    rel.find_each do |p|
      next if p.group.users.where(state: 'confirmed').empty?
      owner.groups ||= {}
      owner.groups[p.role.title] ||= []
      owner.groups[p.role.title] << p.group.title
    end
  end

  def extract_from_container(owner, container, rolefilter, objfilter)
    filter_users(owner, container, rolefilter, objfilter) unless objfilter.class == Group
    filter_groups(owner, container, rolefilter, objfilter) unless objfilter.class == User
    owner
  end
end
