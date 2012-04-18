class ImportRequests < ActiveRecord::Migration
  def up
    backend = ActiveXML::Config.transport_for :directory
    unless Rails.env.test?
      dir = ActiveXML::XMLNode.new(backend.direct_http( URI( "/request" ) ))
    end
    reqs = []
    dir.each_entry do |e|
      reqs << e.value(:name).to_i
    end if dir
    reqs.sort.each do |e|
      xml = backend.direct_http( URI( "/request/#{e}" ) )
      r = BsRequest.new_from_xml xml
      unless r.save
        puts e, r.errors.full_messages.join("\n")
      end
    end

  end

  def down
    return if Rails.env.test?
    BsRequest.all.each { |r| r.destroy }
  end
end
