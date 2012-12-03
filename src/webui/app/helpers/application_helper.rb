# vim: sw=2 et

require 'digest/md5'

require 'action_view/helpers/asset_tag_helper.rb'
module ActionView
  module Helpers

    @@rails_root = nil
    def real_public
      return @@rails_root if @@rails_root
      @@rails_root = Rails.root.join('public')
    end

    @@icon_cache = Hash.new
    
    def rewrite_asset_path(_source)
      if @@icon_cache[_source]
        return @@icon_cache[_source]
      end
      new_path = "/vendor/#{CONFIG['theme']}#{_source}"
      if File.exists?("#{Rails.root.to_s}/public#{new_path}")
        source = new_path
      elsif File.exists?("#{Rails.root.to_s}/public#{_source}")
        source = _source
      else
        return super(_source)
      end
      source=Pathname.new("#{Rails.root.to_s}/public#{source}").realpath
      source="/" + Pathname.new(source).relative_path_from(real_public).to_s
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
        @user ||= Person.find_cached( session[:login] )
      rescue RuntimeError
        logger.error "Cannot load person data for #{session[:login]} in application_helper"
      end
    end
    return @user
  end

  def repo_url(project, repo='' )
    if defined? CONFIG['download_url']
      "#{CONFIG['download_url']}/" + project.to_s.gsub(/:/,':/') + "/#{repo}"
    else
      nil
    end
  end

  def get_frontend_url_for( opt={} )
    opt[:host] ||= CONFIG['external_frontend_host'] || CONFIG['frontend_host']
    opt[:port] ||= CONFIG['external_frontend_port'] || CONFIG['frontend_port']
    opt[:protocol] ||= CONFIG['external_frontend_protocol'] || CONFIG['frontend_protocol']

    if not opt[:controller]
      logger.error "No controller given for get_frontend_url_for()."
      return
    end

    return "#{opt[:protocol]}://#{opt[:host]}:#{opt[:port]}/#{opt[:controller]}"
  end

  def bugzilla_url(email_list="", desc="")
    return '' if CONFIG['bugzilla_host'].nil?
    assignee = email_list.first if email_list
    if email_list.length > 1
      cc = ("&cc=" + email_list[1..-1].join("&cc=")) if email_list
    end
    URI.escape("#{CONFIG['bugzilla_host']}/enter_bug.cgi?classification=7340&product=openSUSE.org&component=3rd party software&assigned_to=#{assignee}#{cc}&short_desc=#{desc}")
  end

  SPONSORS = [
      "sponsor_suse",
      "sponsor_amd",
      "sponsor_b1-systems",
      "sponsor_ip-exchange2",
      "sponsor_heinlein"]

  def get_random_sponsor_image
    return SPONSORS.sample
  end

  def image_url(source)
    abs_path = image_path(source)
    unless abs_path =~ /^http/
      abs_path = "#{request.protocol}#{request.host_with_port}#{abs_path}"
    end
    abs_path
  end

  def user_icon(login, size=20)
    return image_tag(url_for(controller: :home, action: :icon, user: login.to_s, size: size), 
                     width: size, height: size)
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
    return diff_w.to_s + (diff_w == 1 ? " week ago" : " weeks ago") if diff < 63
    diff_m = Integer(diff/30.5) # roughly months
    return diff_m.to_s + " months ago"
  end

  def status_for( repo, arch, package )
    @statushash[repo][arch][package] || { "package" => package } 
  end

  def format_projectname(prjname, login)
    splitted = prjname.split(':', 4)
    if splitted[0] == "home"
      if login and splitted[1] == login
        if splitted.length == 2
          prjname = "~"
        else
          prjname = "~:" + splitted[-1]
        end
      else
        prjname = "~" + splitted[1] + ":" + splitted[-1]
      end
    end
    prjname
  end

  def status_id_for( repo, arch, package )
    valid_xml_id("id-#{package}_#{repo}_#{arch}")
  end

  def arch_repo_table_cell(repo, arch, packname)
    status = status_for(repo, arch, packname)
    status_id = status_id_for( repo, arch, packname)
    link_title = status['details']
    if status['code']
      code = status['code']
      theclass="status_" + code.gsub(/[- ]/,'_')
    else
      code = ''
      theclass=''
    end

    out = "<td class='#{theclass} buildstatus'>"
    if ["unresolvable", "blocked"].include? code 
      out += link_to code, "#", title: link_title, id: status_id
      content_for :ready_function do
        "$('a##{status_id}').click(function() { alert('#{link_title.gsub(/'/, '\\\\\'')}'); return false; });\n".html_safe
      end
    elsif ["-","excluded"].include? code
      out += code
    else
      out += link_to code.gsub(/\s/, "&nbsp;"), {action: :live_build_log,
        package: packname, project: @project.to_s, arch: arch,
        controller: "package", repository: repo}, {title: link_title, rel: 'nofollow'}
    end 
    out += "</td>"
    return out.html_safe
  end

  REPO_STATUS_ICONS = {
    "published"            => "lorry",
    "publishing"           => "cog_go",
    "outdated_published"   => "lorry_error",
    "outdated_publishing"  => "cog_error",
    "unpublished"          => "lorry_flatbed",
    "outdated_unpublished" => "lorry_error",
    "building"             => "cog",
    "outdated_building"    => "cog_error",
    "finished"             => "time",
    "outdated_finished"    => "time_error",
    "blocked"              => "time",
    "outdated_blocked"     => "time_error",
    "broken"               => "exclamation",
    "outdated_broken"      => "exclamation",
    "scheduling"           => "cog",
    "outdated_scheduling"  => "cog_error",
  }

  REPO_STATUS_DESCRIPTIONS = {
    "published"   => "Repository has been published",
    "publishing"  => "Repository is being created right now",
    "unpublished" => "Build finished, but repository publishing is disabled",
    "building"    => "Build jobs exists",
    "finished"    => "Build jobs have been processed, new repository is not yet created",
    "blocked"     => "No build possible atm, waiting for jobs in other repositories",
    "broken"      => "The repository setup is broken, build not possible",
    "scheduling"  => "The repository state is being calculated right now",
  }

  def repo_status_icon( status )
    icon = REPO_STATUS_ICONS[status] || "eye"

    outdated = nil
    if status =~ /^outdated_/
      status.gsub!( %r{^outdated_}, '' )
      outdated = true
    end

    description = REPO_STATUS_DESCRIPTIONS[status] || "Unknown state of repository"
    description = "State needs recalculations, former state was: " + description if outdated

    sprite_tag icon, title: description
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
          image = "#{flags.element_name}_disabled_blue"
        else
          image = "#{flags.element_name}_enabled_blue"
        end
      else
        if flag.element_name == 'disable'
          image = "#{flags.element_name}_disabled_grey"
        else
          image = "#{flags.element_name}_enabled_grey"
        end
      end

      if @user && @user.is_maintainer?(@project, @package)
        opts = { project: @project, package: @package, action: :repositories }
        data = { flag: flags.element_name }
        data[:repository] = repository if repository
        data[:arch] = arch if arch
        content_tag(:div, class: 'flagimage', data: data) do
          content_tag(:div, class: "icons-#{image} icon_24") do
            content_tag(:div, class: 'hidden flagtoggle') do
              out = ''.html_safe
              unless flag.has_attribute? :explicit and flag.element_name == 'disable'
                out += content_tag(:div, class: 'iconwrapper') do
                  content_tag(:div, '', class: "icons-#{flags.element_name}_disabled_blue icon_24")
                end
                out += link_to("Explicitly disable", opts, class: "nowrap flag_trigger", data: { cmd: :set_flag, status: :disable} )
              end
              if flag.element_name == 'disable'
                out += content_tag(:div, class: 'iconwrapper') do
                  content_tag(:div, '', class: "icons-#{flags.element_name}_enabled_grey icon_24")
                end
                out += link_to("Take default", opts, class: "nowrap flag_trigger", data: {cmd: :remove_flag } )
              else
                out += content_tag(:div, class: 'iconwrapper') do
                  content_tag(:div, '', class: "icons-#{flags.element_name}_disabled_grey icon_24")
                end
                out += link_to("Take default", opts, class: "nowrap flag_trigger", data: { cmd: :remove_flag })
              end if flag.has_attribute? :explicit
              unless flag.has_attribute? :explicit and flag.element_name != 'disable'
                out += content_tag(:div, class: 'iconwrapper') do
                  content_tag(:div, '', class: "icons-#{flags.element_name}_enabled_blue icon_24")
                end
                out += link_to("Explicitly enable", opts, class: "nowrap flag_trigger", data: { cmd: :set_flag, status: :enable })
              end
              out
            end
          end
        end
      else
        sprite_tag(image)
      end
    else
      ""
    end
  end

  def plural( count, singular, plural)
    count > 1 ? plural : singular
  end

  def valid_xml_id(rawid)
    rawid = '_' + rawid if rawid !~ /^[A-Za-z_]/ # xs:ID elements have to start with character or '_'
    ERB::Util::h(rawid.gsub(/[+&: .\/\~\(\)@]/, '_'))
  end

  def tab(id, text, opts)
    opts[:package] = @package.to_s if @package
    opts[:project] = @project.to_s
    link_opts = {id: "tab-#{id}"}
    if @current_action.to_s == opts[:action].to_s and @current_controller.to_s == opts[:controller].to_s
      link_opts[:class] = "selected"
    end
    return content_tag("li", link_to(h(text), opts), link_opts)
  end

  # Shortens a text if it longer than 'length'. 
  def elide(text, length = 20, mode = :middle)
    shortened_text = text.to_s      # make sure it's a String

    return "..." if length <= 3     # corner case

    if text.length > length
      case mode
      when :left                    # shorten at the beginning
        shortened_text = "..." + text[text.length - length + 3 .. text.length]
      when :middle                  # shorten in the middle
        pre = text[0 .. length / 2 - 2]
        offset = 2                  # depends if (shortened) length is even or odd
        offset = 1 if length.odd?
        post = text[text.length - length / 2 + offset .. text.length]
        shortened_text = pre + "..." + post
      when :right                   # shorten at the end
        shortened_text = text[0 .. length - 4 ] + "..."
      end
    end
    return shortened_text
  end

  def elide_two(text1, text2, overall_length = 40, mode = :middle)
    half_length = overall_length / 2
    text1_free = half_length - text1.length
    text1_free = 0 if text1_free < 0
    text2_free = half_length - text2.length
    text2_free = 0 if text2_free < 0
    return [elide(text1, half_length + text2_free, mode), elide(text2, half_length + text1_free, mode)]
  end

  def force_utf8_and_transform_nonprintables(text)
    unless text.valid_encoding?
      text = 'The file you look at is not valid UTF-8 text. Please convert the file.'
    end
    # Ged rid of stuff that shouldn't be part of PCDATA:
    return text.gsub(/([^a-zA-Z0-9&;<>\/\n \t()])/u) do
      if $1[0].getbyte(0) < 32
        ''
      else
        $1
      end
    end
  end

  # Same as redirect_to(:back) if there is a valid HTTP referer, otherwise redirect_to()
  def redirect_back_or_to(options = {}, response_status = {})
    if request.env["HTTP_REFERER"]
      redirect_to(:back)
    else
      redirect_to(options, response_status)
    end
  end

  def description_wrapper(description)
    unless description.blank?
      content_tag(:pre, description, id: "description_text", class: "plain")
    else
      content_tag(:p, id: "description_text") do
        content_tag(:i, "No description set")
      end
    end
  end

  def is_advanced_tab?
    ["prjconf", "attributes", "meta", "status"].include? @current_action.to_s
  end

  def mobile_device?
    request.env['mobile_device_type'] == :mobile
  end

  def sprite_tag(icon, opts = {})
    if opts.has_key? :class
	    opts[:class] += " icons-#{icon} inlineblock"
    else
	    opts[:class] = "icons-#{icon} inlineblock"
    end
    content_tag(:span, '', opts)
  end

  def setup_codemirror_editor(opts = {})
    if @codemirror_editor_setup
      @codemirror_editor_setup = @codemirror_editor_setup + 1
      return @codemirror_editor_setup
    end
    @codemirror_editor_setup = 0
    opts.reverse_merge!({ read_only: false, no_border: false, width: 'auto', height: '660px' })

    content_for(:content_for_head, javascript_include_tag('cm2'))
    style = ''
    if opts[:no_border] || opts[:read_only]
      style += ".CodeMirror { border-width: 0 0 0 0; }\n"
    end

    style += ".CodeMirror-scroll {\n"
    style += "height: #{opts[:height]};\n"
    if opts[:height] == 'auto'
      style += "overflow: auto;\n"
    end
    style += "width: #{opts[:width]}; \n}\n"
    content_for(:head_style, style)
    return @codemirror_editor_setup
  end

  def link_to_project(prj, linktext=nil)
    linktext = prj if linktext.blank?
    if Project.exists?(prj)
      link_to(linktext, {:controller => :project, :action => :show, :project => prj}, title: prj )
    else
      linktext
    end
  end

  def link_to_package(prj, pkg, linktext=nil)
    linktext = pkg if linktext.blank?
    if Package.exists?(prj, pkg)
      link_to(linktext, { controller: :package, action: :show, project: prj, package: pkg}, title: pkg)
    else
      linktext
    end
  end

end

