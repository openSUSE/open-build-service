require 'opensuse/backend'

class RepositoryController < ApplicationController

  def index
    repolist = DbProject.get_repo_list

    builder = Builder::XmlMarkup.new( :indent => 2 )
    xml = builder.directory do |dir|
      repolist.each do |repo|
        dir.entry( :name => repo )
      end
    end

    render :text => xml, :content_type => "text/xml"
  end
end
