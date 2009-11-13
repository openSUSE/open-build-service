module BackgrounDRb
  class Result
    def initialize results
      @results = resuls
    end

    def async_response?
      !(@results[:result] == true)
    end

    def sync_response?
      (@results[:result] == true)
    end

    def error?
      !(@results[:result_flag] == "ok")
    end
  end
end
