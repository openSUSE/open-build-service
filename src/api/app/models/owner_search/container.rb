module OwnerSearch
  class Container < Base
    def for(container)
      if container.is_a?(Project)
        project = container
      else
        project = container.project
      end
      @filter = filter(project)
      find_maintainers(container)
    end

    protected

    def add_owners(container)
      owner = Owner.new
      owner.rootproject = ''
      if container.is_a?(Package)
        owner.project = container.project.name
        owner.package = container.name
      else
        owner.project = container.name
      end
      owner.filter = @filter
      extract_from_container(owner, container, @filter, nil)
      return if owner.users.nil? && owner.groups.nil?
      @maintainers << owner
    end

    def find_maintainers(container)
      @maintainers = []
      if container.is_a?(Package)
        add_owners(container)
        project = container.project
      else
        project = container
      end
      # add maintainers from parent projects
      while project
        add_owners(project)
        project = project.parent
      end
      @maintainers
    end
  end
end
