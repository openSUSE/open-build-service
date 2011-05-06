class BsRequest < ActiveXML::Base

  class ListError < Exception; end
  class ModifyError < Exception; end

  default_find_parameter :id

  class << self
    def make_stub(opt)
      option = source_package = target_package = ""
      opt[:description] = "" if !opt.has_key? :description or opt[:description].nil?
      target_package = "package=\"#{opt[:targetpackage].to_xs}\"" if opt[:targetpackage] and not opt[:targetpackage].empty?

      # set request-specific options
      case opt[:type]
        when "submit" then
          # set target package is the same as the source package if no target package is specified
          target_package = "package=\"#{opt[:package].to_xs}\"" if target_package.blank?
          revision_option = "rev=\"#{opt[:rev].to_xs}\"" unless opt[:rev].blank?
          option = "<source project=\"#{opt[:project]}\" package=\"#{opt[:package]}\" #{revision_option}/>"
          option += "<options><sourceupdate>#{opt[:sourceupdate]}</sourceupdate></options>" unless opt[:sourceupdate].blank?
        when "add_role" then
          option = "<group name=\"#{opt[:group]}\" role=\"#{opt[:role]}\"/>" unless opt[:group].blank?
          option = "<person name=\"#{opt[:person]}\" role=\"#{opt[:role]}\"/>" unless opt[:person].blank?
        when "set_bugowner" then
          option = "<person name=\"#{opt[:person]}\" role=\"#{opt[:role]}\"/>"
        when "change_devel" then
          option = "<source project=\"#{opt[:project]}\" package=\"#{opt[:package]}\"/>"
        when "maintenance_incident" then
          option = "<source project=\"#{opt[:project]}\"/>"
        when "maintenance_release" then
          option = "<source project=\"#{opt[:project]}\"/>"
      end
      # build the request XML
      reply = <<-EOF
        <request>
          <action type="#{opt[:type]}">
            #{option}
            <target project="#{opt[:targetproject].to_xs}" #{target_package}/>
          </action>
          <state name="new"/>
          <description>#{opt[:description].to_xs}</description>
        </request>
      EOF
      return XML::Parser.string(reply).parse.root
    end

    def addReview(id, opts)
      opts = {:user => nil, :group => nil, :project => nil, :package => nil, :comment => nil}.merge opts

      transport ||= ActiveXML::Config::transport_for :bsrequest
      path = "/request/#{id}?cmd=addreview"
      path << "&by_user=#{CGI.escape(opts[:user])}" if opts[:user]
      path << "&by_group=#{CGI.escape(opts[:group])}" if opts[:group]
      path << "&by_project=#{CGI.escape(opts[:project])}" if opts[:project]
      path << "&by_package=#{CGI.escape(opts[:package])}" if opts[:package]
      begin
        r = transport.direct_http URI("#{path}"), :method => "POST", :data => opts[:comment]
        BsRequest.free_cache(id)
        # FIXME add a full error handler here
        return true
      rescue ActiveXML::Transport::ForbiddenError => e
        message, _, _ = ActiveXML::Transport.extract_error_message e
        raise ModifyError, message
      rescue ActiveXML::Transport::NotFoundError => e
        message, _, _ = ActiveXML::Transport.extract_error_message e
        raise ModifyError, message
      end
    end

    def modifyReview(id, changestate, opts)
      unless (changestate=="accepted" || changestate=="declined")
        raise ModifyError, "unknown changestate #{changestate}"
      end

      transport ||= ActiveXML::Config::transport_for :bsrequest
      path = "/request/#{id}?newstate=#{changestate}&cmd=changereviewstate"
      path << "&by_user=#{CGI.escape(opts[:user])}" if opts[:user]
      path << "&by_group=#{CGI.escape(opts[:group])}" if opts[:group]
      path << "&by_project=#{CGI.escape(opts[:project])}" if opts[:project]
      path << "&by_package=#{CGI.escape(opts[:package])}" if opts[:package]
      begin
        transport.direct_http URI("#{path}"), :method => "POST", :data => opts[:comment]
        BsRequest.free_cache(id)
        return true
      rescue ActiveXML::Transport::ForbiddenError => e
        message, _, _ = ActiveXML::Transport.extract_error_message e
        raise ModifyError, message
      rescue ActiveXML::Transport::NotFoundError => e
        message, _, _ = ActiveXML::Transport.extract_error_message e
        raise ModifyError, message
      end
    end

    def modify(id, changestate, opts)
      opts = {:superseded_by => nil, :force => false, :reason => ''}.merge opts
      if ["accepted", "declined", "revoked", "superseded"].include?(changestate)
        transport ||= ActiveXML::Config::transport_for :bsrequest
        path = "/request/#{id}?newstate=#{changestate}&cmd=changestate"
        path += "&superseded_by=#{opts[:superseded_by]}" if opts[:superseded_by]
        path += "&force=1" if opts[:force]
        begin
          transport.direct_http URI("#{path}"), :method => "POST", :data => opts[:reason].to_s
          BsRequest.free_cache(id)
          return true
        rescue ActiveXML::Transport::ForbiddenError => e
          message, _, _ = ActiveXML::Transport.extract_error_message e
          raise ModifyError, message
        rescue ActiveXML::Transport::NotFoundError => e
          message, _, _ = ActiveXML::Transport.extract_error_message e
          raise ModifyError, message
        end
      end
      raise ModifyError, "unknown changestate #{changestate}"
    end

    def find_last_request(opts)
      unless opts[:targetpackage] and opts[:targetproject] and opts[:sourceproject] and opts[:sourcepackage]
        raise RuntimeError, "missing parameters"
      end
      pred = "(action/target/@package='#{opts[:targetpackage]}' and action/target/@project='#{opts[:targetproject]}' and action/source/@project='#{opts[:sourceproject]}' and action/source/@package='#{opts[:sourcepackage]}' and action/@type='submit')"
      requests = Collection.find_cached :what => :request, :predicate => pred
      last = nil
      requests.each_request do |r|
        last = r if not last or Integer(r.data[:id]) > Integer(last.data[:id])
      end
      return last
    end

    def list(opts)
      unless opts[:states] or opts[:reviewstate] or opts[:roles] or opts[:types] or (opts[:user] or opts[:project] and (opts[:package] or 1)) # boolean algebra rocks!
        raise RuntimeError, "missing parameters"
      end

      opts.delete(:types) if opts[:types] == 'all' # All types means don't pass 'type' to backend

      transport ||= ActiveXML::Config::transport_for :bsrequest
      path = "/request?view=collection"
      path << "&states=#{CGI.escape(opts[:states])}" if opts[:states]
      path << "&roles=#{CGI.escape(opts[:roles])}" if opts[:roles]
      path << "&reviewstates=#{CGI.escape(opts[:reviewstates])}" if opts[:reviewstates]
      path << "&types=#{CGI.escape(opts[:types])}" if opts[:types] # the API want's to have it that way, sigh...
      path << "&user=#{CGI.escape(opts[:user])}" if opts[:user]
      path << "&project=#{CGI.escape(opts[:project])}" if opts[:project]
      path << "&package=#{CGI.escape(opts[:package])}" if opts[:package]
      begin
        logger.debug "Fetching request list from api"
        response = transport.direct_http URI("#{path}"), :method => "GET"
        return Collection.new(response).each # last statement, implicit return value of block, assigned to 'request_list' non-local variable
      rescue ActiveXML::Transport::Error => e
        message, _, _ = ActiveXML::Transport.extract_error_message e
        raise ListError, message
      end
    end

    def creator(req)
      if req.has_element?(:history)
        #NOTE: 'req' can be a LibXMLNode or not. Depends on code path. Also depends on luck and random quantum effects. ActiveXML sucks big time!
        return req.history.who if req.history.class == ActiveXML::LibXMLNode
        return req.history[0][:who]
      else
        return req.state.who
      end
    end

    def created_at(req)
      if req.has_element?(:history)
        #NOTE: 'req' can be a LibXMLNode or not. Depends on code path. Also depends on luck and random quantum effects. ActiveXML sucks big time!
        return req.history.when if req.history.class == ActiveXML::LibXMLNode
        return req.history[0][:when]
      else
        return req.state.when
      end
    end
  end

  def creator
    return BsRequest.creator(self)
  end

  def created_at
    return BsRequest.created_at(self)
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

end
