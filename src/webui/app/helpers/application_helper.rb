require 'md5'

require 'action_view/helpers/asset_tag_helper.rb'
module ActionView
  module Helpers

    @@rails_root = nil
    def real_public
      return @@rails_root if @@rails_root
      @@rails_root = Pathname.new("#{RAILS_ROOT}/public").realpath
    end

    @@icon_cache = Hash.new
    
    def rewrite_asset_path(_source)
      if @@icon_cache[_source]
        return @@icon_cache[_source]
      end
      new_path = "/vendor/#{CONFIG['theme']}#{_source}"
      if File.exists?("#{RAILS_ROOT}/public#{new_path}")
        source = new_path
      elsif File.exists?("#{RAILS_ROOT}/public#{_source}")
        source = _source
      else
        return super(_source)
      end
      source=Pathname.new("#{RAILS_ROOT}/public#{source}").realpath
      source="/" + Pathname.new(source).relative_path_from(real_public)
      Rails.logger.debug "using themed file: #{_source} -> #{source}"
      source = super(source)
      @@icon_cache[_source] = source
    end

    def compute_asset_host(source)
      if CONFIG['use_static'] 
        if ActionController::Base.relative_url_root
          source = source.slice(ActionController::Base.relative_url_root.length..-1)
        end
        if source =~ %r{^/themes}
          return "https://static.opensuse.org"
        elsif source =~ %r{^/images} or source =~ %r{^/javascripts} or source =~ %r{^/stylesheets}
          return "https://static.opensuse.org/hosts/#{CONFIG['use_static']}"
        end
      end
      super(source)
    end

  end
end

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  def logged_in?
    !session[:login].nil?
  end
  
  def user
    if logged_in?
      begin
        @user ||= find_cached(Person, session[:login] )
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
    if defined? DOWNLOAD_URL
      "#{DOWNLOAD_URL}/" + project.to_s.gsub(/:/,':/') + "/#{repo}"
    else
      nil
    end
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

  def bugzilla_url(email, desc="")
    URI.escape("#{BUGZILLA_HOST}/enter_bug.cgi?classification=7340&product=openSUSE.org&component=3rd party software&assigned_to=#{email}&short_desc=#{desc}")
  end

  
  def hinted_text_field_tag(name, value = nil, hint = "Click and enter text", options={})
    value = value.nil? ? hint : value
    text_field_tag name, value, {:onfocus => "if($(this).value == '#{hint}'){$(this).value = ''}",
      :onblur => "if($(this).value == ''){$(this).value = '#{hint}'}",
    }.update(options.stringify_keys)
  end


  def get_random_sponsor_image
    sponsors = ["/themes/bento/images/sponsors/sponsor_amd.png",
      "/themes/bento/images/sponsors/sponsor_b1-systems.png",
      "/themes/bento/images/sponsors/sponsor_ip-exchange2.png"]
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

  def fuzzy_time_string(time)
    diff = Time.now - Time.parse(time)
    return "now" if diff < 60
    return (diff/60).to_i.to_s + " min ago" if diff < 3600
    diff = Integer(diff/3600) # now hours
    return diff.to_s + (diff == 1 ? " hour ago" : " hours ago") if diff < 24
    diff = Integer(diff/24) # now days
    return diff.to_s + (diff == 1 ? " day ago" : " days ago") if diff < 14
    diff_w = Integer(diff/7) # now weeks
    return diff_w.to_s + (diff_w == 1 ? " week ago" : " weeks ago") if diff < 50
    diff_m = Integer(diff/30.5) # roughly months
    return diff_m.to_s + " months ago"
  end

  def setup_buildresult_trigger
    content_for :ready_function do 
      "setup_buildresult_trigger();"
    end
  end

  def tlink_to(text, length, *url_opts)
    "<span title='#{text}'>" + link_to( truncate(text, :length => length), *url_opts) + "</span>"
  end

  def package_exists?(project, package)
    if Package.find_cached(package, :project => project )
      return true
    else
      return false
    end
  end
 
  def package_link(project, package, opts = {})
    opts = { :hide_package => false, :hide_project => false, :length => 1000 }.merge(opts)
    if package_exists? project, package
      out = link_to 'br', { :controller => :project, :action => :package_buildresult, :project => project, :package => package }, { :class => "hidden build_result" }
      if opts[:hide_package]
        out += tlink_to(project, opts[:length], :controller => :package, :action => "show", :project => project, :package => package)
      elsif opts[:hide_project]
        out += tlink_to(package, opts[:length], :controller => :package, :action => "show", :project => project, :package => package)
      else
        out += tlink_to project, (opts[:length] - 3) / 2 , :controller => :project, :action => "show", :project => project
        out += " / " +  tlink_to(package, (opts[:length] - 3) / 2, :controller => :package, 
          :action => "show", :project => project, :package => package)
      end
    else
      if opts[:hide_package]
        out = "<span title='#{project}'>#{truncate(project, :length => opts[:length])}</span>"
      elsif opts[:hide_project]
        out = "<span title='#{package}'>#{truncate(package, :length => opts[:length])}</span>"
      else
        out = tlink_to project, (opts[:length] - 3) / 2, :controller => :project, :action => "show", :project => project
        out += " / " + "<span title='#{package}'>#{truncate(package, :length => (opts[:length] - 3) / 2)}</span>"
      end
    end
  end

  def status_for( repo, arch, package )
    @statushash[repo][arch][package] || ActiveXML::XMLNode.new("<status package='#{package}'/>")
  end

  def status_id_for( repo, arch, package )
    valid_xml_id("id-#{package}_#{repo}_#{arch}")
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
    
    out = "<td class='#{theclass} buildstatus'>"
    if ["unresolvable", "blocked"].include? code 
      out += link_to code, "#", :title => link_title, :id => status_id
      content_for :ready_function do
        "$('a##{status_id}').click(function() { alert('#{link_title.gsub(/\'/, '\'')}'); return false; });\n"
      end
    elsif ["-","excluded"].include? code
      out += code
    else
      out += link_to code.gsub(/\s/, "&nbsp;"), {:action => :live_build_log,
        :package => packname, :project => @project.to_s, :arch => arch,
        :controller => "package", :repository => repo}, {:title => link_title, :rel => 'nofollow'}
    end 
    return out + "</td>"
  end

  
  def repo_status_icon( status )
    icon = case status
    when "published" then "icons/lorry.png"
    when "publishing" then "icons/cog_go.png"
    when "outdated_published" then "icons/lorry_error.png"
    when "outdated_publishing" then "icons/cog_error.png"
    when "unpublished" then "icons/lorry_flatbed.png"
    when "outdated_unpublished" then "icons/lorry_error.png"
    when "building" then "icons/cog.png"
    when "outdated_building" then "icons/cog_error.png"
    when "finished" then "icons/time.png"
    when "outdated_finished" then "icons/time_error.png"
    when "blocked" then "icons/time.png"
    when "outdated_blocked" then "icons/time_error.png"
    when "broken" then "icons/exclamation.png"
    when "outdated_broken" then "icons/exclamation.png"
    when "scheduling" then "icons/cog.png"
    when "outdated_scheduling" then "icons/cog_error.png"
    else "icons/eye.png"
    end

    outdated = nil
    if status =~ /^outdated_/
      status.gsub!( %r{^outdated_}, '' )
      outdated = true
    end
    description = case status
    when "published" then "Repository has been published"
    when "publishing" then "Repository is created right now"
    when "unpublished" then "Build finished, but repository publishing is disabled"
    when "building" then "Build jobs exists"
    when "finished" then "Build jobs have been processed, new repository is not yet created"
    when "blocked" then "No build possible atm, waiting for jobs in other repositories"
    when "broken" then "The setup of repository is broken, build not possible"
    when "scheduling" then "The repository state is calculated right now"
    else "Unknown state of repository"
    end

    description = "State needs recalculations, former state was: " + description if outdated

    image_tag icon, :size => "16x16", :title => description, :alt => description
  end


  def flag_status(flags, repository, arch)
    image = nil
    flag = nil

    flags.each do |f|

      if f.has_attribute? :repository
        next if f.repository.to_s != repository
      else
        next if repository
      end
      if f.has_attribute? :arch
        next  if f.arch.to_s != arch
      else
        next if arch 
      end

      flag = f
      break
    end


    if flag

      if flag.has_attribute? :explicit
        if flag.element_name == 'disable'
          image = "#{flags.element_name}_disabled_blue.png"
        else
          image = "#{flags.element_name}_enabled_blue.png"
        end
      else
        if flag.element_name == 'disable'
          image = "#{flags.element_name}_disabled_grey.png"
        else
          image = "#{flags.element_name}_enabled_grey.png"
        end
      end

      if @user and @user.is_maintainer?(@project, @package)
        opts = { :project => @project, :repository => repository, :arch => arch, :package => @package, :flag => flags.element_name, :action => :change_flag }
        out = "<div class='flagimage'>" + image_tag(image) + "<div class='hidden flagtoggle'>"
        unless flag.has_attribute? :explicit and flag.element_name == 'disable'
          out += 
            "<div class='nowrap'>" +
            image_tag("#{flags.element_name}_disabled_blue.png", :alt => '0', :size => "24x24") +
            link_to("Explicitly disable", opts.merge({ :cmd => :set_flag, :status => :disable }), {:class => :flag_trigger}) +
            "</div>"
        end
        if flag.element_name == 'disable'
          out += 
            "<div class='nowrap'>" +
            image_tag("#{flags.element_name}_enabled_grey.png", :alt => '1', :size => "24x24") +
            link_to("Take default", opts.merge({ :cmd => :remove_flag }),:class => :flag_trigger) +
            "</div>"
        else
          out += 
            "<div class='nowrap'>" +
            image_tag("#{flags.element_name}_disabled_grey.png", :alt => '0', :size => "24x24") +
            link_to("Take default", opts.merge({ :cmd => :remove_flag }), :class => :flag_trigger)+
            "</div>"
        end if flag.has_attribute? :explicit
        unless flag.has_attribute? :explicit and flag.element_name != 'disable'
          out += 
            "<div class='nowrap'>" +
            image_tag("#{flags.element_name}_enabled_blue.png", :alt => '1', :size => "24x24") +
            link_to("Explicitly enable", opts.merge({ :cmd => :set_flag, :status => :enable }), :class => :flag_trigger) +
            "</div>"
        end
        out += "</div></div>"
      else
        image_tag(image)
      end
    else
      ""
    end
  end

  def plural( count, singular, plural)
    count > 1 ? plural : singular
  end

  def valid_xml_id(rawid)
    ERB::Util::h(rawid.gsub(/[+&: .]/, '_'))
  end

  def format_comment(comment)
    comment ||= '-'
    comment = ERB::Util::h(comment).gsub(%r{[\n\r]}, '<br/>')
    # always prepend a newline so the following code can eat up leading spaces over all lines
    comment = '<br/>' + comment
    comment = comment.gsub('(<br/> *) ', '\1&nbsp;')
    comment = comment.gsub(%r{^<br/>}, '')
    return "<code>" + comment + "</code>"
  end

end
