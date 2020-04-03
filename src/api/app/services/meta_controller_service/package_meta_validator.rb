module MetaControllerService
  class PackageMetaValidator
    attr_reader :project, :package, :request_data, :errors

    def initialize(params = {})
      @project = params[:project]
      @package = params[:package]
      @request_data = params[:request_data]
      @errors = []
    end

    def call
      @errors << 'admin rights are required to raise the protection level of a package' if sourceaccess_disable?
      @errors << 'project name in xml data does not match resource path component' if valid_xml_project?
      @errors << 'package name in xml data does not match resource path component' if valid_xml_package?
      @errors << 'More than one bugowner found. Only one bugowner can be set.' if more_than_one_bugowner?
    end

    def valid?
      @errors.empty?
    end

    private

    def sourceaccess_disable?
      FlagHelper.xml_disabled_for?(@request_data, 'sourceaccess')
    end

    def valid_xml_project?
      @request_data['project'] && @request_data['project'] != @project.name
    end

    def valid_xml_package?
      @request_data['name'] && @request_data['name'] != @package.name
    end

    def more_than_one_bugowner?
      @request_data.elements('person').select { |person| person['role'] == 'bugowner' }.size > 1
    end
  end
end
