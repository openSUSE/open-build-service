class ImportRequestsDelayedJob
  def initialize
  end

  def perform
    lastrq = Backend::Connection.get("/request/_lastid").body.to_i
    while lastrq > 0
      begin
        xml = Backend::Connection.get( "/request/#{lastrq}" ).body
      rescue ActiveXML::Transport::Error
        lastrq -= 1
        next
      end
      r = BsRequest.new_from_xml xml
      unless r.save
        puts "Request ##{lastrq}:", r.errors.full_messages.join("\n")
      end
      lastrq -= 1
    end
  end
end
