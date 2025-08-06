# This component renders the request description based on the type of the actions

class BsRequestDescriptionComponent < ApplicationComponent
  attr_reader :bs_request

  delegate :project_or_package_link, to: :helpers
  delegate :user_with_realname_and_icon, to: :helpers
  delegate :requester_str, to: :helpers
  delegate :creator_intentions, to: :helpers

  def initialize(bs_request:, links: false)
    super
    @bs_request = bs_request
    @links = links
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  # rubocop:disable Metrics/BlockLength
  def call
    # creator = action.bs_request.creator
    types = bs_request.bs_request_actions.group_by(&:type)
    description = []

    types.each do |type, actions|
      source_packages = actions.map { |a| [a.source_project, a.source_package] }.uniq.map { |pr, pk| highlight_package(pr, pk) }
      source_packages = shorten_list(source_packages)
      source_projects = actions.map(&:source_project).uniq.map { |a| highlight_project(a) }
      source_projects = shorten_list(source_projects)
      source_container = if actions.length == 1 && source_packages.length == 1
                           "package #{source_projects.first} / #{source_packages.first}"
                         elsif source_packages
                           "#{'package'.pluralize(source_packages.count)} #{source_packages.to_sentence} from #{'project'.pluralize(source_projects.count)} #{source_projects.to_sentence}"
                         else
                           "#{'project'.pluralize(source_projects.count)} #{source_projects.to_sentence}"
                         end
      source_container = tag.span(sanitize(source_container), data: { bs_toggle: 'popover', bs_content: actions.map { |a| tag.b("#{a.source_project} / #{a.source_package}") }.uniq.to_sentence })

      target_projects = actions.map(&:target_project).uniq.map { |a| highlight_project(a) }
      target_projects = shorten_list(target_projects)
      target_container = if actions.length == 1 && actions.first.target_package
                           "package #{highlight_project(actions.first.target_project)} / #{highlight_package(actions.first.target_project, actions.first.target_package)}"
                         elsif actions.any?(&:target_package)
                           "#{'package'.pluralize(actions.filter_map(&:target_package).uniq.count)} in #{'project'.pluralize(target_projects.count)} #{target_projects.to_sentence}"
                         else
                           "#{'project'.pluralize(target_projects.count)} #{target_projects.to_sentence}"
                         end
      target_container = tag.span(sanitize(target_container), data: { bs_toggle: 'popover', bs_content: actions.map { |a| tag.b("#{a.target_project} / #{a.target_package}") }.uniq.to_sentence })

      source_and_target_container = [source_container, target_container].join(tag.i(nil, class: 'fas fa-long-arrow-alt-right text-info mx-2'))

      description << case type
                     when 'submit'
                       "Submit #{source_and_target_container}"
                     when 'delete'
                       target = actions.map do |a|
                         string = ''
                         string += "repository #{tag.b(a.target_repository)} for " if a.target_repository
                         string += a.target_package ? 'package ' : 'project '
                         string += "#{highlight_project(a.target_project)} "
                         string += "/ #{highlight_package(a.target_project, a.target_package)}" if a.target_package
                         string
                       end.to_sentence
                       "Delete #{target}"
                     when 'add_role', 'set_bugowner'
                       target = actions.map do |a|
                         "#{a.person_name ? 'user' : 'group'} #{highlight_user(a.person_name)} #{highlight_group(a.group_name)} as #{a.type == 'set_bugowner' ? "the #{tag.b('bugowner')}" : "a #{tag.b(a.role)}"}"
                       end
                       target = shorten_list(target)
                       "Assign #{target.to_sentence} for #{target_container}"
                     when 'change_devel'
                       "Set #{source_container} to be #{tag.b('devel')} project/package of #{target_container}"
                     when 'maintenance_incident'
                       "Submit update from #{source_and_target_container}"
                     when 'maintenance_release'
                       "Maintenance release #{source_and_target_container}"
                     when 'release'
                       "Release #{source_and_target_container}"
                     end
    end

    # HACK: this is just a porting of the already existing way of passing the string to the view
    # TODO: refactor in order to get rid of the `html_safe` tagging
    sanitize(description.to_sentence)
  end

  private

  def highlight_project(project)
    return unless project
    return tag.b(project) unless @links

    link_to(project, project_show_path(project))
  end

  def highlight_package(project, package)
    return unless project && package
    return tag.b(package) unless @links

    link_to(package, package_show_path(project, package))
  end

  def highlight_user(user)
    return unless user
    return tag.b(user) unless @links

    link_to(user, user_path(user))
  end

  def highlight_group(group)
    return unless group
    return tag.b(group) unless @links

    link_to(group, group_path(group))
  end

  def shorten_list(array, limit = 3)
    if array.count > limit
      total = array.count - (limit - 1)
      array = array.take(limit - 1)
      array << "#{total} #{'other'.pluralize(total)}"
    end
    array
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/BlockLength
end
