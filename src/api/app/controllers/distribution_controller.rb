class DistributionController < ApplicationController
  DISTFILEPATH = "#{RAILS_ROOT}/files/distributions.xml"
  @@distfile_last_read = Date.new(0).to_time
  @@distfile = "<distributions>\n</distributions>\n"

  def self.read_distfile
    begin
      stat_result = File.stat(DISTFILEPATH)
      logger.debug sprintf("mtime: %s\tdistlast: %s", stat_result.mtime, @@distfile_last_read)
      return @@distfile unless stat_result.mtime > @@distfile_last_read
      logger.debug "reading distfile from disk"
      @@distfile_last_read = Time.now
      @@distfile = File.read(DISTFILEPATH)
    rescue => e
      logger.error "reading the distfile ('#{DISTFILEPATH}') from disk failed: #{e}"
      logger.error "returning default value"
      @@distfile = "<distributions>\n</distributions>\n"
    end
    return @@distfile
  end

  def self.write_distfile(str)
    logger.debug "writing distfile to #{DISTFILEPATH}"
    File.open(DISTFILEPATH,"w") do |file|
      file << str
    end
    @distfile = str
    @distfile_last_read = Time.now
    return true
  end

  def index
    valid_http_methods :get, :put
    if request.get?
      render :text => distfile, :content_type => "text/xml"
    elsif request.put?
      unless @http_user.is_admin?
        render_error :status => 403, :errorcode => "no_permission", :message => "no permission to modify distributions"
        return
      end

      logger.debug "write distribution file"
      self.class.write_distfile(request.raw_post)
      render_ok
    end
  end

  def distfile
    self.class.read_distfile
  end

  def distfile=(str)
    self.class.write_distfile
  end
end
