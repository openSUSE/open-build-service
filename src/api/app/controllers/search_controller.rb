class SearchController < ApplicationController

  require 'xpath_engine'

  def project(render_all=true)
    predicate = predicate_from_match_parameter(params[:match])
    
    logger.debug "searching in projects, predicate: '#{predicate}'"
    xpath = "/project[#{predicate}]"

    render :text => search(xpath, render_all), :content_type => "text/xml"
  end

  def project_id
    project(false)
  end

  #search  in package metadata
  def package(render_all=true)
    predicate = predicate_from_match_parameter(params[:match])
    
    logger.debug "searching in packages, predicate: '#{predicate}'"
    xpath = "/package[#{predicate}]"

    render :text => search(xpath, render_all), :content_type => "text/xml"
  end

  def package_id
    package( false )
  end

  private

  def predicate_from_match_parameter(p)
    if p=~ /\[(.*)\]/
      pred = $1
    else
      pred = p
    end
    pred = "*" if pred.nil? or pred.empty?
    return pred
  end

  def search(xpath, render_all)
    xe = XpathEngine.new
    collection = xe.find( xpath )

    output = String.new
    output << "<?xml version='1.0' encoding='UTF-8'?>\n"
    output << "<collection>\n"

    collection.each do |item|
      if render_all
        str = item.to_axml
      else 
        str = item.to_axml_id
      end
      output << str.split(/\n/).map {|l| "  "+l}.join("\n") + "\n"
    end

    output << "</collection>\n"
    return output
  end
end
