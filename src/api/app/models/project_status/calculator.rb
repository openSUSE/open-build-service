module ProjectStatus
  class Calculator
    # parse the jobhistory and put the result in a format we can cache
    def parse_jobhistory(dname, repo, arch)
      data = Xmlhash.parse(Backend::Api::BuildResults::Binaries.job_history(dname, repo, arch))
      return [] if data.blank?

      ret = []
      data.elements('jobhist') do |p|
        line = {
          'name'      => p['package'],
          'code'      => p['code'],
          'versrel'   => p['versrel'],
          'verifymd5' => p['verifymd5']
        }

        if p.has_key?('readytime')
          if p['readytime'].respond_to?(:to_i)
            line['readytime'] = p['readytime'].to_i
          else
            line['readytime'] = 0
          end
        else
          line['readytime'] = 0
        end
        ret << line
      end
      ret
    end

    def update_jobhistory(proj, mypackages)
      prjpacks = {}
      dname = proj.name
      mypackages.each_value do |package|
        if package.project == dname
          prjpacks[package.name] = package
        end
      end

      proj.repositories_linking_project(@dbproj).each do |r|
        repo = r['name']
        r.elements('arch') do |arch|
          cachekey = "history2#{proj.cache_key}#{repo}#{arch}"
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

    def add_recursively(mypackages, dbpack)
      return if mypackages.has_key? dbpack.id
      pack = PackInfo.new(dbpack)
      pack.backend_package = dbpack.backend_package

      if dbpack.develpackage
        add_recursively(mypackages, dbpack.develpackage)
        pack.develpack = mypackages[dbpack.develpackage_id]
      end
      mypackages[pack.package_id] = pack
    end

    def initialize(dbproj)
      @dbproj = dbproj
    end

    def calc_status(opts = {})
      return {} unless @dbproj

      mypackages = {}

      @dbproj.packages.select([:id, :name, :project_id, :develpackage_id]).includes(:develpackage, :backend_package).load.each do |dbpack|
        add_recursively(mypackages, dbpack)
      end

      list = Project.joins(:packages).where(packages: { id: mypackages.keys }).pluck('projects.id, projects.name, packages.id')
      projects = {}
      list.each do |project_id, project_name, package_name|
        package_info = mypackages[package_name]
        package_info.project = project_name
        if package_info.links_to_id
          package_info.links_to = mypackages[package_info.links_to_id]
        end
        projects[project_id] = project_name
      end

      projects.each do |id, _|
        if !opts[:pure_project] || id == @dbproj.id
          update_jobhistory(Project.find(id), mypackages)
        end
      end

      # cleanup
      mypackages.each_key do |key|
        mypackages.delete(key) if mypackages[key].project != @dbproj.name
      end

      mypackages
    end
  end
end
