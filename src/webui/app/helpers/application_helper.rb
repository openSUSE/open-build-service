require 'md5'

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  def logged_in?
    !session[:login].nil?
  end
  
  def user
    if logged_in?
      begin
        @user ||= Person.find_cached( :login => session[:login] )
      rescue Object => e
        logger.error "Cannot load person data for #{session[:login]} in application_helper"
      end
    end
    return @user
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
    sponsors = ["common/sponsors/sponsor_amd.png",
      "common/sponsors/sponsor_b1-systems.png",
      "common/sponsors/sponsor_ip-exchange2.png"]
    return sponsors[rand(sponsors.size)]
  end


  def link_to_remote_if(condition, name, options = {}, html_options = nil, &block)
    if condition
      link_to_remote(name, options, html_options)
    else
      if block_given?
        block.arity <= 1 ? yield(name) : yield(name, options, html_options)
      else
        name
      end
    end
  end

  def image_url(source)
    abs_path = image_path(source)
    unless abs_path =~ /^http/
      abs_path = "#{request.protocol}#{request.host_with_port}#{abs_path}"
    end
    abs_path
  end

  def gravatar_image(email)
    hash = MD5::md5(email.downcase)
    return image_tag "https://secure.gravatar.com/avatar/#{hash}?s=20&d=" + image_url('local/default_face.png'), :alt => '', :width => 20, :height => 20
  end

  def rewrite_asset_path(source)
    if CONFIG['theme']
      new_path = "/vendor/#{CONFIG['theme']}#{source}"
      if File.exists?("#{RAILS_ROOT}/public#{new_path}")
        Rails.logger.debug "using themed file: #{new_path}"
        source=new_path
      end
    end
    super(source)
  end

  def fuzzy_time_string(time)
    diff = Time.now - Time.parse(time)
    return "now" if diff < 60
    return (diff/60).to_i.to_s + " min ago" if diff < 3600
    return (diff/3600).to_i.to_s + ((diff/3600).to_i == 1 ? " hour ago" : " hours ago") if diff < 86400
    return (diff/86400).to_i.to_s + ((diff/86400).to_i == 1 ? " day ago" : " days ago")
  end

  def setup_buildresult_trigger
    content_for :ready_function do 
      "setup_buildresult_trigger();"
    end
  end

  def package_link(project, package)
    out = "<span class='build_result_trigger'>"
    out += link_to 'br', { :controller => :project, :action => :package_buildresult, :project => project, :package => package }, { :class => "hidden build_result" }
    out += link_to project, :controller => :project, :action => "show", :project => project
    out += " / " +  link_to(package, :controller => :package, :action => "show", :project => project, :package => package)
    out += "</span>"
  end

  def status_for( repo, arch, package )
    @statushash[repo][arch][package] || ActiveXML::XMLNode.new("<status package='#{package}'/>")
  end

  def status_id_for( repo, arch, package )
    h "#{package}_#{repo}_#{arch}"
  end

  def arch_repo_table_cell(repo, arch, packname)
    status = status_for(repo, arch, packname)
    status_id = status_id_for( repo, arch, packname)
    link_title = status.has_element?(:details) ? status.details.to_s : nil
    if status.has_attribute? 'code'
      code = status.code.to_s
      theclass="status_" + code.gsub(/[- ]/,'_')
    else
      code = ''
      theclass=''
    end
    
    out = "<td id='#{status_id}' class='#{theclass} buildstatus'>"
    if ["expansion error", "broken", "blocked"].include? code 
      out += link_to code.gsub("expansion error", "exp. error"), "javascript:alert('#{link_title}')", :title => link_title
    elsif ["-","excluded"].include? code
      out += code
    else
      out += link_to code.gsub(/\s/, "&nbsp;"), {:action => :live_build_log,
        :package => packname, :project => @project.to_s, :arch => arch,
        :controller => "package", :repository => repo}, {:title => link_title}
    end 
    return out + "</td>"
  end

end
