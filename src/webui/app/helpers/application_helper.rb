# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  def logged_in?
    !session[:login].nil?
  end
  
  def user
    u = nil
    if logged_in?
      u = Person.find :login => session[:login]
    end
    return u
  end

  def link_to_home_project
    link_to "Home Project", :controller => "project", :action => "show", 
      :project => "home:" + session[:login]
  end

  def link_to_project project
    link_to project, :controller => "project", :action => :show,
      :project => project
  end

  def link_to_package project, package
    link_to package, :controller => "package", :action => :show,
      :project => project, :package => package
  end

  def repo_url(project, repo='' )
    "#{DOWNLOAD_URL}/" + project.to_s.gsub(/:/,':/') + "/#{repo}"
  end


  def shorten_text( text, length=15 )
    text = text[0..length-1] + '...' if text.length > length
    return text
  end


  def focus_id( id )
    javascript_tag(
      "document.getElementById('#{id}').focus();"
    )
  end


  def focus_and_select_id( id )
    javascript_tag(
      "document.getElementById('#{id}').focus();" +
        "document.getElementById('#{id}').select();"
    )
  end


  def get_frontend_url_for( opt={} )
    opt[:host] ||= Object.const_defined?(:EXTERNAL_FRONTEND_HOST) ? EXTERNAL_FRONTEND_HOST : FRONTEND_HOST
    opt[:port] ||= Object.const_defined?(:EXTERNAL_FRONTEND_PORT) ? EXTERNAL_FRONTEND_PORT : FRONTEND_PORT
    opt[:protocol] ||= FRONTEND_PROTOCOL

    if not opt[:controller]
      logger.error "No controller given for get_frontend_url_for()."
      return
    end

    return "#{opt[:protocol]}://#{opt[:host]}:#{opt[:port]}/#{opt[:controller]}"
  end


  def min_votes_for_rating
    MIN_VOTES_FOR_RATING
  end

  def bugzilla_url(email, desc="")
    "#{BUGZILLA_HOST}/enter_bug.cgi?classification=7340&product=openSUSE.org&component=3rd%20party%20software&assigned_to=#{email}&short_desc=#{desc}"
  end

  
  def hinted_text_field_tag(name, value = nil, hint = "Click and enter text", options={})
    value = value.nil? ? hint : value
    text_field_tag name, value, {:onfocus => "if($(this).value == '#{hint}'){$(this).value = ''}",
                       :onblur => "if($(this).value == ''){$(this).value = '#{hint}'}",
                           }.update(options.stringify_keys)
  end


  def get_random_sponsor_image
    sponsors = ["http://files.opensuse.org/opensuse/en/5/54/Amd.png",
                "http://files.opensuse.org/opensuse/en/b/b6/Ip-exchange.gif",
                "http://files.opensuse.org/opensuse/en/f/fc/B1-systems.jpg"]
    return sponsors[rand(sponsors.size)]
  end

end
