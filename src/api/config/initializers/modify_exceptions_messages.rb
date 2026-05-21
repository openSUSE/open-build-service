module ActiveRecord
  class RecordNotFound < ActiveRecordError
    def message
      if model == "User"
        "Couldn't find User"
      else
        super
      end
    end
  end
end
