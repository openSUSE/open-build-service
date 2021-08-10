class Project
  class EmbargoHandler
    def initialize(project)
      @project = project
    end

    def embargo_date_attrib_type
      @embargo_date_attrib_type ||= AttribType.find_by_namespace_and_name!('OBS', 'EmbargoDate')
    end

    def embargo_date_attribute
      attribs = @project.attribs.find_by(attrib_type: embargo_date_attrib_type)
      attribs.values.first if attribs.present?
    end

    def embargo_date(embargo_attrib)
      return if embargo_attrib.nil?

      begin
        embargo = Time.parse(embargo_attrib&.value.to_s).utc
        # no time specified, allow it next day
        embargo = embargo.tomorrow if /^\d{4}-\d\d?-\d\d?$/.match?(embargo_attrib.value)
      rescue ArgumentError
        raise BsRequest::Errors::InvalidDate, "Unable to parse the date in OBS:EmbargoDate of project #{@project.name}: #{embargo_attrib}"
      end
      raise BsRequest::Errors::UnderEmbargo, "The project #{@project.name} is under embargo until #{embargo_attrib}" if embargo > Time.now.utc
    end

    def call
      embargo_date(embargo_date_attribute)
    end
  end
end
