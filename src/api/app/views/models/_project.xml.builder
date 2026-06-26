project_attributes = { name: my_model.name }
# Check if the project has a special type defined (like maintenance)
project_attributes[:kind] = my_model.kind unless my_model.standard?

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
  xml.scmsync(my_model.scmsync) if my_model.scmsync.present?
  xml.devel(project: my_model.develproject.name) unless my_model.develproject.nil?

  my_model.render_relationships(xml)

  repos = my_model.repositories.preload(:download_repositories, :release_targets, path_elements: :link).not_remote.order(name: :desc)
  FlagHelper.render(my_model, xml)

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
            params[:sslfingerprint] = download_repository.mastersslfingerprint if download_repository.mastersslfingerprint
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
      repo.path_elements.includes(:link).order(kind: :desc).each do |pe|
        project_name = if pe.link.remote_project_name.present?
                         "#{pe.link.project.name}:#{pe.link.remote_project_name}"
                       else
                         pe.link.project.name
                       end
        if pe.kind == 'hostsystem'
          xml_repository.hostsystem(project: project_name, repository: pe.link.name)
        else
          xml_repository.path(project: project_name, repository: pe.link.name)
        end
      end
      repo.repository_architectures.joins(:architecture).pluck('architectures.name').each do |arch|
        xml_repository.arch arch
      end
    end
  end

  maintained_projects = my_model.maintained_project_names
  unless maintained_projects.empty?
    xml.maintenance do |maintenance|
      maintained_projects.each do |mp|
        maintenance.maintains(project: mp)
      end
    end
  end
end
