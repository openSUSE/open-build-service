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

    def addReviewByGroup(id, group, comment = nil)
      addReview(id, nil, group, comment)
    end
    def addReviewByUser(id, user, comment = nil)
      addReview(id, user, nil, comment)
    end
    def addReview(id, user=nil, group=nil, comment = nil)
      transport ||= ActiveXML::Config::transport_for :bsrequest
      path = "/request/#{id}?cmd=addreview"
      if user
        path << "&by_user=#{CGI.escape(user)}"
      end
      if group
        path << "&by_group=#{CGI.escape(group)}"
      end
      begin
        r = transport.direct_http URI("https://#{path}"), :method => "POST", :data => comment
        # FIXME add a full error handler here
        return true
      rescue ActiveXML::Transport::ForbiddenError => e
        message, code, api_exception = ActiveXML::Transport.extract_error_message e
        raise ModifyError, message
      rescue ActiveXML::Transport::NotFoundError => e
        message, code, api_exception = ActiveXML::Transport.extract_error_message e
        raise ModifyError, message
      end
    end

    def modifyReviewByGroup(id, changestate, comment, group)
      modifyReview(id, changestate, comment, nil, group)
    end
    def modifyReviewByUser(id, changestate, comment, user)
      modifyReview(id, changestate, comment, user)
    end
    def modifyReview(id, changestate, comment, user=nil, group=nil)
      unless (changestate=="accepted" || changestate=="declined")
        raise ModifyError, "unknown changestate #{changestate}"
      end

      transport ||= ActiveXML::Config::transport_for :bsrequest
      path = "/request/#{id}?newstate=#{changestate}&cmd=changereviewstate"
      if user
        path << "&by_user=#{CGI.escape(user)}"
      end
      if group
        path << "&by_group=#{CGI.escape(group)}"
      end
      begin
        transport.direct_http URI("https://#{path}"), :method => "POST", :data => comment.to_s
        return true
      rescue ActiveXML::Transport::ForbiddenError => e
        message, code, api_exception = ActiveXML::Transport.extract_error_message e
        raise ModifyError, message
      rescue ActiveXML::Transport::NotFoundError => e
        message, code, api_exception = ActiveXML::Transport.extract_error_message e
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
          message, code, api_exception = ActiveXML::Transport.extract_error_message e
          raise ModifyError, message
        rescue ActiveXML::Transport::NotFoundError => e
          message, code, api_exception = ActiveXML::Transport.extract_error_message e
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
      last=nil
      requests.each_request do |r|
        if not last or Integer(r.data[:id]) > Integer(last.data[:id])
          last=r
        end
      end
      return last
    end

    def list(opts)
      unless opts[:state] or opts[:type] or (opts[:user] or opts[:project] and (opts[:package] or 1)) # boolean algebra rocks!
        raise RuntimeError, "missing parameters"
      end

      # try to find request list in cache first before asking the OBS API
      request_list = Rails.cache.fetch("request_list:#{opts.to_s}", :expires_in => 10.minutes) do
        transport ||= ActiveXML::Config::transport_for :bsrequest
        path = "/request?view=collection"
        path << "&state=#{opts[:state]}" if opts[:state]
        path << "&type=#{opts[:type]}" if opts[:type]
        path << "&user=#{opts[:user]}" if opts[:user]
        path << "&project=#{opts[:project]}" if opts[:project]
        path << "&package=#{opts[:package]}" if opts[:package]
        begin
          logger.debug "Fetching request list from api"
          response = transport.direct_http URI("https://#{path}"), :method => "GET"
          Collection.new(response).each # last statement, implicit return value of block, assigned to 'request_list' non-local variable
        rescue ActiveXML::Transport::Error => e
          message, code, api_exception = ActiveXML::Transport.extract_error_message e
          raise ListError, message
        end
      end
      return request_list
    end
  end

  def creator
    if self.has_element?(:history)
      e = self.history('@name="new"')
    else
      e = self.state
    end
    return "unknown" if e.nil?
    return e.value(:who)
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
