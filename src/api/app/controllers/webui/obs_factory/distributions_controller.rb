module ObsFactory
  class DistributionsController < ApplicationController
    respond_to :html

    before_action :require_distribution, :require_dashboard

    def require_distribution
      @distribution = Distribution.find(params[:project])
      unless @distribution
        redirect_to main_app.root_path, flash: { error: "#{params[:project]} is not a valid openSUSE distribution, can't offer dashboard" }
      end
    end

    def require_dashboard
      if @distribution.staging_projects.empty?
        redirect_to main_app.root_path, flash: { error: "#{params[:project]} does not offer a dashboard" }
      end
    end

    def show
      @staging_projects = StagingProjectPresenter.sort(@distribution.staging_projects)
      @versions = { source: @distribution.source_version,
                    totest: @distribution.totest_version,
                    published: @distribution.published_version }
      @ring_prjs = ObsProjectPresenter.wrap(@distribution.ring_projects)
      @standard = ObsProjectPresenter.new(@distribution.standard_project)
      @live = @distribution.live_project
      @live = ObsProjectPresenter.new(@live) unless @live.nil?
      @images = ObsProjectPresenter.new(@distribution.images_project)
      @openqa_jobs = @distribution.openqa_jobs_for(:totest)
      calculate_reviews
      # For the breadcrumbs
      @project = @distribution.project
    end

    protected

    def calculate_reviews
      @reviews = {}
      @reviews[:review_team]  = @distribution.requests_with_reviews_for_group('opensuse-review-team').size
      @reviews[:factory_auto] = @distribution.requests_with_reviews_for_group('factory-auto').size
      @reviews[:legal_auto]   = @distribution.requests_with_reviews_for_group('legal-auto').size
      @reviews[:legal_team]   = @distribution.requests_with_reviews_for_group('legal-team').size
      @reviews[:repo_checker] = @distribution.requests_with_reviews_for_user('repo-checker').size
    end
  end
end
