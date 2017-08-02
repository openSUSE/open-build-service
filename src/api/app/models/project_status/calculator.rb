module ProjectStatus
  class Calculator
    def check_md5(packages)
      # remap
      ph = {}
      packages.each { |p| ph[p.package_id] = p }
      packages = Package.where(id: ph.keys).includes(:backend_package).references(:backend_packages)
      packages.each do |p|
        obj = ph[p.id]
        obj.bp = p.backend_package
        obj.srcmd5 = obj.bp.srcmd5
        obj.verifymd5 = obj.bp.verifymd5
        obj.error = obj.bp.error
        obj.links_to = obj.bp.links_to_id
        obj.changesmd5 = obj.bp.changesmd5
        obj.maxmtime = obj.bp.maxmtime.to_i
      end
    end

    # parse the jobhistory and put the result in a format we can cache
    def parse_jobhistory(dname, repo, arch)
      uri = "/build/#{CGI.escape(dname)}/#{CGI.escape(repo)}/#{arch}/_jobhistory?code=lastfailures"

      ret = []
      d = Backend::Connection.get(uri).body

      return [] if d.blank?

      data = Xmlhash.parse(d)

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
            pkg.failure(repo, arch, p['readytime'], p['verifymd5']) if p['code'] == "failed"
          end
        end
      end
    end

    def add_recursively(mypackages, dbpack)
      return if mypackages.has_key? dbpack.id
      pack = PackInfo.new(dbpack)

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

      @dbproj.packages.select([:id, :name, :project_id, :develpackage_id]).includes(:develpackage).load.each do |dbpack|
        add_recursively(mypackages, dbpack)
      end

      check_md5(mypackages.values)

      list = Project.joins(:packages).where(packages: {id: mypackages.keys}).pluck("projects.id as pid, projects.name, packages.id")
      projects = {}
      list.each do |pid, pname, id|
        obj = mypackages[id]
        obj.project = pname
        if obj.links_to
          obj.links_to = mypackages[obj.links_to]
        end
        projects[pid] = pname
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
