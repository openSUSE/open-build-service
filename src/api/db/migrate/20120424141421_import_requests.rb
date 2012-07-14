class ImportRequests < ActiveRecord::Migration
  def up
    return if Rails.env.test?
    backend = ActiveXML::Config.transport_for :directory
    begin
      dir = ActiveXML::XMLNode.new(backend.direct_http( URI( "/request" ) ))
    rescue ActiveXML::Transport::ConnectionError => e
      if Rails.env.development?
        puts "Ignoring errors and skipping migration of requests in development mode\n#{e.inspect}"
	return
      else
        raise e
      end
    end
    reqs = []
    dir.each_entry do |entry|
      reqs << entry.value(:name).to_i if entry.value(:name).to_i > 0
    end if dir
    reqs.sort.each do |req|
      xml = backend.direct_http( URI( "/request/#{req}" ) )
      r = BsRequest.new_from_xml xml
      unless r.save
        puts req, r.errors.full_messages.join("\n")
      end
    end

  end

  def down
    return if Rails.env.test?
    BsRequest.all.each { |r| r.destroy }
  end
end
