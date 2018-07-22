module Webui::ObsFactory
  class DistributionsController < Webui::ObsFactory::ApplicationController
    respond_to :html

    before_action :require_distribution, :require_dashboard

    def show
      @staging_projects = ::ObsFactory::StagingProjectPresenter.sort(@distribution.staging_projects)
      @versions = { source: @distribution.source_version,
                    totest: @distribution.totest_version,
                    published: @distribution.published_version }
      @ring_prjs = ::ObsFactory::ObsProjectPresenter.wrap(@distribution.ring_projects)
      @standard = ::ObsFactory::ObsProjectPresenter.new(@distribution.standard_project)
      @live = @distribution.live_project
      @live = ::ObsFactory::ObsProjectPresenter.new(@live) unless @live.nil?
      @images = ::ObsFactory::ObsProjectPresenter.new(@distribution.images_project)
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

    private

    def require_distribution
      @distribution = ::ObsFactory::Distribution.find(params[:project])
      unless @distribution
        redirect_to main_app.root_path, flash: { error: "#{params[:project]} is not a valid openSUSE distribution, can't offer dashboard" }
      end
    end

    def require_dashboard
      if @distribution.staging_projects.empty?
        redirect_to main_app.root_path, flash: { error: "#{params[:project]} does not offer a dashboard" }
      end
    end
  end
end
