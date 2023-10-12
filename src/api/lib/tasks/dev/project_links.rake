namespace :dev do
  namespace :project_links do
    # https://github.com/openSUSE/open-build-service/wiki/Links
    desc 'Create a couple of project link setups'
    task data: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods
      # Make sure the interconnect to api.opensuse.org is there as we are using it...
      interconnect = Project.find_by(name: 'openSUSE.org', remoteurl: 'https://api.opensuse.org/public')
      interconnect ||= create(:remote_project, name: 'openSUSE.org', remoteurl: 'https://api.opensuse.org/public')
      interconnect_repo = interconnect.repositories.find_by(name: 'snapshot', remote_project_name: 'openSUSE:Factory')
      interconnect_repo ||= create(:repository, name: 'snapshot', remote_project_name: 'openSUSE:Factory', project: interconnect)
      interconnect.store

      # An empty Project that links to another Project and rebuilds its packages
      local_linked_to_project = create(:project, name: 'Hans')
      create(:package_with_files, name: 'ctris', project: local_linked_to_project)
      local_linked_to_project.store
      project = create(:project, name: 'ProjectLinks:LocalLinkedBuild',
                                 title: 'Has a project link to a  local project and rebuilds its packages',
                                 description: 'Project Links to Hans')
      repository = create(:repository, name: 'openSUSE_Tumbleweed', linkedbuild: 'all', architectures: ['x86_64'], project: project)
      create(:path_element, repository: repository, link: interconnect_repo)
      create(:linked_project, project: project, linked_db_project: local_linked_to_project)
      project.store

      # An empty Project that links to a remote project and rebuilds its packages
      project = create(:project, name: 'ProjectLinks:RemoteLinkedBuild',
                                 title: 'Has a project link to a remote project and rebuilds its packages',
                                 description: 'Project Link to openSUSE.org:home:hennevogel:myfirstproject')
      repository = create(:repository, name: 'openSUSE_Tumbleweed', linkedbuild: 'all', architectures: ['x86_64'], project: project)
      create(:path_element, repository: repository, link: interconnect_repo)
      create(:linked_project, project: project, linked_remote_project_name: 'openSUSE.org:home:hennevogel:myfirstproject')
      project.store
    end
  end
end
