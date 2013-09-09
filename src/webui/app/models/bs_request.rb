class BsRequest < ActiveXML::Node

  class ListError < Exception; end
  class ModifyError < Exception; end

  default_find_parameter :id

  class << self
    def make_stub(opt)
      target_package, target_repository = "", ""
      opt[:description] = "" if !opt.has_key? :description or opt[:description].nil?
      if opt[:targetpackage] and not opt[:targetpackage].empty?
        target_package = "package=\"#{::Builder::XChar.encode(opt[:targetpackage])}\""
      end
      if opt[:targetrepository] and not opt[:targetrepository].empty?
        target_repository = "repository=\"#{::Builder::XChar.encode(opt[:targetrepository])}\""
      end

      # set request-specific options
      case opt[:type]
        when "submit" then
          # use source package name if no target package name is given for a submit request
          target_package = "package=\"#{::Builder::XChar.encode(opt[:package])}\"" if target_package.empty?
          # set target package is the same as the source package if no target package is specified
          revision_option = "rev=\"#{::Builder::XChar.encode(opt[:rev])}\"" unless opt[:rev].blank?
          action = "<action type=\"#{opt[:type]}\">"
          action += "<source project=\"#{opt[:project]}\" package=\"#{opt[:package]}\" #{revision_option}/>"
          action += "<target project=\"#{::Builder::XChar.encode(opt[:targetproject])}\" #{target_package}/>"
          action += "<options><sourceupdate>#{opt[:sourceupdate]}</sourceupdate></options>" unless opt[:sourceupdate].blank?
          action +="</action>"
        when "add_role" then
          action = "<action type=\"#{opt[:type]}\">"
          action += "<group name=\"#{opt[:group]}\" role=\"#{opt[:role]}\"/>" unless opt[:group].blank?
          action += "<person name=\"#{opt[:person]}\" role=\"#{opt[:role]}\"/>" unless opt[:person].blank?
          action += "<target project=\"#{::Builder::XChar.encode(opt[:targetproject])}\" #{target_package}/>"
          action +="</action>"
        when "set_bugowner" then
          if opt[:targetproject].class == Array
            action = ""
            opt[:targetproject].each do |p|
              project, package = p.split("/")
              action += "<action type=\"#{opt[:type]}\">"              
              if opt[:person]
                action +="<person name=\"#{opt[:person]}\" role=\"bugowner\"/>"
              end
              if opt[:group]
                action +="<group name=\"#{opt[:group]}\" role=\"bugowner\"/>"
              end
              action +="<target project=\"#{::Builder::XChar.encode(project)}\" package=\"#{::Builder::XChar.encode(package)}\"/>"
              action +="</action>"
            end
          else
            action = "<action type=\"#{opt[:type]}\">"
            if opt[:person]
              action += "<person name=\"#{opt[:person]}\" role=\"bugowner\"/>"
            end
            if opt[:group]
              action += "<group name=\"#{opt[:group]}\" role=\"bugowner\"/>"
            end
            action += "<target project=\"#{::Builder::XChar.encode(opt[:targetproject])}\" #{target_package} />"
            action +="</action>"
          end
        when "change_devel" then
          action = "<action type=\"#{opt[:type]}\">"
          action += "<source project=\"#{opt[:project]}\" package=\"#{opt[:package]}\"/>"
          action += "<target project=\"#{::Builder::XChar.encode(opt[:targetproject])}\" #{target_package}/>"
          action +="</action>"
        when "maintenance_incident" then
          action = "<action type=\"#{opt[:type]}\">"
          action += "<source project=\"#{opt[:project]}\" />"
          action += "<target project=\"#{::Builder::XChar.encode(opt[:targetproject])}\" />" unless opt[:targetproject].blank?
          action +="</action>"
        when "maintenance_release" then
          action = "<action type=\"#{opt[:type]}\">"
          action += "<source project=\"#{opt[:project]}\" />"
          action += "<target project=\"#{::Builder::XChar.encode(opt[:targetproject])}\" />" unless opt[:targetproject].blank?
          action +="</action>"
        when "delete" then
          action = "<action type=\"#{opt[:type]}\">"
          action += "<target project=\"#{::Builder::XChar.encode(opt[:targetproject])}\" #{target_package} #{target_repository}/>"
          action +="</action>"
      end
      # build the request XML
      reply = <<-EOF
        <request>
          #{action}
          <state name="new"/>
          <description>#{::Builder::XChar.encode(opt[:description])}</description>
        </request>
      EOF
      return reply
    end

    def addReview(id, opts)
      opts = {:user => nil, :group => nil, :project => nil, :package => nil, :comment => nil}.merge opts

      path = "/request/#{id}?cmd=addreview"
      path << "&by_user=#{CGI.escape(opts[:user])}" unless opts[:user].blank?
      path << "&by_group=#{CGI.escape(opts[:group])}" unless opts[:group].blank?
      path << "&by_project=#{CGI.escape(opts[:project])}" unless opts[:project].blank?
      path << "&by_package=#{CGI.escape(opts[:package])}" unless opts[:package].blank?
      begin
        ActiveXML::transport.direct_http URI("#{path}"), :method => "POST", :data => opts[:comment]
        BsRequest.free_cache(id)
        return true
      rescue ActiveXML::Transport::ForbiddenError => e
        raise ModifyError, e.summary
      rescue ActiveXML::Transport::NotFoundError => e
        raise ModifyError, e.summary
      end
    end

    def modifyReview(id, changestate, opts)
      unless (changestate=="accepted" || changestate=="declined")
        raise ModifyError, "unknown changestate #{changestate}"
      end

      path = "/request/#{id}?newstate=#{changestate}&cmd=changereviewstate"
      path << "&by_user=#{CGI.escape(opts[:user])}" unless opts[:user].blank?
      path << "&by_group=#{CGI.escape(opts[:group])}" unless opts[:group].blank?
      path << "&by_project=#{CGI.escape(opts[:project])}" unless opts[:project].blank?
      path << "&by_package=#{CGI.escape(opts[:package])}" unless opts[:package].blank?
      begin
        ActiveXML::transport.direct_http URI("#{path}"), :method => "POST", :data => opts[:comment]
        BsRequest.free_cache(id)
        return true
      rescue ActiveXML::Transport::Error => e
        raise ModifyError, e.summary
      end
    end

    def modify(id, changestate, opts)
      opts = {:superseded_by => nil, :force => false, :reason => ''}.merge opts
      unless ["accepted", "declined", "revoked", "superseded", "new"].include?(changestate)
        raise ModifyError, "unknown changestate #{changestate}"
      end
      path = "/request/#{id}?newstate=#{changestate}&cmd=changestate"
      path += "&superseded_by=#{opts[:superseded_by]}" unless opts[:superseded_by].blank?
      path += "&force=1" if opts[:force]
      begin
        ActiveXML::transport.direct_http URI("#{path}"), :method => "POST", :data => opts[:reason].to_s
        BsRequest.free_cache(id)
        return true
      rescue ActiveXML::Transport::Error => e
        raise ModifyError, e.summary
      end
    end

    def set_incident(id, incident_project)
      begin
        path = "/request/#{id}?cmd=setincident&incident=#{incident_project}"
        ActiveXML::transport.direct_http URI(path), :method => "POST", :data => ''
        BsRequest.free_cache(id)
        return true
      rescue ActiveXML::Transport::Error => e
        raise ModifyError, e.summary
      end
      raise ModifyError, "Unable to merge with incident #{incident_project}"
    end

    def find_last_request(opts)
      unless opts[:targetpackage] and opts[:targetproject] and opts[:sourceproject] and opts[:sourcepackage]
        raise RuntimeError, "missing parameters"
      end
      pred = "(action/target/@package='#{opts[:targetpackage]}' and action/target/@project='#{opts[:targetproject]}' and action/source/@project='#{opts[:sourceproject]}' and action/source/@package='#{opts[:sourcepackage]}' and action/@type='submit')"
      requests = Collection.find_cached :what => :request, :predicate => pred
      last = nil
      requests.each_request do |r|
        last = r if not last or r.value(:id).to_i > last.value(:id).to_i
      end
      return last
    end

    # FIXME very bad method name
    def ids(ids)
      return [] if ids.blank?
      logger.debug "Fetching request list from api"
      ret = []
      ids.each_slice(50) do |a|
        ret.concat(ApiDetails.read(:requests, ids: a))
      end
      return ret
    end

    def prepare_list_path(path, opts)
      unless opts[:states] or opts[:reviewstate] or opts[:roles] or opts[:types] or opts[:user] or opts[:project]
        raise RuntimeError, 'missing parameters'
      end
      
      opts.delete(:types) if opts[:types] == 'all' # All types means don't pass 'type' to backend
      
      query = []
      query << "states=#{CGI.escape(opts[:states])}" unless opts[:states].blank?
      query << "roles=#{CGI.escape(opts[:roles])}" unless opts[:roles].blank?
      query << "reviewstates=#{CGI.escape(opts[:reviewstates])}" unless opts[:reviewstates].blank?
      query << "types=#{CGI.escape(opts[:types])}" unless opts[:types].blank? # the API want's to have it that way, sigh...
      query << "user=#{CGI.escape(opts[:user])}" unless opts[:user].blank?
      query << "project=#{CGI.escape(opts[:project])}" unless opts[:project].blank?
      query << "package=#{CGI.escape(opts[:package])}" unless opts[:package].blank?
      query << 'subprojects=1' if opts[:subprojects]
      return path + '?' + query.join('&')
    end
    
    def list_ids(opts)
       # All types means don't pass 'type' to backend
      if opts[:types] == 'all' || (opts[:types].respond_to?(:include?) && opts[:types].include?('all'))
        opts.delete(:types)
      end
      ApiDetails.read(:ids_requests, opts)
    end

    def list(opts)
      path = prepare_list_path('/request?view=collection', opts)
      begin
        logger.debug 'Fetching request list from api'
        response = ActiveXML::transport.direct_http URI("#{path}"), :method => 'GET'
        return Collection.new(response).each # last statement, implicit return value of block, assigned to 'request_list' non-local variable
      rescue ActiveXML::Transport::Error => e
        raise ListError, e.summary
      end
    end
  
  end

  def history
    ret = []
    self.each_history do |h|
      ret << { :who => h.who, :when => Time.parse(h.when), :name => h.name, :comment => h.value(:comment) }
    end if self.has_element?(:history)
    h = self.state
    ret << { :who => h.who, :when => Time.parse(h.when), :name => h.name, :comment => h.value(:comment) }
    return ret
  end

  def reviewer_for_history_item(item)
    reviewer = ''
    if item.by_group
      reviewer = item.value('by_group')
    elsif item.by_project
      reviewer = item.value('by_project')
    elsif item.by_package
      reviewer = item.value('by_package')
    elsif item.by_user
      reviewer = item.value('by_user')
    end
    return reviewer
  end

  # return the login of the creator - to be obsoleted soon (FIXME2.4)
  def creator
    details = ApiDetails.read(:request, self.id)
    return details['creator']
  end
end
