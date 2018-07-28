class OwnerAssigneeSearch < OwnerSearch
  def for(search_string)
    # search in each marked project
    object_projects(search_string).map do |project|
      find_assignees project, search_string, limit.to_i, !devel_disabled?(project)
    end.flatten
  end

  protected

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

  def find_assignees(rootproject, binary_name, limit = 1, devel = true)
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

    webui_mode = params[:webui_mode].present?
    return instances_without_definition if webui_mode && maintainers.empty?

    maintainers << deepest_match if deepest_match

    maintainers
  end
end
