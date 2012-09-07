class ImportRequestsDelayedJob

  def initialize
  end

  def perform
    require 'opensuse/backend'

    lastrq =  Suse::Backend.get("/request/_lastid").body.to_i
    while lastrq > 0
      xml = Suse::Backend.get( "/request/#{lastrq}" ).body
      r = BsRequest.new_from_xml xml
      unless r.save
        puts "Request ##{lastrq}:", r.errors.full_messages.join("\n")
      end
      lastrq -= 1
    end

  end

end


