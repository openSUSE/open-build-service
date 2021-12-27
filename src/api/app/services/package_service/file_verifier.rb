module PackageService
  class FileVerifier
    attr_accessor :package, :file_name, :content

    def initialize(package:, file_name:, content:)
      @package = package
      @content = content_readable(content)
      @file_name = file_name
    end

    def call
      # Prohibit dotfiles (files with leading .) and files with a / character in the name
      raise Package::IllegalFileName, "'#{@file_name}' is not a valid filename" if file_name_invalid?

      PackageService::SchemaVerifier.new(content: @content, package: @package, file_name: @file_name).call
      PackageService::LinkVerifier.new(content: @content, package: @package).call if link? && @content.present?
      # special checks in their models
      Service.verify_xml!(@content) if service?
      Channel.verify_xml!(@content) if channel?
      Patchinfo.new.verify_data(@package.project, @content) if patchinfo?
    end

    private

    def content_readable(content)
      content.is_a?(ActionDispatch::Http::UploadedFile) ? File.read(content.path) : content
    end

    def file_name_invalid?
      @file_name.blank? || @file_name !~ %r{^[^./][^/]+$}
    end

    def service?
      @file_name == '_service'
    end

    def channel?
      @file_name == '_channel'
    end

    def patchinfo?
      @file_name == '_patchinfo'
    end

    def link?
      @file_name == '_link'
    end
  end
end
