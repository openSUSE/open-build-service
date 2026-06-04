class NotifiedPackages
  def initialize(notification)
    @notification = notification
    @notifiable = notification.notifiable
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def call
    return [] if @notifiable.blank?

    case @notification.notifiable_type
    when 'Package'
      [@notifiable.name]
    when 'Comment'
      case @notifiable.commentable_type
      when 'Package'
        [@notifiable.commentable.name]
      when 'BsRequest'
        package_names_from_request(@notifiable.commentable)
      when 'BsRequestAction'
        package_names_from_request(@notifiable.commentable.bs_request)
      else
        []
      end
    when 'BsRequest'
      package_names_from_request(@notifiable)
    when 'Report'
      @notifiable.reportable.is_a?(Package) ? [@notifiable.reportable.name] : []
    when 'Decision'
      @notifiable.reports.filter_map { |r| r.reportable.name if r.reportable.is_a?(Package) }.uniq
    when 'Appeal'
      @notifiable.decision.reports.filter_map { |r| r.reportable.name if r.reportable.is_a?(Package) }.uniq
    else
      []
    end.compact.uniq
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  private

  def package_names_from_request(bs_request)
    bs_request.bs_request_actions.flat_map do |action|
      [action.source_package, action.target_package]
    end.compact.uniq
  end
end
