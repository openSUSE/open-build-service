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

      value = embargo_attrib.value

      embargo = parse_value(value)

      check_timezone_identifier(value)

      # no time specified, allow it next day
      embargo = embargo.tomorrow if /^\d{4}-\d\d?-\d\d?$/.match?(value)

      raise BsRequest::Errors::UnderEmbargo, "The project #{@project.name} is under embargo until #{embargo_attrib}" if embargo > Time.now.utc
    end

    def call
      embargo_date(embargo_date_attribute)
    end

    private

    def check_timezone_identifier(value)
      # Check for a valid timezone identifier
      if value =~ /\A\d{4}-\d\d?-\d\d?(\s|T)\d\d?:\d\d?(:\d\d?)?\s(.+)\Z/ &&  # whole string matches 'YYYY-MM-DD HH:MM:SS TZ' and
         (timezone = Regexp.last_match(3)) !~ /(\+|-)\d\d?(:\d\d?)?/          # timezone part doesn't match '+-HH:MM'
        begin
          TZInfo::Timezone.get(timezone)
        rescue TZInfo::InvalidTimezoneIdentifier
          raise BsRequest::Errors::InvalidDate, "Unable to parse the timezone in OBS:EmbargoDate of project #{@project.name}: #{value}"
        end
      end
    end

    def parse_value(value)
      begin
        parsed_value = Time.zone.parse(value)
      rescue ArgumentError
        raise BsRequest::Errors::InvalidDate, "Unable to parse the date in OBS:EmbargoDate of project #{@project.name}: #{value}"
      end

      raise BsRequest::Errors::InvalidDate, "Unable to parse the date in OBS:EmbargoDate of project #{@project.name}: #{value}" if parsed_value.nil?

      parsed_value
    end
  end
end
