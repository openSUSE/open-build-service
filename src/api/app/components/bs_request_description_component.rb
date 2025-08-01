# This component renders the request description based on the type of the actions

class BsRequestDescriptionComponent < ApplicationComponent
  attr_reader :bs_request

  delegate :project_or_package_link, to: :helpers
  delegate :user_with_realname_and_icon, to: :helpers
  delegate :requester_str, to: :helpers
  delegate :creator_intentions, to: :helpers

  def initialize(bs_request:)
    super
    @bs_request = bs_request
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  # rubocop:disable Metrics/BlockLength
  # rubocop:disable Style/FormatString
  def call
    # creator = action.bs_request.creator
    types = bs_request.bs_request_actions.group_by(&:type)
    description = []

    types.each do |type, actions|
      source_packages = actions.map(&:source_package).uniq.map { |a| tag.b(a) }
      source_packages = shorten_list(source_packages)
      source_projects = actions.map(&:source_project).uniq.map { |a| tag.b(a) }
      source_projects = shorten_list(source_projects)
      source_container = if actions.length == 1 && source_packages.length == 1
                           "package #{source_projects.first} / #{source_packages.first}"
                         elsif source_packages
                           "#{'package'.pluralize(source_packages.count)} #{source_packages.to_sentence} from #{'project'.pluralize(source_projects.count)} #{source_projects.to_sentence}"
                         else
                           "#{'project'.pluralize(source_projects.count)} #{source_projects.to_sentence}"
                         end
      source_container = tag.span(sanitize(source_container), data: { bs_toggle: 'popover', bs_content: actions.map { |a| tag.b("#{a.source_project} / #{a.source_package}") }.uniq.to_sentence })

      target_projects = actions.map(&:target_project).uniq.map { |a| tag.b(a) }
      target_projects = shorten_list(target_projects)
      target_container = "#{'project'.pluralize(target_projects.count)} #{target_projects.to_sentence}"
      target_container = tag.span(sanitize(target_container), data: { bs_toggle: 'popover', bs_content: actions.map { |a| tag.b("#{a.target_project} / #{a.target_package}") }.uniq.to_sentence })

      source_and_target_container = [source_container, target_container].join(tag.i(nil, class: 'fas fa-long-arrow-alt-right text-info mx-2'))

      description << case type
                     when 'submit'
                       'Submit %{source_and_target_container}' % { source_and_target_container: source_and_target_container }
                     when 'delete'
                       target = actions.map do |a|
                         string = ''
                         string += "repository #{tag.b(a.target_repository)} for " if a.target_repository
                         string += a.target_package ? 'package ' : 'project '
                         string += "#{tag.b(a.target_project)} "
                         string += "/ #{tag.b(a.target_package)}"
                         string
                       end.to_sentence
                       'Delete %{target}' %
                       { target: target }
                     when 'add_role', 'set_bugowner'
                       'Change role for %{target_container}' % { target_container: target_container }
                     when 'change_devel'
                       'Set %{source_container} to be devel project/package of %{target_container}' %
                       { source_container: source_container, target_container: target_container }
                     when 'maintenance_incident'
                       'Submit update from %{source_and_target_container}' %
                       { source_and_target_container: source_and_target_container }
                     when 'maintenance_release'
                       'Maintenance release %{source_and_target_container}' %
                       { source_and_target_container: source_and_target_container }
                     when 'release'
                       'Release %{source_and_target_container}' %
                       { source_and_target_container: source_and_target_container }
                     end
    end

    # HACK: this is just a porting of the already existing way of passing the string to the view
    # TODO: refactor in order to get rid of the `html_safe` tagging
    sanitize(description.to_sentence)
  end

  private

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
  # rubocop:enable Style/FormatString
end
