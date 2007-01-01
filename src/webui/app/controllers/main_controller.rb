class MainController < ApplicationController

  skip_before_filter :authorize


  def search
    ### search form
  end


  def search_advanced
    ### advanced search form
  end


  ### generate search results
  def search_result
    @search_text = params[:search_text]

    if !@search_text or @search_text.length < 2
      flash[:error] = "Search String must contain at least 2 Characters."
      redirect_to :controller => 'main', :action => 'search'
      return
    end

    logger.debug "performing search: search_text='#{@search_text}'"

    if params[:advanced]
      @search_what = []
      @search_what << 'package' if params[:package]
      @search_what << 'project' if params[:project]
    else
      @search_what = %w{ package project }
    end

    @results = []
    @search_what.each do |s_what|

      # build xpath predicate
      if params[:advanced]
        p = []
        p << "contains(@name,'#{@search_text}')" if params[:name]
        p << "contains(title,'#{@search_text}')" if params[:title]
        p << "contains(description,'#{@search_text}')" if params[:description]
        predicate = p.join(' or ')
        if predicate.empty?
          flash[:error] = "You need to choose name, title or description."
          return
        end
      else
        predicate = "contains(@name,'#{@search_text}') or contains(title,'#{@search_text}') or contains(description,'#{@search_text}')"
      end

      collection = Collection.find( :what => s_what, :predicate => predicate )

      # collect all results and give them some weight
      collection.send("each_#{s_what}") do |data|

        s = @search_text
        count = 0
        weight = 0
        weight += 10 if s_what == 'project'
        weight += 20 if data.name.to_s.downcase == @search_text.downcase

        # weight the name
        weight += 9*count if count = data.name.to_s.scan(/\b#{s}\b/i).length
        weight += 6*count if count = data.name.to_s.scan(/\b#{s}/i).length
        weight += 4*count if count = data.name.to_s.scan(/#{s}/i).length

        # weight the title
        weight += 6*count if count = data.title.to_s.scan(/\b#{s}\b/i).length
        weight += 4*count if count = data.title.to_s.scan(/\b#{s}/i).length
        weight += 2*count if count = data.title.to_s.scan(/#{s}/i).length

        # weight the description
        weight += 3*count if count = data.description.to_s.scan(/\b#{s}\b/i).length
        weight += 2*count if count = data.description.to_s.scan(/\b#{s}/i).length
        weight += 1*count if count = data.description.to_s.scan(/#{s}/i).length

        @results << { :type => s_what, :data => data, :weight => weight }
      end
    end

    # reorder results by weight
    @results.sort! { |a,b| b[:weight] <=> a[:weight] }

  end


end
