module Event
  class Relationship < Base
    self.abstract_class = true
    payload_keys :description, :who, :user, :group, :project, :package, :role, :notifiable_id
    shortenable_key :description

    def subject
      raise AbstractMethodCalled
    end

    def parameters_for_notification
      super.merge({ notifiable_type: notifiable_type, notifiable_id: notifiable_id, type: "Notification#{notifiable_type}" })
    end

    def any_roles
      [User.find_by(login: payload['user']) || ::Group.find_by(title: payload['group'])]
    end

    def notifiable_type
      return 'Package' if payload['package']

      'Project'
    end

    def notifiable_id
      # FIXME: Inherited package coming from a project link via attribute link resolves to the upstream package. This is confusing at least. We need to think about this behaviour later.
      return Package.get_by_project_and_name(payload['project'], payload['package']).id if payload['package']
      return Project.get_by_name(payload['project']).id if Project.exists_by_name(payload['project'])

      nil
    rescue Project::Errors::UnknownObjectError # This happens for access-protected projects
      nil
    end

    def originator
      payload_address('who')
    end

    # FIXME: Use this to get rid of notifiable_type / notifiable_id
    def event_object
      return Package.unscoped.includes(:project).where(name: Package.striping_multibuild_suffix(payload['package']), projects: { name: payload['project'] }) if payload['package']

      Project.unscoped.find_by(name: payload['project'])
    end
  end
end
