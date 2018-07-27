class OwnerOfContainerSearch < OwnerSearch
  def for(obj)
    if obj.is_a? Project
      project = obj
    else
      project = obj.project
    end
    find_maintainers(obj, filter(project))
  end

  protected

  def find_maintainers(container, filter)
    maintainers = []
    sql = build_rolefilter_sql(filter)
    add_owners = proc do |cont|
      m = Owner.new
      m.rootproject = ''
      if cont.is_a? Package
        m.project = cont.project.name
        m.package = cont.name
      else
        m.project = cont.name
      end
      m.filter = filter
      extract_from_container(m, cont.relationships, sql, nil)
      maintainers << m unless m.users.nil? && m.groups.nil?
    end
    project = container
    if container.is_a? Package
      add_owners.call container
      project = container.project
    end
    # add maintainers from parent projects
    until project.nil?
      add_owners.call(project)
      project = project.parent
    end
    maintainers
  end
end
