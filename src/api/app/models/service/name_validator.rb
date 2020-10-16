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
      return false unless name.is_a?(String)
      return false if name.length > 200 || name.blank?
      return false if /^[_.]/.match?(name)
      return false if /::/.match?(name)
      return true if /\A\w[-+\w.:]*\z/.match?(name)

      false
    end
  end
end
