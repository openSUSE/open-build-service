class BsRequest < ActiveXML::Base

  class ListError < Exception; end
  class ModifyError < Exception; end

  default_find_parameter :id

  class << self
    def make_stub(opt)
      opt[:description] = "" if !opt.has_key? :description or opt[:description].nil?

      ret = nil
      if opt[:type] == "submit" then
        option = ""
        option = "<options><sourceupdate>#{opt[:sourceupdate]}</sourceupdate></options>" if opt[:sourceupdate]
        opt[:targetproject] = opt[:project] if !opt.has_key? :targetproject or opt[:targetproject].nil?
        opt[:targetpackage] = opt[:package] if !opt.has_key? :targetpackage or opt[:targetpackage].nil?
        reply = <<-EOF
          <request>
            <action type="submit">
              <source project="#{opt[:project].to_xs}" package="#{opt[:package].to_xs}"/>
              <target project="#{opt[:targetproject].to_xs}" package="#{opt[:targetpackage].to_xs}"/>
              #{option}
            </action>
            <state name="new"/>
            <description>#{opt[:description].to_xs}</description>
          </request>
        EOF
        ret = XML::Parser.string(reply).parse.root
        ret.find_first("//source")["rev"] = opt[:rev] if opt[:rev]
      else
        # set request-specific options
        option = ""
        case opt[:type]
          when "add_role" then
            option = "<group name=\"#{opt[:group]}\" role=\"#{opt[:role]}\"/>" if opt.has_key? :group and not opt[:group].nil?
            option = "<person name=\"#{opt[:person]}\" role=\"#{opt[:role]}\"/>" if opt.has_key? :person and not opt[:person].nil?
          when "set_bugowner" then
            option = "<person name=\"#{opt[:person]}\" role=\"#{opt[:role]}\"/>"
          when "change_devel" then
            option = "<source project=\"#{opt[:project]}\" package=\"#{opt[:package]}\"/>"
        end
        # build the request XML
        pkg_option = ""
        pkg_option = "package=\"#{opt[:targetpackage].to_xs}\"" if opt.has_key? :targetpackage and not opt[:targetpackage].nil?
        reply = <<-EOF
          <request>
            <action type="#{opt[:type]}">
              <target project="#{opt[:targetproject].to_xs}" #{pkg_option}/>
              #{option}
            </action>
            <state name="new"/>
            <description>#{opt[:description].to_xs}</description>
          </request>
        EOF
        ret = XML::Parser.string(reply).parse.root
      end
      return ret
    end

    def addReview(id, opts)
      {:user => nil, :group => nil, :project => nil, :package => nil, :comment => nil}.merge opts

      transport ||= ActiveXML::Config::transport_for :bsrequest
      path = "/request/#{id}?cmd=addreview"
      path << "&by_user=#{CGI.escape(opts[:user])}" if opts[:user]
      path << "&by_group=#{CGI.escape(opts[:group])}" if opts[:group]
      path << "&by_project=#{CGI.escape(opts[:project])}" if opts[:project]
      path << "&by_package=#{CGI.escape(opts[:package])}" if opts[:package]
      begin
        r = transport.direct_http URI("https://#{path}"), :method => "POST", :data => opts[:comment]
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
      {:user => nil, :group => nil, :project => nil, :package => nil, :comment => nil}.merge opts
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
        transport.direct_http URI("https://#{path}"), :method => "POST", :data => opts[:comment]
        return true
      rescue ActiveXML::Transport::ForbiddenError => e
        message, _, _ = ActiveXML::Transport.extract_error_message e
        raise ModifyError, message
      rescue ActiveXML::Transport::NotFoundError => e
        message, _, _ = ActiveXML::Transport.extract_error_message e
        raise ModifyError, message
      end
    end

    def modify(id, changestate, reason)
      if (changestate=="accepted" || changestate=="declined" || changestate=="revoked")
        transport ||= ActiveXML::Config::transport_for :bsrequest
        path = "/request/#{id}?newstate=#{changestate}&cmd=changestate"
        begin
          transport.direct_http URI("https://#{path}"), :method => "POST", :data => reason.to_s
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
      unless opts[:state] or opts[:type] or (opts[:user] or opts[:project] and (opts[:package] or 1)) # boolean algebra rocks!
        raise RuntimeError, "missing parameters"
      end

      opts.delete(:type) if opts[:type] == 'all' # All types means don't pass 'type' to backend

      transport ||= ActiveXML::Config::transport_for :bsrequest
      path = "/request?view=collection"
      path << "&state=#{CGI.escape(opts[:state])}" if opts[:state]
      path << "&action_type=#{CGI.escape(opts[:type])}" if opts[:type] # the API want's to have it that way, sigh...
      path << "&user=#{CGI.escape(opts[:user])}" if opts[:user]
      path << "&project=#{CGI.escape(opts[:project])}" if opts[:project]
      path << "&package=#{CGI.escape(opts[:package])}" if opts[:package]
      begin
        logger.debug "Fetching request list from api"
        response = transport.direct_http URI("https://#{path}"), :method => "GET"
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
