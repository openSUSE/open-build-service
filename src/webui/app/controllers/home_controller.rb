require 'net/http'

class HomeController < ApplicationController

  before_filter :require_login, :except => [:my_work, :icon]
  before_filter :check_user, :except => [:icon]
  before_filter :overwrite_user, :only => [:index, :my_work, :requests, :list_my]

  def index
  end

  def icon
    user = params[:id]
    size = params[:size] || '20'
    key = "home_face_#{user}_#{size}"
    Rails.cache.delete(key) if discard_cache?
    content = Rails.cache.fetch(key, :expires_in => 5.hour) do

      unless CONFIG['use_gravatar'] == :off
        email = Person.email_for_login(user)
        hash = Digest::MD5.hexdigest(email.downcase)
        http = nil
        proxyuri = ENV['http_proxy']
        proxyuri = CONFIG['http_proxy'] unless CONFIG['http_proxy'].blank?
        if proxyuri
          proxy = URI.parse(proxyuri)
          proxy_user, proxy_pass = proxy.userinfo.split(/:/) if proxy.userinfo
          http = Net::HTTP::Proxy(proxy.host, proxy.port, proxy_user, proxy_pass).new("www.gravatar.com")
        else
          http = Net::HTTP.new("www.gravatar.com")
        end
        begin
          http.start
          response = http.get "/avatar/#{hash}?s=#{size}&d=wavatar" unless Rails.env.test?
          if response.is_a?(Net::HTTPSuccess)
            content = response.body
          end
        rescue SocketError, Errno::EINTR, Errno::EPIPE, EOFError, Net::HTTPBadResponse, IOError, Errno::ETIMEDOUT, Errno::ECONNREFUSED => err
          logger.debug "#{err} when fetching http://www.gravatar.com/avatar/#{hash}?s=#{size}"
          http = nil
        end
        http.finish if http
      end

      unless content
        #TODO/FIXME: Looks like an asset...
        f = File.open("#{Rails.root}/app/assets/images/default_face.png", "r")
        content = f.read
        f.close
      end
      content.force_encoding("ASCII-8BIT")
    end

    render :text => content, :layout => false, :content_type => "image/png"
  end

  def my_work
    unless @displayed_user
      require_login 
      return
    end
    @requests = @displayed_user.requests_that_need_work
    @declined_requests = BsRequest.ids(@requests['declined'])
    @open_reviews = BsRequest.ids(@requests['reviews'])
    @new_requests = BsRequest.ids(@requests['new'])
    @open_patchinfos = @displayed_user.running_patchinfos(:cache => false)
    
    logger.debug @new_requests.inspect

    session[:requests] = (@declined_requests + @open_reviews  + @new_requests)
    respond_to do |format|
      format.html
      format.json do
        rawdata = Hash.new
        rawdata["declined"] = @declined_requests
        rawdata["review"] = @open_reviews
        rawdata["new"] = @new_requests
        rawdata["patchinfos"] = @open_patchinfos
        render :text => JSON.pretty_generate(rawdata)
      end
    end
  end

  def requests
    session[:requests] = ApiDetails.find(:person_involved_requests, login: @displayed_user.login)
    @requests =  BsRequest.ids(session[:requests])
  end

  def home_project
    redirect_to :controller => :project, :action => :show, :project => "home:#{@user}"
  end

  def list_my
    @displayed_user.free_cache if discard_cache?
    @iprojects = @displayed_user.involved_projects.each.map {|x| x.name}.uniq.sort
    @ipackages = Hash.new
    pkglist = @displayed_user.involved_packages.each.reject {|x| @iprojects.include?(x.project)}
    pkglist.sort(&@displayed_user.method('packagesorter')).each do |pack|
      @ipackages[pack.project] ||= Array.new
      @ipackages[pack.project] << pack.name if !@ipackages[pack.project].include? pack.name
    end
  end

  def remove_watched_project
    logger.debug "removing watched project '#{params[:project]}' from user '#@user'"
    @user.remove_watched_project(params[:project])
    @user.save
    render :partial => 'watch_list'
  end

  def overwrite_user
    @displayed_user = @user
    user = find_cached(Person, params['user'] ) if params['user'] && !params['user'].empty?
    @displayed_user = user if user
  end
  private :overwrite_user
end
