project_attributes = { name: my_model.name }
# Check if the project has a special type defined (like maintenance)
project_attributes[:kind] = my_model.kind unless my_model.is_standard?

xml.project(project_attributes) do
  xml.title(my_model.title)
  xml.description(my_model.description)

  my_model.linking_to.each do |l|
    params = { project: l.linked_db_project ? l.linked_db_project.name : l.linked_remote_project_name }
    params[:vrevmode] = l.vrevmode unless l.vrevmode == 'standard' || l.vrevmode.blank?
    xml.link(params)
  end

  xml.url(my_model.url) if my_model.url.present?
  xml.remoteurl(my_model.remoteurl) if my_model.remoteurl.present?
  xml.remoteproject(my_model.remoteproject) if my_model.remoteproject.present?
  xml.devel(project: my_model.develproject.name) unless my_model.develproject.nil?

  my_model.render_relationships(xml)

  repos = my_model.repositories.not_remote.sort { |a, b| b.name <=> a.name }
  FlagHelper.flag_types.each do |flag_name|
    flaglist = my_model.flags.of_type(flag_name)
    next if flaglist.empty?
    xml.send(flag_name) do
      flaglist.each do |flag|
        flag.to_xml(xml)
      end
    end
  end

  repos.each do |repo|
    params = {}
    params[:name] = repo.name
    params[:rebuild] = repo.rebuild if repo.rebuild
    params[:block] = repo.block if repo.block
    params[:linkedbuild] = repo.linkedbuild if repo.linkedbuild
    xml.repository(params) do |xml_repository|
      repo.download_repositories.each do |download_repository|
        params = { arch: download_repository.arch, url: download_repository.url, repotype: download_repository.repotype }
        xml_repository.download(params) do |xml_download|
          xml_download.archfilter download_repository.archfilter if download_repository.archfilter.present?
          if download_repository.masterurl.present?
            params = { url: download_repository.masterurl }
            params[:sslfingerprint] = download_repository.mastersslfingerprint
            xml_download.master(params)
          end
          xml_download.pubkey download_repository.pubkey if download_repository.pubkey.present?
        end
      end
      repo.release_targets.each do |rt|
        params = {}
        params[:project] = rt.target_repository.project.name
        params[:repository] = rt.target_repository.name
        params[:trigger] = rt.trigger if rt.trigger.present?
        xml_repository.releasetarget(params)
      end
      if repo.hostsystem
        xml_repository.hostsystem(project: repo.hostsystem.project.name, repository: repo.hostsystem.name)
      end
      repo.path_elements.includes(:link).each do |pe|
        if pe.link.remote_project_name.present?
          project_name = pe.link.project.name + ':' + pe.link.remote_project_name
        else
          project_name = pe.link.project.name
        end
        xml_repository.path(project: project_name, repository: pe.link.name)
      end
      repo.repository_architectures.joins(:architecture).pluck('architectures.name').each do |arch|
        xml_repository.arch arch
      end
    end
  end

  unless MaintainedProject.where(maintenance_project_id: my_model.id).empty?
    xml.maintenance do |maintenance|
      MaintainedProject.where(maintenance_project_id: my_model.id).each do |mp|
        maintenance.maintains(project: mp.project.name)
      end
    end
  end
end
