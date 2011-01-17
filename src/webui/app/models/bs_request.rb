class BsRequest < ActiveXML::Base

  class ModifyError < Exception; end

  default_find_parameter :id

  class << self
    def make_stub(opt)
      opt[:description] = "" if !opt.has_key? :description or opt[:description].nil?
      
      ret = nil
      case opt[:type]
        when "submit" then
          option = ""
          option = "<options><sourceupdate>#{opt[:sourceupdate]}</sourceupdate></options>" if opt[:sourceupdate]
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
        when "delete" then
          pkg_option = ""
          pkg_option = "package=\"#{opt[:targetpackage].to_xs}\"" if opt.has_key? :targetpackage and not opt[:targetpackage].nil?
          reply = <<-EOF
            <request>
              <action type="delete">
                <target project="#{opt[:targetproject].to_xs}" #{pkg_option}/>
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

    def find_open_review_requests(user)
      unless user
        raise RuntimeError, "missing parameters"
      end
      pred = "state/@name='review' and review/@state='new' and review/@by_user='#{user}'"
      requests = Collection.find_cached :what => :request, :predicate => pred
      return requests
    end

    def list(opts)
      unless opts[:type] and opts[:user] or opts[:project] and (opts[:package] or 1) # boolean algebra rocks!
        raise RuntimeError, "missing parameters"
      end

      predicate = ""
      case opts[:type]
        when "pending" then    predicate += "(state/@name='new' or state/@name='review')"
        when "new" then        predicate += "state/@name='new'"
        when "deleted" then    predicate += "state/@name='deleted'"
        when "declined" then   predicate += "state/@name='declined'"
        when "accepted" then   predicate += "state/@name='accepted'"
        when "review" then     predicate += "state/@name='review'"
        when "revoked"  then   predicate += "state/@name='revoked'"
        when "superseded" then predicate += "state/@name='superseded'"
        else                   predicate += "(state/@name='new' or state/@name='review')"
      end

      if opts[:project] and not opts[:project].empty?
        if opts[:package] and not opts[:package].empty?
          predicate += " and action/target/@project='#{opts[:project]}' and action/target/@package='#{opts[:package]}'"
        else
          predicate += " and action/target/@project='#{opts[:project]}'"
        end
      elsif opts[:user] # should be set in almost all cases
        # user's own submitted requests
        predicate += " and (state/@who='#{opts[:user]}'"
        # requests where the user is reviewer
        predicate += " or review[@by_user='#{opts[:user]}' and @state='new']" if opts[:type] == "pending" or opts[:type] == "review"
        # find requests where person is maintainer in target project
        pending_projects = Array.new
        ip_coll = Collection.find_cached(:id, :what => 'project', :predicate => "person/@userid='#{opts[:user]}'")
        ip_coll.each {|ip| pending_projects += ["action/target/@project='#{ip.name}'"]}
        predicate += " or (" + pending_projects.join(" or ") + ")" unless pending_projects.empty?
        predicate += ")"
      end

      logger.debug "PREDICATE: " + predicate
      requests = Collection.find_cached :what => :request, :predicate => predicate
      return [] if requests.each.blank? # same behavior as Person#involved_requests
      return requests
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
