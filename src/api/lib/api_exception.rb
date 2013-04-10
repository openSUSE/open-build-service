
class APIException < Exception
  def self.abstract_class?
    true
  end
  
  class << self
    @errorcode = nil
    @status = 400
    @default_message = nil

    def setup(setvalue, status = nil, message = nil)
      if setvalue.is_a? String
        @errorcode = setvalue
        @status = status || 400
        @default_message = message
      else # support having the status first
        @status = setvalue
        @default_message = status
      end
    end
  end

  def errorcode
    err = self.class.instance_variable_get "@errorcode"
    err || self.class.name.split('::').last.underscore
  end
  
  def status
    self.class.instance_variable_get "@status"
  end
  
  def default_message
    self.class.instance_variable_get "@default_message"
  end

end
