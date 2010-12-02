class BsRequest < ActiveXML::Base

  class ModifyError < Exception; end

  default_find_parameter :id

  class << self
    def make_stub( opt )
      text = ""
      if opt.has_key? :description
        text = opt[:description]
      end
      
      ret = nil

      # TODO: this is function is a joke as it requires all options for a submit request
      # it should be more generic
      option = ""
      option = "<options><sourceupdate>#{opt[:sourceupdate]}</sourceupdate></options>" if opt[:sourceupdate]
      target_package_option = ""
      target_package_option = "package=\"#{opt[:targetpackage].to_xs}\"" if opt[:targetpackage]
      if opt[:type] == "submit" 
        reply = <<-ENDE
          <request type="submit">
            <submit>
              <source project="#{opt[:project].to_xs}" package="#{opt[:package].to_xs}"/>
              <target project="#{opt[:targetproject].to_xs}" #{target_package_option}/>
              #{option}
            </submit>
            <state name="new"/>
            <description>#{text.to_xs}</description>
          </request>
        ENDE
        ret = XML::Parser.string(reply).parse.root
        ret.find_first("//source")["rev"] = opt[:rev] if opt[:rev]
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
  end

end
