class MainController < ApplicationController

  skip_before_filter :authorize


  ### advanced search form
  def search_advanced
    @searchwhat_options = [
      ['packages','package'],
      ['projects','project']
    ]
    @searchin_options = [
      ['description','description'],
      ['title','title'],
      ['name','name']
    ]
    search_result if request.post?
  end


  ### simple search form
  def search_simple
    # action to test simple searchbox partial
    @search_what = 'package'
    @search_in = 'name'
  end


  ### generate search results
  def search_result
    @search_text = params[:search_text]
    @search_what = params[:search_what]
    @search_in   = params[:search_in]

    allowed_fields = ['package','project']
    if allowed_fields.grep(@search_what) == nil
      logger.debug "search aborted: search_what=#{@search_what} is not in the list of allowed_fields"
      return
    end

    logger.debug "performing search: search_text=#{@search_text}, @search_what=#{@search_what}, @search_in=#{@search_in}"

    frontend = FrontendCompat.new
    collection = ActiveXML::Base.new 'collection'

    collection.raw_data = frontend.search @search_what,
      'contains(@' + @search_in.to_s +  ',\'' + @search_text.to_s + '\')'

    @results = []
    collection.send( 'each_' + @search_what ) do |item|
      @results << item
    end

  end


end
