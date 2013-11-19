class WebuiRequest < ActiveXML::Node

  def self.transport
    ActiveXML::api
  end

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
        ActiveXML::api.direct_http URI("#{path}"), :method => "POST", :data => opts[:comment]
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
        ActiveXML::api.direct_http URI("#{path}"), :method => "POST", :data => opts[:comment]
        return true
      rescue ActiveXML::Transport::Error => e
        raise ModifyError, e.summary
      end
    end

    def modify(id, changestate, opts)
      opts = {:superseded_by => nil, :force => false, :reason => ''}.merge opts
      unless %w(accepted declined revoked superseded new).include?(changestate)
        raise ModifyError, "unknown changestate #{changestate}"
      end
      path = "/request/#{id}?newstate=#{changestate}&cmd=changestate"
      path += "&superseded_by=#{opts[:superseded_by]}" unless opts[:superseded_by].blank?
      path += "&force=1" if opts[:force]
      begin
        ActiveXML::api.direct_http URI("#{path}"), :method => "POST", :data => opts[:reason].to_s
        return true
      rescue ActiveXML::Transport::Error => e
        raise ModifyError, e.summary
      end
    end

    def set_incident(id, incident_project)
      begin
        path = "/request/#{id}?cmd=setincident&incident=#{incident_project}"
        ActiveXML::api.direct_http URI(path), :method => "POST", :data => ''
        return true
      rescue ActiveXML::Transport::Error => e
        raise ModifyError, e.summary
      end
      raise ModifyError, "Unable to merge with incident #{incident_project}"
    end

  end

  def id
    value(:id).to_i
  end

  def api_obj
    @api_obj ||= BsRequest.find self.id
  end
end
