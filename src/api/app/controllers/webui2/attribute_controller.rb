module Webui2::AttributeController
  def webui2_new
    @attribute_types = AttribType.includes(:attrib_namespace).all.sort_by(&:fullname)
  end

  def webui2_edit
    if @attribute.attrib_type.issue_list
      @issue_trackers = IssueTracker.order(:name).all
    end

    @allowed_values = @attribute.attrib_type.allowed_values.map(&:value)
  end
end
