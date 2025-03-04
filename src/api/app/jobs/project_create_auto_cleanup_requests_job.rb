class ProjectCreateAutoCleanupRequestsJob < ApplicationJob
  DESCRIPTION = "This is a humble request to remove this project.
Accepting this request will free resources on our always crowded server.
Please decline this request if you want to keep this repository nevertheless. Otherwise this request
will get accepted automatically in near future.
These requests are not created for projects with open requests or if you remove the OBS:AutoCleanup attribute.".freeze

  class CleanupRequestTemplate
    attr_accessor :project, :description, :cleanup_time

    def initialize(project:, description:, cleanup_time:)
      @project = project
      @description = description
      @cleanup_time = cleanup_time
      @erb = ERB.new(template)
    end

    def template
      <<~XML
        <request>
          <action type="delete"><target project="<%= project %>"/></action>
          <description><%= description %></description>
          <state name="new" />
          <accept_at><%= cleanup_time %></accept_at>
        </request>
      XML
    end

    def render
      @erb.result(binding)
    end
  end

  def perform
    # disabled ?
    cleanup_days = ::Configuration.cleanup_after_days
    return unless cleanup_days && cleanup_days.positive?

    # defaults
    User.default_admin.run_as do
      @cleanup_attribute = AttribType.find_by_namespace_and_name!('OBS', 'AutoCleanup')
      @cleanup_time = Time.zone.now + cleanup_days.days

      Project.joins(:attribs).where(attribs: { attrib_type_id: @cleanup_attribute.id }).find_each do |prj|
        autoclean_project(prj)
      end
    end
  end

  private

  def autoclean_project(prj)
    return unless project_ready_to_autoclean?(prj)

    begin
      attribute = prj.attribs.find_by_attrib_type_id(@cleanup_attribute.id)
      return unless attribute

      time = Date.parse(attribute.values.first.value)
    rescue TypeError, ArgumentError
      # nil time raises TypeError
      return
    end
    # not yet
    return unless time.past?

    # create request, but add some time between to avoid an overload
    @cleanup_time += 5.minutes

    req = create_request(project: prj.name, cleanup_time: @cleanup_time)
    req.save!
    Event::RequestCreate.create(req.event_parameters)
  end

  def create_request(project:, description: DESCRIPTION, cleanup_time: 5)
    BsRequest.new_from_xml(CleanupRequestTemplate.new(project: project,
                                                      description: description,
                                                      cleanup_time: cleanup_time).render)
  end

  def project_ready_to_autoclean?(project)
    # project may be locked?
    return false if project.locked?
    # open requests do block the cleanup
    return false if open_requests_count(project.name).positive?
    return false unless project.check_weak_dependencies?

    true
  end

  def open_requests_count(project_name)
    OpenRequestsWithProjectAsSourceOrTargetFinder.new(relation, project_name).call.count
  end

  def relation
    BsRequest.where(state: %i[new review declined])
             .joins(:bs_request_actions)
  end
end
