class MainController < ApplicationController

  skip_before_filter :authorize


  def search
    ### search form
  end


  ### generate search results
  def search_result
    @search_text = params[:search_text]
    @search_what = params[:search_what]
    @search_in   = params[:search_in]

    if @search_text.length < 3
      flash[:error] = "Search String must contain at least 3 Characters."
      redirect_to :controller => 'main', :action => 'search'
    end

    logger.debug "performing search: search_text='#{@search_text}'"

    @results = {}
    @search_what = %w{ package project }

    @search_what.each do |s_what|
      predicate = "contains(@name,'#{@search_text}') or contains(@title,'#{@search_text}') or contains(description,'#{@search_text}')"
      @results[s_what] = Collection.find( :what => s_what, :predicate => predicate )

      ### TODO: give the results some weight
      #@results[s_what].each do |result|
      #  weight = 0
      #  weight += 5 if result.name ~= /@search_text/
      #  weight += 3 if result.title ~= /@search_text/
      #  weight += 1 if result.description ~= /@search_text/
      #end

    end

  end


end
