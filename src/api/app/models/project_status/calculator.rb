module ProjectStatus
  class Calculator
    def initialize(dbproj)
      @dbproj = dbproj
    end

    def calc_status(opts = {})
      return {} unless @dbproj

      mypackages = {}

      @dbproj.packages.select([:id, :name, :project_id, :develpackage_id]).includes(:develpackage, :backend_package).load.each do |dbpack|
        add_recursively(mypackages, dbpack)
      end

      projects = {}

      get_list_of_project_and_packages(mypackages.keys).each do |project_id, project_name, package_name|
        package_info = mypackages[package_name]
        package_info.project = project_name
        package_info.links_to = mypackages[package_info.links_to_id] if package_info.links_to_id
        projects[project_id] = project_name
      end

      selected_projects = projects.keys.select { |project_id| !opts[:pure_project] || project_id == @dbproj.id }
      selected_projects.each { |project_id| update_jobhistory(Project.find(project_id), mypackages) }

      # cleanup
      mypackages.each_key do |key|
        mypackages.delete(key) if mypackages[key].project != @dbproj.name
      end

      mypackages
    end

    private

    # parse the jobhistory and put the result in a format we can cache
    def parse_jobhistory(dname, repo, arch)
      data = Xmlhash.parse(Backend::Api::BuildResults::Binaries.job_history(dname, repo, arch))
      return [] if data.blank?

      data.elements('jobhist').collect do |p|
        {
          'name' => p['package'],
          'code' => p['code'],
          'versrel' => p['versrel'],
          'verifymd5' => p['verifymd5'],
          'readytime' => p.key?('readytime') ? p['readytime'].to_i : 0
        }
      end
    end

    def add_recursively(mypackages, dbpack)
      return if mypackages.key?(dbpack.id)

      pack = PackInfo.new(dbpack)
      pack.backend_package = dbpack.backend_package

      if dbpack.develpackage
        add_recursively(mypackages, dbpack.develpackage)
        pack.develpack = mypackages[dbpack.develpackage_id]
      end
      mypackages[pack.package_id] = pack
    end

    def get_list_of_project_and_packages(ids)
      Project.joins(:packages).where(packages: { id: ids }).pluck('projects.id, projects.name, packages.id')
    end

    def update_jobhistory(proj, mypackages)
      prjpacks = {}
      dname = proj.name
      mypackages.each_value do |package|
        prjpacks[package.name] = package if package.project == dname
      end

      proj.repositories_linking_project(@dbproj).each do |r|
        repo = r['name']
        r.elements('arch') do |arch|
          cachekey = "history2#{proj.cache_key_with_version}#{repo}#{arch}"
          jobhistory = Rails.cache.fetch(cachekey, expires_in: 30.minutes) do
            parse_jobhistory(dname, repo, arch)
          end
          jobhistory.each do |p|
            pkg = prjpacks[p['name']]
            next unless pkg

            pkg.set_versrel(p['versrel'], p['readytime'])
            pkg.failure(repo, arch, p['readytime'], p['verifymd5']) if p['code'] == 'failed'
          end
        end
      end
    end
  end
end
