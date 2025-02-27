module Webui::ProjectBuildResultParsing
  extend ActiveSupport::Concern

  def monitor_buildresult
    @legend = Buildresult::STATUS_DESCRIPTION

    @name_filter = params[:pkgname]
    @lastbuild_switch = params[:lastbuild]
    # FIXME: this code needs some love
    defaults = if params[:defaults]
                 (begin
                   Integer(params[:defaults])
                 rescue ArgumentError
                   1
                 end).positive?
               else
                 true
               end
    params['expansionerror'] = 1 if params['unresolvable']
    monitor_set_filter(defaults)

    find_opt = { project: @project.to_param, view: 'status', code: @status_filter,
                 arch: @arch_filter, repository: @repo_filter }
    find_opt[:lastbuild] = 1 if @lastbuild_switch.present?

    buildresult = Buildresult.find_hashed(find_opt)
    if buildresult.empty?
      flash[:warning] = "No build results for project '#{elide(@project.name)}'"
      redirect_to action: :show, project: params[:project]
      return
    end

    return unless buildresult.key?('result')

    buildresult
  end

  def monitor_parse_buildresult(buildresult)
    @packagenames = Set.new
    @statushash = {}
    @repostatushash = {}
    @repostatusdetailshash = {}
    @failures = 0

    buildresult.elements('result') do |result|
      monitor_parse_result(result)
    end

    # convert to sorted array
    @packagenames = @packagenames.to_a.sort!
  end

  def monitor_parse_result(result)
    repo = result['repository']
    arch = result['arch']

    return unless @repo_filter.nil? || @repo_filter.include?(repo)
    return unless @arch_filter.nil? || @arch_filter.include?(arch)

    # package status cache
    @statushash[repo] ||= {}
    stathash = @statushash[repo][arch] = {}

    result.elements('status') do |status|
      package = status['package']
      next if @name_filter.present? && !filter_matches?(package, @name_filter)

      stathash[package] = status
      @packagenames.add(package)
      @failures += 1 if status['code'].in?(%w[unresolvable failed broken])
    end

    # repository status cache
    @repostatushash[repo] ||= {}
    @repostatusdetailshash[repo] ||= {}

    return unless result.key?('state')

    @repostatushash[repo][arch] = if result.key?('dirty')
                                    "outdated_#{result['state']}"
                                  else
                                    result['state']
                                  end

    @repostatusdetailshash[repo][arch] = result['details'] if result.key?('details')
  end

  def monitor_set_arch_filter(defaults)
    repos = @project.repositories
    @avail_arch_values = repos.joins(:architectures).select('architectures.name').distinct.order('architectures.name').pluck('architectures.name')

    @arch_filter = []
    @avail_arch_values.each do |s|
      archid = valid_xml_id("arch_#{s}")
      @arch_filter << s if defaults || params[archid]
    end
  end

  def monitor_set_repo_filter(defaults)
    repos = @project.repositories
    @avail_repo_values = repos.select(:name).distinct.order(:name).pluck(:name)

    @repo_filter = []
    @avail_repo_values.each do |s|
      repoid = valid_xml_id("repo_#{s}")
      @repo_filter << s if defaults || params[repoid]
    end
  end

  def monitor_set_filter(defaults)
    @avail_status_values = Buildresult.avail_status_values
    @status_filter = []
    excluded_status = %w[disabled excluded unknown]
    @avail_status_values.each do |s|
      id = s.delete(' ')
      if params.key?(id)
        next if params[id].to_s == '0'
      else
        next unless defaults
      end
      next if defaults && excluded_status.include?(s)

      @status_filter << s
    end

    monitor_set_arch_filter(defaults)
    monitor_set_repo_filter(defaults)
  end

  def filter_matches?(input, filter_string)
    result = false
    filter_string.gsub!(/\s*/, '')
    filter_string.split(',').each do |filter|
      no_invert = filter.match(/(^!?)(.+)/)
      result = if no_invert[1] == '!'
                 input.include?(no_invert[2]) ? result : true
               else
                 input.include?(no_invert[2]) || result
               end
    end
    result
  end
end
