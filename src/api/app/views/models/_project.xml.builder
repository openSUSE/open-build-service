project_attributes = { name: my_model.name }
# Check if the project has a special type defined (like maintenance)
project_attributes[:kind] = my_model.project_type if my_model.project_type and my_model.project_type != "standard"

xml.project(project_attributes) do
  xml.title(my_model.title)
  xml.description(my_model.description)

  my_model.linkedprojects.each do |l|
    if l.linked_db_project
      xml.link(project: l.linked_db_project.name)
    else
      xml.link(project: l.linked_remote_project_name)
    end
  end

  xml.remoteurl(my_model.remoteurl) unless my_model.remoteurl.blank?
  xml.remoteproject(my_model.remoteproject) unless my_model.remoteproject.blank?
  xml.devel(project: my_model.develproject.name) unless my_model.develproject.nil?

  my_model.render_relationships(xml)

  my_model.downloads.each do |dl|
    xml.download(baseurl: dl.baseurl, metafile: dl.metafile,
                 mtype: dl.mtype, arch: dl.architecture.name)
  end

  repos = my_model.repositories.not_remote.sort { |a, b| b.name <=> a.name }
  if view == 'flagdetails'
    my_model.flags_to_xml(xml, my_model.expand_flags)
  else
    FlagHelper.flag_types.each do |flag_name|
      flaglist = my_model.type_flags(flag_name)
      xml.send(flag_name) do
        flaglist.each do |flag|
          flag.to_xml(xml)
        end
      end unless flaglist.empty?
    end
  end

  repos.each do |repo|
    params = {}
    params[:name] = repo.name
    params[:rebuild] = repo.rebuild if repo.rebuild
    params[:block] = repo.block if repo.block
    params[:linkedbuild] = repo.linkedbuild if repo.linkedbuild
    xml.repository(params) do |r|
      repo.release_targets.each do |rt|
        params = {}
        params[:project] = rt.target_repository.project.name
        params[:repository] = rt.target_repository.name
        params[:trigger] = rt.trigger unless rt.trigger.blank?
        r.releasetarget(params)
      end
      if repo.hostsystem
        r.hostsystem(:project => repo.hostsystem.project.name, :repository => repo.hostsystem.name)
      end
      repo.path_elements.includes(:link).each do |pe|
        if pe.link.remote_project_name
          project_name = pe.link.project.name+":"+pe.link.remote_project_name
        else
          project_name = pe.link.project.name
        end
        r.path(:project => project_name, :repository => pe.link.name)
      end
      repo.repository_architectures.joins(:architecture).pluck("architectures.name").each do |arch|
        r.arch arch
      end
    end
  end

  if my_model.maintained_projects.length > 0
    xml.maintenance do |maintenance|
      my_model.maintained_projects.each do |mp|
        maintenance.maintains(:project => mp.name)
      end
    end
  end

end
