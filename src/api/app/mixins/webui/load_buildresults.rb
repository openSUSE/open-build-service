# frozen_string_literal: true
module Webui::LoadBuildresults
  # TODO: Make use of the Project#buildresults method and get rid of this duplicated logic
  def fill_status_cache
    @repohash = {}
    @statushash = {}
    @packagenames = []
    @repostatushash = {}
    @repostatusdetailshash = {}
    @failures = 0

    @buildresult.elements('result') do |result|
      @resultvalue = result
      repo = result['repository']
      arch = result['arch']

      next unless @repo_filter.nil? || @repo_filter.include?(repo)
      next unless @arch_filter.nil? || @arch_filter.include?(arch)

      @repohash[repo] ||= []
      @repohash[repo] << arch

      # package status cache
      @statushash[repo] ||= {}
      stathash = @statushash[repo][arch] = {}

      result.elements('status') do |status|
        stathash[status['package']] = status
        if status['code'].in?(['unresolvable', 'failed', 'broken'])
          @failures += 1
        end
      end
      @packagenames << stathash.keys

      # repository status cache
      @repostatushash[repo] ||= {}
      @repostatusdetailshash[repo] ||= {}

      if result.key? 'state'
        if result.key? 'dirty'
          @repostatushash[repo][arch] = 'outdated_' + result['state']
        else
          @repostatushash[repo][arch] = result['state']
        end
        if result.key? 'details'
          @repostatusdetailshash[repo][arch] = result['details']
        end
      end
    end
  end
end
