class DistributionController < ApplicationController
  DISTFILEPATH = "#{RAILS_ROOT}/files/distributions.xml"
  @@distfile_last_read = Date.new(0).to_time
  @@distfile = ""

  def self.read_distfile
    logger.debug sprintf("mtime: %s\tdistlast: %s", File.stat(DISTFILEPATH).mtime, @@distfile_last_read)
    return @@distfile unless File.stat(DISTFILEPATH).mtime > @@distfile_last_read
    logger.debug "reading distfile from disk"
    @@distfile_last_read = Time.now
    return DISTFILEPATH.exists? ? @@distfile = File.read(DISTFILEPATH) : '<distributions></distributions>'
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

      logger.debug "funz"
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
