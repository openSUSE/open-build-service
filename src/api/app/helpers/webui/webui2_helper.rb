module Webui::Webui2Helper
  def webui2_tab(id, text, opts, link_opts = {})
    opts[:package] = @package.to_s if @package
    opts[:project] = @project.to_s if @project
    link_opts[:id] = "tab-#{id}"
    link_opts[:class] = "nav-link"
    if (action_name == opts[:action].to_s && (opts[:controller].to_s.include? controller_name)) || opts[:selected]
      link_opts[:class] = 'nav-link active'
    end
    content_tag('li', link_to(h(text), opts, link_opts), class: 'nav-item')
  end

  def proceed_link_webui2(image, text, link_opts)
    content_tag(:li,
                link_to(image_tag("icons/" + image, title: text, class: 'mx-auto d-block') + content_tag(:p, text, class: 'mx-auto') , link_opts, class: 'nav-link'), id: "proceed-#{image}", class: 'nav-item')
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
  }.freeze

  REPO_STATUS_DESCRIPTIONS = {
    'published'   => 'Repository has been published',
    'publishing'  => 'Repository is being created right now',
    'unpublished' => 'Build finished, but repository publishing is disabled',
    'building'    => 'Build jobs exists',
    'finished'    => 'Build jobs have been processed, new repository is not yet created',
    'blocked'     => 'No build possible atm, waiting for jobs in other repositories',
    'broken'      => 'The repository setup is broken, build or publish not possible',
    'scheduling'  => 'The repository state is being calculated right now'
  }.freeze

  def check_first(first)
    first.nil? ? true : nil
  end

  def repo_status_icon_webui2(status, details = nil)
    icon = REPO_STATUS_ICONS[status] || 'eye'

    outdated = nil
    if /^outdated_/.match?(status)
      status.gsub!(%r{^outdated_}, '')
      outdated = true
    end

    description = REPO_STATUS_DESCRIPTIONS[status] || 'Unknown state of repository'
    description = 'State needs recalculations, former state was: ' + description if outdated
    description += ' (' + details + ')' if details

    image_tag icon, title: description
  end
end
