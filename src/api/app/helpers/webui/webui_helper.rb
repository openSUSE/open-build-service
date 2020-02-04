# rubocop:disable Metrics/ModuleLength
module Webui::WebuiHelper
  include ActionView::Helpers::JavaScriptHelper
  include ActionView::Helpers::AssetTagHelper
  include Webui::BuildresultHelper

  def bugzilla_url(email_list = '', desc = '')
    return '' if @configuration['bugzilla_url'].blank?
    assignee = email_list.first if email_list
    if email_list.length > 1
      cc = ('&cc=' + email_list[1..-1].join('&cc=')) if email_list
    end

    URI.escape(
      "#{@configuration['bugzilla_url']}/enter_bug.cgi?classification=7340&product=openSUSE.org" \
      "&component=3rd party software&assigned_to=#{assignee}#{cc}&short_desc=#{desc}"
    )
  end

  def fuzzy_time(time, with_fulltime = true)
    if Time.now - time < 60
      return 'now' # rails' 'less than a minute' is a bit long
    end

    human_time_ago = time_ago_in_words(time) + ' ago'

    if with_fulltime
      raw("<span title='#{l(time.utc)}' class='fuzzy-time'>#{human_time_ago}</span>")
    else
      human_time_ago
    end
  end

  def fuzzy_time_string(timestring)
    fuzzy_time(Time.parse(timestring), false)
  end

  def format_projectname(prjname, login)
    splitted = prjname.split(':', 3)
    if splitted[0] == 'home'
      if login && splitted[1] == login
        prjname = '~'
      else
        prjname = "~#{splitted[1]}"
      end
      prjname += ":#{splitted[-1]}" if splitted.length > 2
    end
    prjname
  end

  REPO_STATUS_ICONS = {
    'published' => 'truck',
    'outdated_published' => 'truck',
    'publishing' => 'truck-loading',
    'outdated_publishing' => 'truck-loading',
    'unpublished' => 'dolly-flatbed',
    'outdated_unpublished' => 'dolly-flatbed',
    'building' => 'cog',
    'outdated_building' => 'cog',
    'finished' => 'check',
    'outdated_finished' => 'check',
    'blocked' => 'lock',
    'outdated_blocked' => 'lock',
    'broken' => 'exclamation-triangle',
    'outdated_broken' => 'exclamation-triangle',
    'scheduling' => 'calendar-alt',
    'outdated_scheduling' => 'calendar-alt'
  }.freeze

  REPO_STATUS_DESCRIPTIONS = {
    'published' => 'Repository has been published',
    'publishing' => 'Repository is being created right now',
    'unpublished' => 'Build finished, but repository publishing is disabled',
    'building' => 'Build jobs exists',
    'finished' => 'Build jobs have been processed, new repository is not yet created',
    'blocked' => 'No build possible atm, waiting for jobs in other repositories',
    'broken' => 'The repository setup is broken, build or publish not possible',
    'scheduling' => 'The repository state is being calculated right now'
  }.freeze

  def repo_status_description(status)
    REPO_STATUS_DESCRIPTIONS[status] || 'Unknown state of repository'
  end

  def repo_status_icon(status)
    REPO_STATUS_ICONS[status] || 'eye'
  end

  def check_first(first)
    first.nil? ? true : nil
  end

  def image_template_icon(template)
    default_icon = image_url('icons/drive-optical-48.png')
    icon = template.public_source_path('_icon') if template.has_icon?
    capture_haml do
      haml_tag(:object, data: icon || default_icon, type: 'image/png', title: template.title, width: 32, height: 32) do
        haml_tag(:img, src: default_icon, alt: template.title, width: 32, height: 32)
      end
    end
  end

  def repository_status_icon(status:, details: nil, html_class: '')
    outdated = status.sub!(/^outdated_/, '')
    description = outdated ? 'State needs recalculations, former state was: ' : ''
    description << repo_status_description(status)
    description << " (#{details})" if details

    repo_state_class = repository_state_class(outdated, status)

    content_tag(:i, '', class: "repository-state-#{repo_state_class} #{html_class} fas fa-#{repo_status_icon(status)}",
                        data: { content: description, placement: 'top', toggle: 'popover' })
  end

  def repository_state_class(outdated, status)
    return 'outdated' if outdated
    return status =~ /broken|building|finished|publishing|published/ ? status : 'default'
  end

  # Shortens a text if it longer than 'length'.
  def elide(text, length = 20, mode = :middle)
    shortened_text = text.to_s # make sure it's a String

    return '' if text.blank?

    return '...' if length <= 3 # corner case

    if text.length > length
      case mode
      when :left # shorten at the beginning
        shortened_text = '...' + text[text.length - length + 3..text.length]
      when :middle # shorten in the middle
        pre = text[0..length / 2 - 2]
        offset = 2 # depends if (shortened) length is even or odd
        offset = 1 if length.odd?
        post = text[text.length - length / 2 + offset..text.length]
        shortened_text = pre + '...' + post
      when :right # shorten at the end
        shortened_text = text[0..length - 4] + '...'
      end
    end
    shortened_text
  end

  def elide_two(text1, text2, overall_length = 40, mode = :middle)
    half_length = overall_length / 2
    text1_free = half_length - text1.to_s.length
    text1_free = 0 if text1_free < 0
    text2_free = half_length - text2.to_s.length
    text2_free = 0 if text2_free < 0
    [elide(text1, half_length + text2_free, mode), elide(text2, half_length + text1_free, mode)]
  end

  def force_utf8_and_transform_nonprintables(text)
    return '' if text.blank?
    text.force_encoding('UTF-8')
    unless text.valid_encoding?
      text = 'The file you look at is not valid UTF-8 text. Please convert the file.'
    end
    # Ged rid of stuff that shouldn't be part of PCDATA:
    text.gsub(/([^a-zA-Z0-9&;<>\/\n \t()])/) do
      if Regexp.last_match(1)[0].getbyte(0) < 32
        ''
      else
        Regexp.last_match(1)
      end
    end
  end

  def sprite_tag(icon, opts = {})
    if opts.key?(:class)
      opts[:class] += " icons-#{icon}"
    else
      opts[:class] = "icons-#{icon}"
    end
    unless opts.key?(:alt)
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
    return @codemirror_editor_setup = 0 unless @codemirror_editor_setup
    @codemirror_editor_setup += 1
  end

  def codemirror_style(opts = {})
    opts.reverse_merge!(read_only: false, no_border: false, width: 'auto', height: 'auto')

    style = ".CodeMirror {\n"
    style += "border-width: 0 0 0 0;\n" if opts[:no_border] || opts[:read_only]
    style += "height: #{opts[:height]};\n" unless opts[:height] == 'auto'
    style += "width: #{opts[:width]}; \n" unless opts[:width] == 'auto'
    style + "}\n"
  end

  def package_link(pack, opts = {})
    opts[:project] = pack.project.name
    opts[:package] = pack.name
    project_or_package_link(opts)
  end

  def link_to_package(prj, pkg, opts)
    opts[:project_text] ||= opts[:project]
    opts[:package_text] ||= opts[:package]

    unless opts[:trim_to].nil?
      opts[:project_text], opts[:package_text] =
        elide_two(opts[:project_text], opts[:package_text], opts[:trim_to])
    end

    if opts[:short]
      out = ''.html_safe
    else
      out = 'package '.html_safe
    end

    opts[:short] = true # for project
    out += link_to_project(prj, opts) + ' / ' +
           link_to_if(pkg, opts[:package_text],
                      { controller: '/webui/package', action: 'show',
                        project: opts[:project],
                        package: opts[:package] }, class: 'package', title: opts[:package])
    if opts[:rev] && pkg
      out += ' ('.html_safe +
             link_to("revision #{elide(opts[:rev], 10)}",
                     { controller: '/webui/package', action: 'show',
                       project: opts[:project], package: opts[:package], rev: opts[:rev] },
                     class: 'package', title: opts[:rev]) + ')'.html_safe
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
                     { controller: '/webui/project', action: 'show', project: opts[:project] },
                     class: 'project', title: opts[:project])
  end

  def project_or_package_link(opts)
    defaults = { package: nil, rev: nil, short: false, trim_to: 40 }
    opts = defaults.merge(opts)

    # only care for database entries
    prj = Project.where(name: opts[:project]).select(:id, :name, :updated_at).first
    # Expires in 2 hours so that changes of local and remote packages eventually result in an update
    Rails.cache.fetch(['project_or_package_link', prj.try(:id), opts], expires_in: 2.hours) do
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

  def creator_intentions(role = nil)
    role.blank? ? 'become bugowner (previous bugowners will be deleted)' : "get the role #{role}"
  end

  def can_register
    return false if CONFIG['kerberos_mode']
    return true if User.admin_session?

    begin
      UnregisteredUser.can_register?
    rescue APIError
      return false
    end
    true
  end

  def replace_jquery_meta_characters(input)
    # The stated characters are c&p from https://api.jquery.com/category/selectors/
    input.gsub(/[!"#$%&'()*+,.\/:\\;<=>?@\[\]^`{|}~]/, '_')
  end

  def word_break(string, length = 80)
    return '' unless string
    # adds a <wbr> tag after an amount of given characters
    safe_join(string.scan(/.{1,#{length}}/), '<wbr>'.html_safe)
  end

  def toggle_sliced_text(text, slice_length = 50, id = "toggle_sliced_text_#{Time.now.to_f.to_s.delete('.')}")
    return text if text.to_s.length < slice_length
    javascript_toggle_code = "$(\"[data-toggle-id='".html_safe + id + "']\").toggle();".html_safe
    short = content_tag(:span, 'data-toggle-id' => id) do
      content_tag(:span, text.slice(0, slice_length) + ' ') +
        link_to('[+]', 'javascript:void(0)', onclick: javascript_toggle_code)
    end
    long = content_tag(:span, 'data-toggle-id' => id, :style => 'display: none;') do
      content_tag(:span, text + ' ') +
        link_to('[-]', 'javascript:void(0)', onclick: javascript_toggle_code)
    end
    short + long
  end

  def tab_link(label, path, active = false, permit = true)
    html_class = 'nav-link text-nowrap'
    html_class << ' active' if active || (request.path.include?(path) && permit)

    link_to(label, path, class: html_class)
  end

  def image_tag_for(object, size: 500, custom_class: 'img-fluid')
    return unless object
    alt = "#{object.name}'s avatar"
    image_tag(gravatar_icon(object.email, size), alt: alt, size: size, title: object.name, class: custom_class)
  end

  def gravatar_icon(email, size)
    if ::Configuration.gravatar && email
      "https://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(email.downcase)}?s=#{size}&d=robohash"
    else
      'default_face.png'
    end
  end

  def home_title
    @configuration ? @configuration['title'] : 'Open Build Service'
  end

  def pick_max_problems(remaining_checks, remaining_build_problems, max_shown)
    show_checks = [max_shown, remaining_checks.length].min
    show_builds = [max_shown - show_checks, remaining_build_problems.length].min
    # always prefer one build fail
    if show_builds == 0 && remaining_build_problems.present?
      show_builds += 1
      show_checks -= 1
    end

    checks = remaining_checks.shift(show_checks)
    build_problems = remaining_build_problems.shift(show_builds)
    return checks, build_problems, remaining_checks, remaining_build_problems
  end

  # responsive_ux:
  def access_params
    return proxy_params if CONFIG['proxy_auth_mode'] == :on
    no_proxy_params
  end

  # responsive_ux:
  def proxy_params
    { sign_up_url: "#{CONFIG['proxy_auth_register_page']}?%22",
      form_url: CONFIG['proxy_auth_login_page'],
      options: { method: :post,
                 enctype: 'application/x-www-form-urlencoded' },
      proxy: true,
      can_sign_up: CONFIG['proxy_auth_register_page'].present? }
  end

  # responsive_ux:
  def no_proxy_params
    { sign_up_url: signup_path,
      form_url: session_path,
      options: { method: :post },
      proxy: false,
      can_sign_up: can_register }
  end

  # responsive_ux:
  def flipper_responsive?
    Flipper.enabled?(:responsive_ux, User.possibly_nobody)
  end

  # responsive_ux:
  def responsive_namespace
    flipper_responsive? ? 'webui/responsive_ux' : 'webui'
  end
end
# rubocop:enable Metrics/ModuleLength
