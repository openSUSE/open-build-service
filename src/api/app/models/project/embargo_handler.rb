class Project
  class EmbargoHandler
    def initialize(project)
      @project = project
    end

    def call
      embargo = embargo_date(embargo_date_attribute)
      raise BsRequest::Errors::UnderEmbargo, "The project #{@project.name} is under embargo until #{embargo}" if embargo.present? && embargo > Time.now.utc
    end

    def embargo_date(attrib_value)
      return if attrib_value.nil?

      value = attrib_value.value

      raise BsRequest::Errors::InvalidDate, "Unable to parse the date in OBS:EmbargoDate of project #{@project.name}: #{value}" unless attrib_value.attrib.valid?

      embargo = Time.zone.parse(value)

      raise BsRequest::Errors::InvalidDate, "Unable to parse the date in OBS:EmbargoDate of project #{@project.name}: #{value}" if embargo.nil?

      # no time specified, allow it next day
      embargo = embargo.tomorrow if /^\d{4}-\d\d?-\d\d?$/.match?(value)

      embargo
    end

    private

    def embargo_date_attrib_type
      @embargo_date_attrib_type ||= AttribType.find_by_namespace_and_name!('OBS', 'EmbargoDate')
    end

    def embargo_date_attribute
      attribs = @project.attribs.find_by(attrib_type: embargo_date_attrib_type)
      attribs.values.first if attribs.present?
    end
  end
end
