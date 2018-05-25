module ObsFactory
  # View decorator for StagingProject
  class StagingProjectPresenter < BasePresenter

    # Wraps the associated subproject with the corresponding decorator.
    #
    # @return StagingProjectPresenter object
    def subproject
      return nil unless model.subproject
      ObsFactory::StagingProjectPresenter.new(model.subproject)
    end

    def self.sort(collection)
      prjs = wrap(collection)
      prjs.sort_by! { |a| a.sort_key }
    end

    # List of packages included in the staging_project.
    #
    # The names are extracted from the description (that is in fact a yaml
    # string).
    #
    # @return [String] package names delimited by commas
    def description_packages
      requests = meta["requests"]
      if requests.blank?
        ''
      else
        requests.map { |i| i["package"] }.sort.join(', ')
      end
    end

    # engine helpers are troublesome, so we avoid them
    def self.review_icon(reviewer)
      case reviewer
      when 'opensuse-review-team' then
        'search'
      when 'repo-checker' then
        'cog'
      when 'sle-release-managers', 'leap-reviewers', 'caasp-release-managers' then
        'users'
      when 'maintenance-team' then
        'medkit'
      when 'legal-team', 'legal-auto' then
        'graduation-cap'
      when 'leaper' then
        'code-fork'
      when 'sle-changelog-checker' then
        'tags'
      else
        'ban'
      end
    end

    # List of requests/packages tracked in the staging project
    def classified_requests
      return @classified_requests if @classified_requests

      @classified_requests = []
      requests = selected_requests
      return @classified_requests unless requests

      reviews = Hash.new
      missing_reviews.each do |r|
        reviews[r[:request]] ||= []
        r[:icon] = self.class.review_icon(r[:by])
        reviews[r[:request]] << r
      end
      requests.each do |req|
        r = { number: req.number, package: req.package }
        css = 'ok'
        r[:missing_reviews] = reviews[req.number]
        unless r[:missing_reviews].blank?
          css = 'review'
        end
        if req.obsolete?
          css = 'obsolete'
        end
        r[:css] = css
        r[:request_type] = req.request_type
        @classified_requests << r
      end
      # now append untracked reqs
      untracked_requests.each do |req|
        @classified_requests << { number: req.number, package: req.package, css: 'untracked' }
      end
      @classified_requests.sort! { |x, y| x[:package] <=> y[:package] }
      @classified_requests
    end

    # determine build progress as percentage
    # if the project contains subprojects but is complete, the percentage
    # is the subproject's
    def build_progress
      total = 0
      final = 0
      building_repositories.each do |r|
        total += r[:tobuild] + r[:final]
        final += r[:final]
      end
      ret = { subproject: name }
      if total != 0
        # if we have building repositories, make sure we don't exceed 99
        ret[:percentage] = [final * 100 / total, 99].min
      else
        ret[:percentage] = 100
        return subproject.build_progress if subproject
      end
      ret
    end

    # collect the broken packages of all subprojects
    def broken_packages
      ret = model.broken_packages
      ret += subproject.broken_packages if subproject
      ret
    end

    # @return [Array] Array of OpenqaJob objects for all subprojects
    def all_openqa_jobs
      ret = model.openqa_jobs
      ret += subproject.openqa_jobs if subproject
      ret
    end

    # Wraps the associated openqa_jobs with the corresponding decorator.
    #
    # @return [Array] Array of OpenqaJobPresenter objects for all subprojects
    def openqa_jobs
      ObsFactory::OpenqaJobPresenter.wrap(all_openqa_jobs)
    end

    # Wraps the failed openqa_jobs with the corresponding decorator.
    #
    # @return [Array] Array of OpenqaJobPresenter objects for all subprojects
    def failed_openqa_jobs
      ObsFactory::OpenqaJobPresenter.wrap(all_openqa_jobs.select { |job| job.failing_modules.present? })
    end

    # return a percentage counting the reviewed requests / total requests
    def review_percentage
      total = classified_requests.size
      missing = 0
      classified_requests.each do |rq|
        missing +=1 if rq[:missing_reviews]
      end
      if total > 0
        100 - missing * 100 / total
      else
        0
      end
    end

    def testing_percentage
      jobs = all_openqa_jobs
      notdone = 0
      jobs.each do |job|
        notdone += 1 unless %w(passed failed).include?(job.result)
      end
      if jobs.size > 0
        100 - notdone * 100 / jobs.size
      else
        0
      end
    end

    # returns a number presenting how high it should be in the list of staging prjs
    # the lower the number, the earlier it is in the list - acceptable A first
    def sort_key
      main = case overall_state
      when :acceptable then
        0
      when :review then
        10000 - review_percentage * 100
      when :testing then
        20000 - testing_percentage * 100
      when :building then
        30000 - build_progress[:percentage] * 100
      when :failed then
        40000
      when :unacceptable then
        50000
      when :empty
        60000
      else
        Rails.logger.error "untracked #{overall_state}"
        return
      end
      main + letter.ord()
    end
  end
end
