module PackageMediumContainer
  extend ActiveSupport::Concern

  # local mode (default): last package in link chain in my project
  # no local mode:        first package in link chain outside of my project
  def origin_container(options = { local: true })
    # link target package name is more important, since local name could be
    # extended. For example in maintenance incident projects.
    linkinfo = dir_hash['linkinfo']
    # no link, so I am origin
    return self if linkinfo.nil?

    if options[:local] && linkinfo['project'] != project.name
      # links to external project, so I am origin
      return self
    end

    # local link, go one step deeper
    prj = Project.get_by_name(linkinfo['project'])
    pkg = prj.find_package(linkinfo['package'])
    return pkg if !options[:local] && project != prj && !prj.maintenance_incident?

    # If package is nil it's either broken or a remote one.
    # Otherwise we continue
    pkg.try(:origin_container, options)
  end

  def add_containers(opts = {})
    container_list = {}

    # ensure to start with update project
    update_pkg = origin_container(local: false).update_instance
    # we need to take update project and all projects linking to into account
    update_pkg.project.expand_all_projects.each do |prj|
      origin_package = prj.packages.find_by_name(update_pkg.name)
      next unless origin_package

      origin_package.binary_releases.where(obsolete_time: nil).find_each do |binary_release|
        mc = binary_release.medium_container
        if mc
          mc_update_project = mc.project.update_instance_or_self
          # pick only one and the highest container.
          identifier = "#{mc_update_project.name}/#{mc.name}"
          # esp. in maintenance update projects where the name suffix is the counter
          identifier.gsub!(/\.[^.]*$/, '') if mc_update_project.maintenance_release?
          next if container_list[identifier] && container_list[identifier].name > mc.name

          container_list[identifier] = mc
        end
      end
    end

    comment = "add container for #{name}"
    opts[:extend_package_names] = true if project.maintenance_incident?

    container_list.values.each do |container|
      container_name = container.name.dup
      container_update_project = container.project.update_instance_or_self
      container_name.gsub!(/\.[^.]*$/, '') if container_update_project.maintenance_release? && !container.link?
      container_name << '.' << container_update_project.name.tr(':', '_') if opts[:extend_package_names]
      next if project.packages.exists?(name: container_name)

      target_package = Package.new(name: container_name, title: container.title, description: container.description)
      project.packages << target_package
      target_package.store(comment: comment)

      # branch sources
      target_package.branch_from(container.project.update_instance_or_self.name, container.name, comment: comment)
    end
  end
end
