class Service
  class NameValidator
    attr_accessor :name

    def initialize(name)
      @name = name
    end

    def valid?
      valid_name?
    end

    private

    def valid_name?
      return false unless name.present? || name.is_a?(String)
      return false if name.length > 200

      case name
      when /^[_.]/, /::/
        false
      when /\A\w[-+\w.:]*\z/
        true
      else
        false
      end
    end
  end
end
