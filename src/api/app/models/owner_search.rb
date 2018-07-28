require 'api_exception'

class OwnerSearch
  class AttributeNotSetError < APIException
    setup 'attribute_not_set', 400
  end

  def initialize(params = {})
    self.params = params
    self.attribute = AttribType.find_by_name!(params[:attribute] || 'OBS:OwnerRootProject')

    self.limit = (params[:limit] || 1).to_i
  end

  def for(owner)
    # search in each marked project
    object_projects(owner).map do |project|
      find_containers(project, owner, !devel_disabled?(project))
    end.flatten
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

  def find_containers(rootproject, owner, devel)
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
