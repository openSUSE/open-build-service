module PackageService
  class FileVerifier
    attr_accessor :package, :file_name

    def initialize(package:, file_name:, content:)
      @package = package
      @content = content
      @content_data = nil
      @file_name = file_name
    end

    def call
      # Prohibit dotfiles (files with leading .) and files with a / character in the name
      raise Package::IllegalFileName, "'#{@file_name}' is not a valid filename" if file_name_invalid?

      # defer call to content until the validator calls to_s on the proc
      defer_content = proc { content }
      defer_content.define_singleton_method(:to_s) { call }
      PackageService::SchemaVerifier.new(content: defer_content, package: @package, file_name: @file_name).call
      PackageService::LinkVerifier.new(content: content, package: @package).call if link? && content.present?
      # special checks in their models
      Service.verify_xml!(content) if service?
      Channel.verify_xml!(content) if channel?
      Patchinfo.new.verify_data(@package.project, content) if patchinfo?
    end

    private

    def content
      @content_data ||= begin
        data = @content.is_a?(ActionDispatch::Http::UploadedFile) ? File.open(@content.path) : @content
        data = data.read if data.respond_to?(:read)
        data
      end
    end

    def file_name_invalid?
      @file_name.blank? || @file_name !~ /^[^.\/][^\/]+$/
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
