class Request < ActiveXML::Base

  class ModifyError < Exception; end

  default_find_parameter :id

  def self.make_stub( opt )
    text = ""
    if opt.has_key? :description
      text = opt[:description]
    end
    
    ret = nil

    # TODO: this is function is a joke as it requires all options for a submit request
    # it should be more generic
    if opt[:type] == "submit" 
      reply = <<-ENDE
        <request type="submit">
          <submit>
	    <source project="#{opt[:project].to_xs}" package="#{opt[:package].to_xs}"/>
            <target project="#{opt[:targetproject].to_xs}" package="#{opt[:targetpackage].to_xs}"/>
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

  def self.addReviewByGroup(id, group)
    addReview(id, nil, group)
  end
  def self.addReviewByUser(id, user)
    addReview(id, user)
  end
  def self.addReview(id, user=nil, group=nil)
    transport = ActiveXML::Config::transport_for(:request)
    path = "/request/#{id}?cmd=addreview"
    if user
      path << "&by_user=#{CGI.escape(user)}"
    end
    if group
      path << "&by_group=#{CGI.escape(group)}"
    end
    begin
      r = transport.direct_http URI("https://#{path}"), :method => "POST"
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

  def self.modifyReviewByGroup(id, changestate, comment, group)
    modifyReview(id, changestate, comment, nil, group)
  end
  def self.modifyReviewByUser(id, changestate, comment, user)
    modifyReview(id, changestate, comment, user)
  end
  def self.modifyReview(id, changestate, comment, user=nil, group=nil)
    unless (changestate=="accepted" || changestate=="declined")
      raise ModifyError, "unknown changestate #{changestate}"
    end

    transport = ActiveXML::Config::transport_for(:request)
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

  def self.modify(id, changestate, reason)
    if (changestate=="accepted" || changestate=="declined" || changestate=="revoked")
      transport = ActiveXML::Config::transport_for(:request)
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

  def self.find_last_request(opts)
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

  def self.find_open_review_requests(user)
    unless user
      raise RuntimeError, "missing parameters"
    end
    pred = "state/@name='review' and review/@state='new' and review/@by_user='#{user}'"
    requests = Collection.find_cached :what => :request, :predicate => pred
    return requests
  end

end
