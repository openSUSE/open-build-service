require 'api_error'

module OwnerSearch
  class Base
    class AttributeNotSetError < APIError
      setup 'attribute_not_set', 400
    end

    def devel_disabled?(project = nil)
      return %w[0 false].include?(params[:devel]) if params[:devel]

      attrib = project_attrib(project)
      attrib && attrib.values.exists?(value: 'DisableDevel')
    end

    protected

    def initialize(params = {})
      self.params = params
      self.attribute = AttribType.find_by_name!(params[:attribute] || 'OBS:OwnerRootProject')

      self.limit = (params[:limit] || 1).to_i

      raise InvalidLimitError, "The limit (#{limit}) must be either a positive number, 0 or -1." unless limit >= -1
    end

    attr_accessor :params, :attribute, :limit

    def projects_to_look_at
      # default project specified
      return [Project.get_by_name(params[:project])] if params[:project]

      # Find all marked projects
      projects = Project.joins(:attribs).where(attribs: { attrib_type_id: attribute.id })
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
      if attrib && attrib.values.exists?(value: 'BugownerOnly')
        ['bugowner']
      else
        %w[maintainer bugowner]
      end
    end

    def filter_roles(relation, rolefilter)
      return relation if rolefilter.empty?

      role_ids = rolefilter.map { |r| Role.find_by_title!(r).id }
      relation.where(role_id: role_ids)
    end

    def filter_users(owner, container, rolefilter, user)
      rel = filter_roles(container.relationships.users, rolefilter)
      rel = rel.where(user: user) if user
      rel = rel.joins(:user).where(relationships: { user_id: User.active })
      rel.each do |p|
        owner.users ||= {}
        entries = owner.users.fetch(p.role.title, []) << p.user
        owner.users[p.role.title] = entries
      end
    end

    def filter_groups(owner, container, rolefilter, group)
      rel = filter_roles(container.relationships.groups, rolefilter)
      rel = rel.where(group: group) if group
      rel.each do |p|
        next unless p.group.any_confirmed_users?

        owner.groups ||= {}
        entries = owner.groups.fetch(p.role.title, []) << p.group
        owner.groups[p.role.title] = entries
      end
    end

    def extract_from_container(owner, container, rolefilter, user_or_group = nil)
      filter_users(owner, container, rolefilter, user_or_group) unless user_or_group.instance_of?(Group)
      filter_groups(owner, container, rolefilter, user_or_group) unless user_or_group.instance_of?(User)
    end
  end
end
