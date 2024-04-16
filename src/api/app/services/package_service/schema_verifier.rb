module PackageService
  class SchemaVerifier
    SCHEMAS = %w[aggregate constraints link
                 service patchinfo channel multibuild pattern].freeze

    def initialize(content:, package:, file_name:)
      @content = content
      @package = package
      @file_name = file_name
    end

    def call
      return unless allowed_schema?

      # if it doesn't validate, exception will be raised
      SCHEMAS.each { |schema| validate_schema!(schema) if schema?(schema) }
    end

    private

    def allowed_schema?
      schema = pattern? ? @package.try(:name) : @file_name
      SCHEMAS.include?(schema[1..])
    end

    def pattern?
      @package.try(:name) == '_pattern'
    end

    def validate_schema!(schema)
      Suse::Validator.validate(schema, @content)
    end

    def schema?(schema)
      pattern? ? @package.try(:name) == "_#{schema}" : @file_name == "_#{schema}"
    end
  end
end
