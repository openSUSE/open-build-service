class Project
  class BranchRemoteRepositoriesCommand
    attr_reader :project, :remote_project_name

    def initialize(project, remote_project_name)
      @project = project
      @remote_project_name = remote_project_name
    end

    def run
      remote_project = Project.new(name: remote_project_name)
      remote_project_meta = Nokogiri::XML(remote_project.meta.to_s)
      local_project_meta = Nokogiri::XML(project.to_axml)

      remote_repositories = remote_project.repositories_from_meta
      remote_repositories -= project.repositories.where(name: remote_repositories).pluck(:name)

      remote_repositories.each do |repository|
        repository_node = local_project_meta.create_element("repository")
        repository_node["name"] = repository

        # if it is kiwi type
        if repository == "images"
          path_elements = remote_project_meta.xpath("//repository[@name='images']/path")

          prjconf = project.source_file('_config')
          unless prjconf =~ /^Type:/
            prjconf = "%if \"%_repository\" == \"images\"\nType: kiwi\nRepotype: none\nPatterntype: none\n%endif\n" << prjconf
            Backend::Connection.put_source(project.source_path('_config'), prjconf)
          end
        else
          path_elements = local_project_meta.create_element("path")
          path_elements["project"] = remote_project_name
          path_elements["repository"] = repository
        end
        repository_node.add_child(path_elements)

        architectures = remote_project_meta.xpath("//repository[@name='#{repository}']/arch")
        repository_node.add_child(architectures)

        local_project_meta.at('project').add_child(repository_node)
      end

      # update branched project _meta file
      project.update_from_xml!(Xmlhash.parse(local_project_meta.to_xml))
    end
  end
end
