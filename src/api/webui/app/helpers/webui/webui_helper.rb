# vim: sw=2 et

require 'digest/md5'

module Webui::WebuiHelper

  include ActionView::Helpers::JavaScriptHelper

  def repo_url(project, repo='')
    if @configuration['download_url']
      "#{@configuration['download_url']}/" + project.to_s.gsub(/:/, ':/') + "/#{repo}"
    else
      nil
    end
  end

  def get_frontend_url_for(opt={})
    opt[:host] ||= CONFIG['external_frontend_host'] || CONFIG['frontend_host']
    opt[:port] ||= CONFIG['external_frontend_port'] || CONFIG['frontend_port']
    opt[:protocol] ||= CONFIG['external_frontend_protocol'] || CONFIG['frontend_protocol']

    if not opt[:controller]
      logger.error 'No controller given for get_frontend_url_for().'
      return
    end

    return "#{opt[:protocol]}://#{opt[:host]}:#{opt[:port]}/#{opt[:controller]}"
  end

  def bugzilla_url(email_list='', desc='')
    return '' if @configuration['bugzilla_url'].blank?
    assignee = email_list.first if email_list
    if email_list.length > 1
      cc = ('&cc=' + email_list[1..-1].join('&cc=')) if email_list
    end
    URI.escape("#{@configuration['bugzilla_url']}/enter_bug.cgi?classification=7340&product=openSUSE.org&component=3rd party software&assigned_to=#{assignee}#{cc}&short_desc=#{desc}")
  end

  def image_url(source)
    abs_path = image_path(source)
    unless abs_path =~ /^http/
      abs_path = "#{request.protocol}#{request.host_with_port}#{abs_path}"
    end
    abs_path
  end

  def user_icon(user, size=20, css_class=nil, alt=nil)
    user = User.find_by_login!(user) unless user.is_a? User
    alt ||= user.realname
    alt = user.login if alt.empty?
    if size < 3 # TODO: needs more work, if the icon appears often on the page, it's cheaper to fetch it
      content = user.gravatar_image(size)
      if content == :none
        content = Rails.cache.fetch('default_face') do
          File.open(Rails.root.join('app', 'assets', 'images',
                                    'default_face.png'), 'r').read
        end
      end
      "<img src='data:image/jpeg;base64,#{Base64.encode64(content)}' width='#{size}' height='#{size}' alt='#{alt}' class='#{css_class}'/>".html_safe
    else
      image_tag(url_for(controller: :home, action: :icon, user: user.login, size: size),
                width: size, height: size, alt: alt, class: css_class)
    end
  end

  def fuzzy_time(time)
    if Time.now - time < 60
      return 'now' # rails' 'less than a minute' is a bit long
    end
    time_ago_in_words(time) + ' ago'
  end

  def fuzzy_time_string(timestring)
    fuzzy_time(Time.parse(timestring))
  end

  def status_for(repo, arch, package)
    @statushash[repo][arch][package] || { 'package' => package }
  end

  def format_projectname(prjname, login)
    splitted = prjname.split(':', 4)
    if splitted[0] == 'home'
      if login and splitted[1] == login
        if splitted.length == 2
          prjname = '~'
        else
          prjname = '~:' + splitted[-1]
        end
      else
        prjname = '~' + splitted[1] + ':' + splitted[-1]
      end
    end
    prjname
  end

  def status_id_for(repo, arch, package)
    valid_xml_id("id-#{package}_#{repo}_#{arch}")
  end

  def arch_repo_table_cell(repo, arch, packname)
    status = status_for(repo, arch, packname)
    status_id = status_id_for(repo, arch, packname)
    link_title = status['details']
    if status['code']
      code = status['code']
      theclass='status_' + code.gsub(/[- ]/, '_')
    else
      code = ''
      theclass=''
    end

    out = "<td class='#{theclass} buildstatus'>"
    if ['unresolvable', 'blocked'].include? code
      out += link_to code, '#', title: link_title, id: status_id
      content_for :ready_function do
        "$('a##{status_id}').click(function() { alert('#{link_title.gsub(/'/, '\\\\\'')}'); return false; });\n".html_safe
      end
    elsif ['-', 'excluded'].include? code
      out += code
    else
      out += link_to code.gsub(/\s/, '&nbsp;'), { action: :live_build_log,
                                                  package: packname, project: @project.to_s, arch: arch,
                                                  controller: 'package', repository: repo }, { title: link_title, rel: 'nofollow' }
    end
    out += '</td>'
    return out.html_safe
  end

  REPO_STATUS_ICONS = {
      'published' => 'lorry',
      'publishing' => 'cog_go',
      'outdated_published' => 'lorry_error',
      'outdated_publishing' => 'cog_error',
      'unpublished' => 'lorry_flatbed',
      'outdated_unpublished' => 'lorry_error',
      'building' => 'cog',
      'outdated_building' => 'cog_error',
      'finished' => 'time',
      'outdated_finished' => 'time_error',
      'blocked' => 'time',
      'outdated_blocked' => 'time_error',
      'broken' => 'exclamation',
      'outdated_broken' => 'exclamation',
      'scheduling' => 'cog',
      'outdated_scheduling' => 'cog_error',
  }

  REPO_STATUS_DESCRIPTIONS = {
      'published' => 'Repository has been published',
      'publishing' => 'Repository is being created right now',
      'unpublished' => 'Build finished, but repository publishing is disabled',
      'building' => 'Build jobs exists',
      'finished' => 'Build jobs have been processed, new repository is not yet created',
      'blocked' => 'No build possible atm, waiting for jobs in other repositories',
      'broken' => 'The repository setup is broken, build not possible',
      'scheduling' => 'The repository state is being calculated right now',
  }

  def repo_status_icon(status)
    icon = REPO_STATUS_ICONS[status] || 'eye'

    outdated = nil
    if status =~ /^outdated_/
      status.gsub!(%r{^outdated_}, '')
      outdated = true
    end

    description = REPO_STATUS_DESCRIPTIONS[status] || 'Unknown state of repository'
    description = 'State needs recalculations, former state was: ' + description if outdated

    sprite_tag icon, title: description
  end


  def flag_status(flagname, flags, repository, arch)
    flag = determine_most_specific_flag(arch, flags, repository)
    return '' unless flag

    image, title = flag_image(flag, flagname)

    if (@package && User.current.can_modify_package?(@package.api_obj)) ||
        (@project && User.current.can_modify_project?(@project.api_obj))
      opts = { project: @project, package: @package, action: :repositories }
      data = { flag: flagname }
      data[:repository] = repository if repository
      data[:arch] = arch if arch
      content_tag(:div, class: 'flagimage', data: data) do
        content_tag(:div, class: "icons-#{image} icon_24") do
          content_tag(:div, class: 'hidden flagtoggle') do
            out = ''.html_safe
            unless flag[1].has_key? :explicit and flag[0] == 'disable'
              out += content_tag(:div, class: 'iconwrapper') do
                content_tag(:div, '', class: "icons-#{flagname}_disabled_blue icon_24")
              end
              out += link_to('Explicitly disable', opts, class: 'nowrap flag_trigger', data: { cmd: :set_flag, status: :disable })
            end
            if flag[0] == 'disable'
              out += content_tag(:div, class: 'iconwrapper') do
                content_tag(:div, '', class: "icons-#{flagname}_enabled_grey icon_24")
              end
              out += link_to('Take default', opts, class: 'nowrap flag_trigger', data: { cmd: :remove_flag })
            else
              out += content_tag(:div, class: 'iconwrapper') do
                content_tag(:div, '', class: "icons-#{flagname}_disabled_grey icon_24")
              end
              out += link_to('Take default', opts, class: 'nowrap flag_trigger', data: { cmd: :remove_flag })
            end if flag[1].has_key? :explicit
            unless flag[1].has_key? :explicit and flag[0] != 'disable'
              out += content_tag(:div, class: 'iconwrapper') do
                content_tag(:div, '', class: "icons-#{flagname}_enabled_blue icon_24")
              end
              out += link_to('Explicitly enable', opts, class: 'nowrap flag_trigger', data: { cmd: :set_flag, status: :enable })
            end
            out
          end
        end
      end
    else
      sprite_tag(image, title: title)
    end
  end

  def flag_image(flag, flagname)
    suffix = flag[1].has_key?(:explicit) ? 'blue' : 'grey'
    if flag[0] == 'disable'
      ["#{flagname}_disabled_#{suffix}", 'disabled']
    else
      ["#{flagname}_enabled_#{suffix}", 'enabled']
    end
  end

  def determine_most_specific_flag(arch, flags, repository)
    flag = nil

    flags.each do |status, f|
      if f.has_key? :repository
        next if f[:repository].to_s != repository
      else
        next if repository
      end
      if f.has_key? :arch
        next if f[:arch].to_s != arch
      else
        next if arch
      end

      flag = [status, f]
      break
    end
    flag
  end

  def plural(count, singular, plural)
    count > 1 ? plural : singular
  end

  def valid_xml_id(rawid)
    rawid = '_' + rawid if rawid !~ /^[A-Za-z_]/ # xs:ID elements have to start with character or '_'
    ERB::Util::h(rawid.gsub(/[+&: .\/\~\(\)@#]/, '_'))
  end

  def tab(id, text, opts)
    opts[:package] = @package.to_s if @package
    opts[:project] = @project.to_s if @project
    link_opts = { id: "tab-#{id}" }
    if @current_action.to_s == opts[:action].to_s and @current_controller.to_s == opts[:controller].to_s
      link_opts[:class] = 'selected'
    end
    return content_tag('li', link_to(h(text), opts), link_opts)
  end

  # Shortens a text if it longer than 'length'.
  def elide(text, length = 20, mode = :middle)
    shortened_text = text.to_s # make sure it's a String

    return '' if text.blank?

    return '...' if length <= 3 # corner case

    if text.length > length
      case mode
      when :left # shorten at the beginning
        shortened_text = '...' + text[text.length - length + 3 .. text.length]
      when :middle # shorten in the middle
        pre = text[0 .. length / 2 - 2]
        offset = 2 # depends if (shortened) length is even or odd
        offset = 1 if length.odd?
        post = text[text.length - length / 2 + offset .. text.length]
        shortened_text = pre + '...' + post
      when :right # shorten at the end
        shortened_text = text[0 .. length - 4] + '...'
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
    return text.gsub(/([^a-zA-Z0-9&;<>\/\n \t()])/) do
      if $1[0].getbyte(0) < 32
        ''
      else
        $1
      end
    end
  end

  # Same as redirect_to(:back) if there is a valid HTTP referer, otherwise redirect_to()
  def redirect_back_or_to(options = {}, response_status = {})
    if request.env['HTTP_REFERER']
      redirect_to(:back)
    else
      redirect_to(options, response_status)
    end
  end

  def description_wrapper(description)
    unless description.blank?
      content_tag(:pre, description, id: 'description_text', class: 'plain')
    else
      content_tag(:p, id: 'description_text') do
        content_tag(:i, 'No description set')
      end
    end
  end

  def is_advanced_tab?
    ['prjconf', 'attributes', 'meta', 'status'].include? @current_action.to_s
  end

  def mobile_device?
    request.env['mobile_device_type'] == :mobile
  end

  def sprite_tag(icon, opts = {})
    if opts.has_key? :class
      opts[:class] += " icons-#{icon}"
    else
      opts[:class] = "icons-#{icon}"
    end
    unless opts.has_key? :alt
      alt = icon
      if opts[:title]
        alt = opts[:title]
      else
        Rails.logger.warn 'No alt/title text for sprite_tag'
      end
      opts[:alt] = alt
    end
    image_tag('s.gif', opts)
  end

  def next_codemirror_uid
    @codemirror_editor_setup = @codemirror_editor_setup + 1
    return @codemirror_editor_setup
  end

  def setup_codemirror_editor(opts = {})
    if @codemirror_editor_setup
      return next_codemirror_uid
    end
    @codemirror_editor_setup = 0
    opts.reverse_merge!({ read_only: false, no_border: false, width: 'auto' })

    content_for(:content_for_head, javascript_include_tag('webui/cm2'))
    style = ''
    style += ".CodeMirror {\n"
    if opts[:no_border] || opts[:read_only]
      style += "border-width: 0 0 0 0;\n"
    end
    style += "height: #{opts[:height]};\n" unless opts[:height] == 'auto'
    style += "width: #{opts[:width]}; \n" unless opts[:width] == 'auto'
    style += "}\n"
    content_for(:head_style, style)
    return @codemirror_editor_setup
  end

  def remove_dialog_tag(text)
    link_to(text, '#', title: 'Remove Dialog', id: 'remove_dialog')
  end

  # dialog_init is a function name called before dialog is shown
  def render_dialog(dialog_init = nil)
    check_ajax
    @dialog_html = escape_javascript(render_to_string(partial: @current_action.to_s))
    @dialog_init = dialog_init
    render partial: 'dialog', content_type: 'application/javascript'
  end

  # @param [String] user login of the user
  # @param [String] role title of the login
  # @param [Hash]   options boolean flags :short, :no_icon and :no_link
  def user_and_role(user, role=nil, options = {})
    opt = { short: false, no_icon: false, no_link: false }.merge(options)
    realname = User.realname_for_login(user)
    output = ''

    output += user_icon(user) unless opt[:no_icon]
    unless realname.empty? or opt[:short] == true
      printed_name = realname + ' (' + user + ')'
    else
      printed_name = user
    end
    if role
      printed_name += ' as ' + role
    end
    unless User.current.is_nobody?
      output += link_to_if(!opt[:no_link], printed_name, :controller => 'home', :user => user)
    else
      output += printed_name
    end
    output.html_safe
  end

  def package_link(pack, opts = {})
    opts[:project] = pack.project
    opts[:package] = pack.name
    project_or_package_link opts
  end

  def link_to_package(prj, pkg, opts)
    opts[:project_text] ||= opts[:project]
    opts[:package_text] ||= opts[:package]

    opts[:project_text], opts[:package_text] =
        elide_two(opts[:project_text], opts[:package_text], opts[:trim_to])

    if opts[:short]
      out = ''.html_safe
    else
      out = 'package '.html_safe
    end

    opts[:short] = true # for project
    out += link_to_project(prj, opts) + ' / ' +
        link_to_if(pkg, opts[:package_text],
                   { controller: 'package', action: 'show',
                     project: opts[:project],
                     package: opts[:package] }, { class: 'package', title: opts[:package] })
    if opts[:rev] && pkg
      out += ' ('.html_safe +
          link_to("revision #{elide(opts[:rev], 10)}",
                  { controller: 'package', action: 'show',
                    project: opts[:project], package: opts[:package], rev: opts[:rev] },
                  { class: 'package', title: opts[:rev] }) + ')'.html_safe
    end
    out
  end

  def link_to_project(prj, opts)
    opts[:project_text] ||= opts[:project]
    if opts[:short]
      out = ''.html_safe
    else
      out = 'project '.html_safe
    end
    out + link_to_if(prj, elide(opts[:project_text], opts[:trim_to]),
                     { controller: 'project', action: 'show', project: opts[:project] },
                     { class: 'project', title: opts[:project] })
  end

  def project_or_package_link(opts)
    defaults = { package: nil, rev: nil, short: false, trim_to: 40 }
    opts = defaults.merge(opts)

    CacheLine.fetch(['project_or_package_link', opts], project: opts[:project], package: opts[:package]) do
      # only care for database entries
      prj = Project.where(name: opts[:project]).select(:id, :name).first
      if prj && opts[:creator]
        opts[:project_text] ||= format_projectname(opts[:project], opts[:creator])
      end
      if opts[:package] && prj && opts[:package] != :multiple
        pkg = prj.packages.where(name: opts[:package]).select(:id, :name, :db_project_id).first
      end
      if opts[:package]
        link_to_package(prj, pkg, opts)
      else
        link_to_project(prj, opts)
      end
    end
  end

  def user_with_realname_and_icon(user, opts = {})
    defaults = { short: false, no_icon: false, no_link: false }
    opts = defaults.merge(opts)

    user = User.find_by_login(user) unless user.is_a? User
    return '' unless user

    Rails.cache.fetch([user, 'realname_and_icon', opts, Configuration.first]) do
      realname = user.realname

      if opts[:short] || realname.empty?
        printed_name = user.login
      else
        printed_name = "#{realname} (#{user.login})"
      end

      user_icon(user) + ' ' + link_to_if(!opts[:no_link], printed_name,
                                         controller: 'home', user: user.login)
    end
  end

  def possibly_empty_ul(html_opts, &block)
    content = capture(&block)
    if content.blank?
      html_opts[:fallback]
    else
      html_opts.delete :fallback
      content_tag(:ul, content, html_opts)
    end
  end
end
