module ObsFactory
  class OpenqaJobsController < ApplicationController
    respond_to :json, :html

    def index
      @q = params[:q] || {}
      @cache = params[:cache]
      openqa_jobs = OpenqaJob.find_all_by(@q, cache: @cache)
      respond_to do |format|
        format.html { @openqa_jobs = OpenqaJobPresenter.wrap(openqa_jobs) }
        format.json { render json: openqa_jobs }
      end
    end
  end
end
