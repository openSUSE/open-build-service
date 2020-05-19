require_dependency 'opensuse/validator'

module PackageService
  class SchemaVerifier
    SCHEMAS = ['aggregate', 'constraints', 'link',
               'service', 'patchinfo', 'channel', 'multibuild'].freeze

    def initialize(content:, package:, file_name:)
      @content = content
      @package = package
      @file_name = file_name
    end

    def call
      return unless  allowed_schema? || pattern?
      # if it doesn't validate, exception will be raised
      SCHEMAS.each { |schema| validate_schema!(schema) if schema?(schema) }
      validate_schema!('pattern') if pattern?
    end

    private

    def allowed_schema?
      SCHEMAS.include?(@file_name[1..-1])
    end

    def pattern?
      @package.try(:name) == '_pattern'
    end

    def validate_schema!(schema)
      Suse::Validator.validate(schema, @content)
    end

    def schema?(schema)
      @file_name == "_#{schema}"
    end
  end
end
