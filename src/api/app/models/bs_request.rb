class BsRequest < ActiveXML::Base
  default_find_parameter :id

  # override Object#type to get access to the request type attribute
  def type(*args, &block)
    self.value(:type)
  end

  # override Object#id to get access to the request id attribute
  def id(*args, &block)
    self.value(:id)
  end

  def creator
    if self.has_element?(:history)
      e = self.find_first('history')
    else
      e = state
    end
    raise RuntimeError, 'broken request: no state/history named "new" or "review"' if e.nil?
    raise RuntimeError, 'broken request: no attribute named "who"' unless e.has_attribute?(:who)
    return e.who
  end

  def is_reviewer? (user)
    return false unless self.has_element?(:review)

    self.each_review do |r|
      if r.has_attribute? 'by_user'
        return true if user.login == r.value("by_user")
      elsif r.has_attribute? 'by_group'
        return true if user.is_in_group? r.value("by_group")
      elsif r.has_attribute? 'by_project'
        if r.has_attribute? 'by_package'
           pkg = DbPackage.find_by_project_and_name r.value("by_project"), r.value("by_package")
           return true if pkg and user.can_modify_package? pkg
        else
           prj = DbProject.find_by_name r.value("by_project")
           return true if prj and user.can_modify_project? prj
        end
      end
    end

    return false
  end

  def initialize( _data )
    super(_data)

    if has_element? 'submit' and has_attribute? 'type'
      # old style, convert to new style on the fly
      delete_attribute('type')
      submit.element_name = 'action' # Rename 'submit' element to 'action'
      action.set_attribute('type', 'submit')
    end
  end

  def remove_reviews(opts)
    return false unless opts[:by_user] or opts[:by_group] or opts[:by_project] or opts[:by_package]
    each_review do |review|
      if review.by_user and review.by_user == opts[:by_user] or
         review.by_group and review.by_group == opts[:by_group] or
         review.by_project and review.by_project == opts[:by_project] or
         review.by_package and review.by_package == opts[:by_package]
        logger.debug "Removing review #{review.dump_xml}"
        self.delete_element(review)
      end
    end
    return self.save()
  end

  def change_state(state, user, opts)
    opts = {:superseded_by => nil, :comment => ''}.merge(opts)
    if ['new', 'review', 'accepted', 'declined', 'revoked', 'superseded'].include?(state)
      begin
        path = "/request/#{self.id}?cmd=changestate&newstate=#{CGI.escape(state)}&user=#{CGI.escape(user)}&comment=#{CGI.escape(opts[:comment])}"
        path += "&superseded_by=#{CGI.escape(opts[:superseded_by])}" if opts[:superseded_by]
        response = Suse::Backend.post(path, '')
        if response.code == "200"
          self.state.set_value('name', state) # Set local state to match change sent to backend
          logger.debug "Changed state of request '#{self.id}' to '#{state}'"
          return true
        else
          return false
        end
      rescue Suse::Backend::HTTPError
        logger.debug "Unable to change state of request '#{self.id}' to '#{state}'"
        return false
      end
    end
    return false
  end

end
