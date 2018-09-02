class PackageBuildStatus
  class NoRepositoriesFound < APIError
    setup 404, 'No repositories build against target'
  end

  class FailedToRetrieveBuildInfo < APIError
    setup 404
  end

  def initialize(pkg)
    @pkg = pkg
  end

  def result(opts = {})
    @srcmd5 = opts[:srcmd5]
    @multibuild_pkg = opts[:multibuild_pkg]
    gather_md5sums

    tocheck_repos = @pkg.project.repositories_linking_project(opts[:target_project])

    raise NoRepositoriesFound if tocheck_repos.empty?

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
    raise NoRepositoriesFound, 'Can not find repository building against target' unless trepo

    gather_target_packages(trepo)

    archs.each do |arch|
      check_repo_arch_status(srep, arch)
    end
  end

  def gather_target_packages(trepo)
    @tpackages = {}
    vprojects = {}
    trepo.each do |p, _|
      next if vprojects.key?(p)
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
    unless @everbuilt
      buildflag = @pkg.find_flag_state('build', srep['name'], arch)
      @buildcode = 'disabled' if buildflag == 'disable'
    end

    gather_current_buildcode(srep, arch) unless @buildcode

    @result[srep['name']][arch] = { result: @buildcode }
    @result[srep['name']][arch][:missing] = missingdeps.uniq
  end

  def current_dir
    Directory.hashed(project: @pkg.project.name,
                     package: @pkg.name, view: :info)
  end

  def gather_current_buildcode(srep, arch)
    @buildcode = 'unknown'
    begin
      package = CGI.escape(@multibuild_pkg || @pkg.name)
      resultlist = Xmlhash.parse(Backend::Api::BuildResults::Status.build_result(@pkg.project.name, package, srep['name'], arch))
      currentcode = nil
      resultlist.elements('result') do |r|
        r.elements('status') { |s| currentcode = s['code'] }
      end
    rescue Backend::Error
      currentcode = nil
    end
    if currentcode.in?(['unresolvable', 'failed', 'broken'])
      @buildcode = 'failed'
    end
    if currentcode.in?(['building', 'scheduled', 'finished', 'signing', 'blocked'])
      @buildcode = 'building'
    end
    @buildcode = 'excluded' if currentcode == 'excluded'
    # if it's currently succeeded but !@everbuilt, it's different sources
    return unless currentcode == 'succeeded'

    dir = current_dir
    if @srcmd5 == dir['srcmd5'] || @srcmd5 == dir['verifymd5']
      @buildcode = 'building' # guesssing
    else
      @buildcode = 'outdated'
    end
  end

  def check_missingdeps(srep, arch)
    missingdeps = []
    # if
    if @eversucceeded
      begin
        buildinfo = Xmlhash.parse(Backend::Api::BuildResults::Binaries.build_dependency_info(@pkg.project.name, @pkg.name, srep['name'], arch))
      rescue Backend::Error => e
        # if there is an error, we ignore
        raise FailedToRetrieveBuildInfo, "Can't get buildinfo: #{e.summary}"
      end

      buildinfo.get('package').elements('pkgdep') do |b|
        missingdeps << b unless @tpackages.key?(b)
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
    hist = Xmlhash.parse(Backend::Api::BuildResults::JobHistory.last_failures(@pkg.project.name, @pkg.name, srep['name'], arch))
    return unless hist
    hist.elements('jobhist') do |jh|
      if jh['verifymd5'] == @verifymd5 || jh['srcmd5'] == @srcmd5
        @everbuilt = true
      end
    end

    unless @everbuilt
      hist = Xmlhash.parse(Backend::Api::BuildResults::JobHistory.all_for_package(@pkg.project.name, @pkg.name, srep['name'], arch, 20))
    end

    # going through the job history to check if it built and if yes, succeeded
    hist.elements('jobhist') do |jh|
      next unless jh['verifymd5'] == @verifymd5 || jh['srcmd5'] == @srcmd5
      @everbuilt = true
      if jh['code'] == 'succeeded' || jh['code'] == 'unchanged'
        @buildcode = 'succeeded'
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
