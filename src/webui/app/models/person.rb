class Person < ActiveXML::Base
  default_find_parameter :login
  
  # redefine make_stub so that Person.new( :login => 'login_name' ) works
  class << self
    def make_stub( opt )
      
      # stay backwards compatible to old arguments (:name instead of :login)
      if not opt.has_key? :login
        opt[:login] = opt[:name]
      end
      return REXML::Document.new( "<person><login>#{opt[:login]}</login></person>" ).root
    end
  end
  
  def to_s
    name.to_s
  end

  def add_watched_project(name)
    return nil unless name
    
    data.add_element 'watchlist' unless has_element? :watchlist
    watchlist.data.add_element 'project', 'name' => name
    
    logger.debug "user '#{login}' is now watching project '#{name}'"
  end

  def remove_watched_project(name)
    return nil unless name
    return nil unless has_element? :watchlist

    watchlist.data.delete_element "project[@name='#{name}']"
    
    logger.debug "user '#{login}' removes project '#{name}' from watchlist"
  end

  def watches?(name)
    has_element?(:watchlist) and watchlist.has_element?("project[@name='#{name}']")
  end
end
