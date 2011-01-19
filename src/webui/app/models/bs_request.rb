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
          opt[:targetproject] = opt[:project] if !opt.has_key? :targetproject or opt[:targetproject].nil?
          opt[:targetpackage] = opt[:package] if !opt.has_key? :targetpackage or opt[:targetpackage].nil?
          reply = <<-EOF
            <request>
              <action type="submit">
                <source project="#{opt[:project].to_xs}" package="#{opt[:package].to_xs}" rev="#{opt[:rev]}"/>
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
      unless (opts[:state] or opts[:type]) and (opts[:user] or opts[:project] and (opts[:package] or 1)) # boolean algebra rocks!
        raise RuntimeError, "missing parameters"
      end

      predicate = ""
      case opts[:state].to_s
        when "pending" then    predicate += "(state/@name='new' or state/@name='review') and "
        when "new" then        predicate += "state/@name='new' and "
        when "deleted" then    predicate += "state/@name='deleted' and "
        when "declined" then   predicate += "state/@name='declined' and "
        when "accepted" then   predicate += "state/@name='accepted' and "
        when "review" then     predicate += "state/@name='review' and "
        when "revoked"  then   predicate += "state/@name='revoked' and "
        when "superseded" then predicate += "state/@name='superseded' and "
      end

      # Filter by request type (submit, delete, ...)
      predicate += "action/@type='#{opts[:type]}' and " if opts[:type]

      if opts[:project] and not opts[:project].empty?
        if opts[:package] and not opts[:package].empty?
          predicate += "action/target/@project='#{opts[:project]}' and action/target/@package='#{opts[:package]}'"
        else
          predicate += "action/target/@project='#{opts[:project]}'"
        end
      elsif opts[:user] # should be set in almost all cases
        # user's own submitted requests
        predicate += "(state/@who='#{opts[:user]}'"
        # requests where the user is reviewer or own requests that are in review by someone else
        predicate += " or review[@by_user='#{opts[:user]}' and @state='new'] or history[@who='#{opts[:user]}' and position() = 1]" if opts[:state] == "pending" or opts[:state] == "review"
        # find requests where user is maintainer in target project
        maintained_projects = Array.new
        coll = Collection.find_cached(:id, :what => 'project', :predicate => "person/@userid='#{opts[:user]}'")
        coll.each {|mp| maintained_projects += ["action/target/@project='#{mp.name}'"]}
        predicate += " or (" + maintained_projects.join(" or ") + ")" unless maintained_projects.empty?
        # find request where user is maintainer in target package
        maintained_packages = Array.new
        maintained_projects_hash = Hash.new
        coll.each {|prj| maintained_projects_hash[prj.name] = true}
        coll = Collection.find(:id, :what => 'package', :predicate => "person/@userid='#{opts[:user]}'")
        coll.each do |mp|
          maintained_packages += ["(action/target/@project='#{mp.project}' and action/target/@package='#{mp.name}')"] unless maintained_projects_hash.has_key?(mp.project.to_s)
        end
        predicate += " or (" + maintained_packages.join(" or ") + ")" unless maintained_packages.empty?
        predicate += ")"
      end

      return Collection.find_cached(:what => :request, :predicate => predicate).each
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
