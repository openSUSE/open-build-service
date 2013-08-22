class Webui::SubscriptionsController < Webui::BaseController

  def custom_relation(relation)
    if @project
      if @package
        relation = relation.where(package: Package.get_by_project_and_name(@project, @package))
      else
        relation = relation.where(project: Project.get_by_name(@project))
      end
    else
      relation = relation.where("project_id is null and package_id is null")
    end
    relation
  end

  def set_receive(rule)
    logger.debug rule.inspect
    @subscriptions[rule.eventtype]['receive'] = rule.receive
  end

  # recursivly adding events
  def set_subclasses(et)
    subclasses = et.subclasses.map { |c| c.name }.sort
    @subscriptions[et.name] = {receive: 'none', description: et.description,
                               subclasses: subclasses}
    et.subclasses.each do |sc|
      set_subclasses(sc)
    end
  end

  def index
    @project = params[:project_id]
    @package = params[:package_id]

    defaults = custom_relation(EventSubscription.where("user_id is null"))
    userrules = custom_relation(EventSubscription.where(user: User.current))

    @subscriptions = {}
    Event.subclasses.each { |sc| set_subclasses(sc) }

    defaults.each { |rule| set_receive(rule) }
    userrules.each { |rule| set_receive(rule) }

    render json: @subscriptions
  end

  def create
    be_not_nobody!

    required_parameters :event, :receive

    @project = params[:project_id]
    @package = params[:package_id]

    userrules = custom_relation(EventSubscription.where(user: User.current))
    userrules = userrules.where(eventtype: params[:event])
    rule = userrules.first
    if rule
      rule.receive = params[:receive]
    else
      rule = userrules.new(receive: params[:receive])
    end
    rule.save!
    render json: {status: 'ok'}
  end
end
