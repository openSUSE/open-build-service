class Webui::SearchesController < Webui::BaseController

  def new
    @search = FullTextSearch.new(classes: %(Project Package),
                                 fields: %w(name title))
    render json: @search
  end

  def create
    @search = FullTextSearch.new(params[:search])
    @search.search(:page => params[:page], :per_page => params[:per_page])
    render json: @search
  end
end
