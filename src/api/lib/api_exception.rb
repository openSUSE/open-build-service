
class APIException < Exception
  def self.abstract_class?
    true
  end
  
  class << self
    @errorcode = 'internal_server_error'
    @status = 400
    @default_message = nil

    def setup(setvalue, status = 400, message = nil)
      @errorcode = setvalue
      @status = status
      @default_message = message
    end
  end

  def errorcode
    self.class.instance_variable_get "@errorcode"
  end
  
  def status
    self.class.instance_variable_get "@status"
  end
  
  def default_message
    self.class.instance_variable_get "@default_message"
  end

end
