# vim: sw=2 et
require 'digest/md5'

module Webui::WebuiHelper
  include ActionView::Helpers::JavaScriptHelper
  include ActionView::Helpers::AssetTagHelper
  include Webui::BuildresultHelper

  def get_frontend_url_for(opt = {})
    opt[:host] ||= CONFIG['external_frontend_host'] || CONFIG['frontend_host']
    opt[:port] ||= CONFIG['external_frontend_port'] || CONFIG['frontend_port']
    opt[:protocol] ||= CONFIG['external_frontend_protocol'] || CONFIG['frontend_protocol']

    unless opt[:controller]
      logger.error 'No controller given for get_frontend_url_for().'
      return
    end

    "#{opt[:protocol]}://#{opt[:host]}:#{opt[:port]}/#{opt[:controller]}"
  end

  def bugzilla_url(email_list = '', desc = '')
    return '' if @configuration['bugzilla_url'].blank?
    assignee = email_list.first if email_list
    if email_list.length > 1
      cc = ('&cc=' + email_list[1..-1].join('&cc=')) if email_list
    end
    # rubocop:disable Metrics/LineLength
    URI.escape("#{@configuration['bugzilla_url']}/enter_bug.cgi?classification=7340&product=openSUSE.org&component=3rd party software&assigned_to=#{assignee}#{cc}&short_desc=#{desc}")
    # rubocop:enable Metrics/LineLength
  end

  def user_icon(user, size = 20, css_class = nil, alt = nil)
    user = User.find_by_login!(user) unless user.is_a? User
    alt ||= user.realname
    alt = user.login if alt.empty?
    image_tag(url_for(controller: :user, action: :user_icon, icon: user.login, size: size),
              width: size, height: size, alt: alt, class: css_class)
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

  def format_projectname(prjname, login)
    splitted = prjname.split(':', 3)
    if splitted[0] == 'home'
      if login && splitted[1] == login
        prjname = '~'
      else
        prjname = '~' + splitted[1]
      end
      if splitted.length > 2
        prjname += ':' + splitted[-1]
      end
    end
    prjname
  end

  REPO_STATUS_ICONS = {
    'published'            => 'lorry',
    'publishing'           => 'cog_go',
    'outdated_published'   => 'lorry_error',
    'outdated_publishing'  => 'cog_error',
    'unpublished'          => 'lorry_flatbed',
    'outdated_unpublished' => 'lorry_error',
    'building'             => 'cog',
    'outdated_building'    => 'cog_error',
    'finished'             => 'time',
    'outdated_finished'    => 'time_error',
    'blocked'              => 'time',
    'outdated_blocked'     => 'time_error',
    'broken'               => 'exclamation',
    'outdated_broken'      => 'exclamation',
    'scheduling'           => 'cog',
    'outdated_scheduling'  => 'cog_error'
  }

  REPO_STATUS_DESCRIPTIONS = {
    'published'   => 'Repository has been published',
    'publishing'  => 'Repository is being created right now',
    'unpublished' => 'Build finished, but repository publishing is disabled',
    'building'    => 'Build jobs exists',
    'finished'    => 'Build jobs have been processed, new repository is not yet created',
    'blocked'     => 'No build possible atm, waiting for jobs in other repositories',
    'broken'      => 'The repository setup is broken, build or publish not possible',
    'scheduling'  => 'The repository state is being calculated right now'
  }

  def repo_status_icon(status, details = nil)
    icon = REPO_STATUS_ICONS[status] || 'eye'

    outdated = nil
    if status =~ /^outdated_/
      status.gsub!(%r{^outdated_}, '')
      outdated = true
    end

    description = REPO_STATUS_DESCRIPTIONS[status] || 'Unknown state of repository'
    description = 'State needs recalculations, former state was: ' + description if outdated
    description << " (" + details + ")" if details

    sprite_tag icon, title: description
  end

  def tab(id, text, opts)
    opts[:package] = @package.to_s if @package
    opts[:project] = @project.to_s if @project
    link_opts = { id: "tab-#{id}" }
    if @current_action.to_s == opts[:action].to_s && @current_controller.to_s == opts[:controller].to_s
      link_opts[:class] = 'selected'
    end
    content_tag('li', link_to(h(text), opts), link_opts)
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
    shortened_text
  end

  def elide_two(text1, text2, overall_length = 40, mode = :middle)
    half_length = overall_length / 2
    text1_free = half_length - text1.length
    text1_free = 0 if text1_free < 0
    text2_free = half_length - text2.length
    text2_free = 0 if text2_free < 0
    [elide(text1, half_length + text2_free, mode), elide(text2, half_length + text1_free, mode)]
  end

  def force_utf8_and_transform_nonprintables(text)
    text.force_encoding('UTF-8')
    unless text.valid_encoding?
      text = 'The file you look at is not valid UTF-8 text. Please convert the file.'
    end
    # Ged rid of stuff that shouldn't be part of PCDATA:
    text.gsub(/([^a-zA-Z0-9&;<>\/\n \t()])/) do
      if $1[0].getbyte(0) < 32
        ''
      else
        $1
      end
    end
  end

  def description_wrapper(description)
    if description.blank?
      content_tag(:p, id: 'description-text') do
        content_tag(:i, 'No description set')
      end
    else
      content_tag(:pre, description, id: 'description-text', class: 'plain')
    end
  end

  def is_advanced_tab?
    %w(prjconf index meta status).include? @current_action.to_s
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

  def sprited_text(icon, text)
    sprite_tag(icon, title: text) + ' ' + text
  end

  def next_codemirror_uid
    @codemirror_editor_setup = @codemirror_editor_setup + 1
    @codemirror_editor_setup
  end

  def setup_codemirror_editor(opts = {})
    if @codemirror_editor_setup
      return next_codemirror_uid
    end
    @codemirror_editor_setup = 0
    opts.reverse_merge!({ read_only: false, no_border: false, width: 'auto' })

    content_for(:content_for_head, javascript_include_tag('webui/application/cm2/index'))
    style = ''
    style += ".CodeMirror {\n"
    if opts[:no_border] || opts[:read_only]
      style += "border-width: 0 0 0 0;\n"
    end
    style += "height: #{opts[:height]};\n" unless opts[:height] == 'auto'
    style += "width: #{opts[:width]}; \n" unless opts[:width] == 'auto'
    style += "}\n"
    content_for(:head_style, style)
    @codemirror_editor_setup
  end

  def remove_dialog_tag(text)
    link_to(text, '#', title: 'Close', id: 'remove_dialog')
  end

  # @param [String] user login of the user
  # @param [String] role title of the login
  # @param [Hash]   options boolean flags :short, :no_icon and :no_link
  def user_and_role(user, role = nil, options = {})
    opt = { short: false, no_icon: false, no_link: false }.merge(options)
    real_name = User.realname_for_login(user)

    if opt[:no_icon]
      icon = ''
    else
      # user_icon returns an ActiveSupport::SafeBuffer and not a String
      icon = user_icon(user)
    end

    if !(real_name.empty? || opt[:short])
      printed_name = "#{real_name} (#{user})"
    else
      printed_name = user
    end

    printed_name << " as #{role}" if role

    # It's necessary to concat icon and $variable and don't use string interpolation!
    # Otherwise we get a new string and not an ActiveSupport::SafeBuffer
    if User.current.is_nobody?
      icon + printed_name
    else
      icon + link_to_if(!opt[:no_link], printed_name, user_show_path(user))
    end
  end

  def package_link(pack, opts = {})
    opts[:project] = pack.project.name
    opts[:package] = pack.name
    project_or_package_link opts
  end

  def link_to_package(prj, pkg, opts)
    opts[:project_text] ||= opts[:project]
    opts[:package_text] ||= opts[:package]

    opts[:project_text], opts[:package_text] =
        elide_two(opts[:project_text], opts[:package_text], opts[:trim_to]) unless opts[:trim_to].nil?

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
    project_text = opts[:trim_to].nil? ? opts[:project_text] : elide(opts[:project_text], opts[:trim_to])
    out + link_to_if(prj, project_text,
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
        pkg = prj.packages.where(name: opts[:package]).select(:id, :name, :project_id).first
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

    Rails.cache.fetch([user, 'realname_and_icon', opts, ::Configuration.first]) do
      realname = user.realname

      if opts[:short] || realname.empty?
        printed_name = user.login
      else
        printed_name = "#{realname} (#{user.login})"
      end

      user_icon(user) + ' ' + link_to_if(!opts[:no_link], printed_name,
                                         user_show_path(user))
    end
  end

  # If there is any content add the ul tag
  def possibly_empty_ul(html_opts, &block)
    content = capture(&block)
    if content.blank?
      html_opts[:fallback]
    else
      html_opts.delete :fallback
      content_tag(:ul, content, html_opts)
    end
  end

  def can_register
    return true if User.current.try(:is_admin?)

    begin
      UnregisteredUser.can_register?
    rescue APIException
      return false
    end
    true
  end

  def escape_nested_list(list)
    # The input list is not html_safe because it's
    # user input which we should never trust!!!
    list.map { |item|
      "['".html_safe +
      escape_javascript(item[0]) +
      "', '".html_safe +
      escape_javascript(item[1]) +
      "']".html_safe
    }.join(",\n").html_safe
  end

  def replace_jquery_meta_characters(input)
    # The stated characters are c&p from https://api.jquery.com/category/selectors/
    input.gsub(/[!"#$%&'()*+,.\/:\\;<=>?@\[\]^`{|}~]/, '_')
  end

  def word_break(string, length)
    # adds a <wbr> tag after an amount of given characters
    safe_join(string.scan(/.{1,#{length}}/), "<wbr>".html_safe)
  end
end
