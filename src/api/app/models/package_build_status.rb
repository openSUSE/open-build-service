class PackageBuildStatus
  class NoRepositoriesFound < APIException
    setup 404, "No repositories build against target"
  end

  class FailedToRetrieveBuildInfo < APIException
    setup 404
  end

  def initialize(pkg)
    @pkg = pkg
  end

  def result(opts = {})
    @srcmd5 = opts[:srcmd5]
    gather_md5sums

    tocheck_repos = @pkg.project.repositories_linking_project(opts[:target_project])

    raise NoRepositoriesFound.new if tocheck_repos.empty?

    @result = {}
    tocheck_repos.each do |srep|
      check_repo_status(srep)
    end

    @result
  end

  def check_repo_status(srep)
    @result[srep['name']] ||= {}
    trepo = []
    archs = []
    srep.elements('path') do |p|
      if p['project'] != @pkg.project.name
        r = Repository.find_by_project_and_name(p['project'], p['repository'])
        r.architectures.each { |a| archs << a.name.to_s }
        trepo << [p['project'], p['repository']]
      end
    end
    archs.uniq!
    raise NoRepositoriesFound.new "Can not find repository building against target" unless trepo

    gather_target_packages(trepo)

    archs.each do |arch|
      check_repo_arch_status(srep, arch)
    end
  end

  def gather_target_packages(trepo)
    @tpackages = Hash.new
    vprojects = Hash.new
    trepo.each do |p, _|
      next if vprojects.has_key? p
      prj = Project.find_by_name(p)
      next unless prj # in case of remote projects
      prj.packages.pluck(:name).each { |n| @tpackages[n] = p }
      vprojects[p] = 1
    end
  end

  def check_repo_arch_status(srep, arch)
    check_everbuilt(srep, arch)

    Rails.logger.debug "arch:#{arch} md5:#{@srcmd5} successed:#{@eversucceeded} built:#{@everbuilt}"
    missingdeps = check_missingdeps(srep, arch)

    # if the package does not appear in build history, check flags
    if !@everbuilt
      buildflag=@pkg.find_flag_state("build", srep['name'], arch)
      if buildflag == 'disable'
        @buildcode='disabled'
      end
    end

    unless @buildcode
      gather_current_buildcode(srep, arch)
    end

    @result[srep['name']][arch] = {result: @buildcode}
    @result[srep['name']][arch][:missing] = missingdeps.uniq
  end

  def current_dir
    Directory.hashed(project: @pkg.project.name,
                     package: @pkg.name, view: :info)
  end

  def gather_current_buildcode(srep, arch)
    @buildcode="unknown"
    begin
      # rubocop:disable Metrics/LineLength
      uri = URI("/build/#{CGI.escape(@pkg.project.name)}/_result?package=#{CGI.escape(@pkg.name)}&repository=#{CGI.escape(srep['name'])}&arch=#{CGI.escape(arch)}")
      # rubocop:enable Metrics/LineLength
      resultlist = Xmlhash.parse(ActiveXML.backend.direct_http(uri))
      currentcode = nil
      resultlist.elements('result') do |r|
        r.elements('status') { |s| currentcode = s['code'] }
      end
    rescue ActiveXML::Transport::Error
      currentcode = nil
    end
    if %w(unresolvable failed broken).include?(currentcode)
      @buildcode='failed'
    end
    if %w(building scheduled finished signing blocked).include?(currentcode)
      @buildcode='building'
    end
    if currentcode == 'excluded'
      @buildcode='excluded'
    end
    # if it's currently succeeded but !@everbuilt, it's different sources
    if currentcode == 'succeeded'
      dir = current_dir
      if @srcmd5 == dir['srcmd5'] || @srcmd5 == dir['verifymd5']
        @buildcode='building' # guesssing
      else
        @buildcode='outdated'
      end
    end
  end

  def check_missingdeps(srep, arch)
    missingdeps=[]
    # if
    if @eversucceeded
      # rubocop:disable Metrics/LineLength
      uri = URI("/build/#{CGI.escape(@pkg.project.name)}/#{CGI.escape(srep['name'])}/#{CGI.escape(arch)}/_builddepinfo?package=#{CGI.escape(@pkg.name)}&view=pkgnames")
      # rubocop:enable Metrics/LineLength
      begin
        buildinfo = Xmlhash.parse(ActiveXML.backend.direct_http(uri))
      rescue ActiveXML::Transport::Error => e
        # if there is an error, we ignore
        raise FailedToRetrieveBuildInfo.new "Can't get buildinfo: #{e.summary}"
      end

      buildinfo.get("package").elements("pkgdep") do |b|
        unless @tpackages.has_key? b
          missingdeps << b
        end
      end

    end
    missingdeps
  end

  def check_everbuilt(srep, arch)
    @everbuilt = false
    @eversucceeded = false
    @buildcode = nil

    # first we check the lastfailures. This route is fast but only has up to
    # two results per package. If the md5sum does not match, we have to dig deeper
    hist = Jobhistory.find_hashed(project: @pkg.project.name,
                                  repository: srep['name'],
                                  package: @pkg.name,
                                  arch: arch,
                                  code: 'lastfailures')
    return unless hist
    hist.elements('jobhist') do |jh|
      if jh['verifymd5'] == @verifymd5 || jh['srcmd5'] == @srcmd5
        @everbuilt = true
      end
    end

    if !@everbuilt
      hist = Jobhistory.find_hashed(project: @pkg.project.name,
                                    repository: srep['name'],
                                    package: @pkg.name,
                                    arch: arch,
                                    limit: 20,
                                    expires_in: 15.minutes)
    end

    # going through the job history to check if it built and if yes, succeeded
    hist.elements('jobhist') do |jh|
      next unless jh['verifymd5'] == @verifymd5 || jh['srcmd5'] == @srcmd5
      @everbuilt = true
      if jh['code'] == 'succeeded' || jh['code'] == 'unchanged'
        @buildcode ='succeeded'
        @eversucceeded = true
      end
    end
  end

  def gather_md5sums
    # check current @srcmd5
    cdir = Directory.hashed(project: @pkg.project.name,
                            package: @pkg.name,
                            rev: @srcmd5,
                            view: :info)
    @verifymd5 = cdir['verifymd5'] || @srcmd5
  end
end
