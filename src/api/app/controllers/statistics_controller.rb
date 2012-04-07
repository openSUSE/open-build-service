
require 'rexml/document'
require "rexml/streamlistener"

class StatisticsController < ApplicationController

  validate_action :redirect_stats => {:method => :get, :response => :redirect_stats}

  before_filter :get_limit, :only => [
    :highest_rated, :most_active_packages, :most_active_projects, :latest_added, :latest_updated,
    :latest_built, :download_counter
  ]

  # StreamHandler for parsing incoming download_stats / redirect_stats (xml)
  class StreamHandler
    include REXML::StreamListener

    attr_accessor :errors

    def initialize

      # This loads all data, basically makes statistic controller not really usable on a large
      # installation
      @errors = []
      # build hashes for caching id-/name- combinations
      projects = DbProject.find :all, :select => 'id, name'
      packages = DbPackage.find :all, :select => 'id, name, db_project_id'
      repos  =  Repository.find :all, :select => 'id, name, db_project_id'
      archs = Architecture.find :all, :select => 'id, name'
      @project_hash = @package_hash = @repo_hash = @arch_hash = {}
      projects.each { |p| @project_hash[ p.name ] = p.id }
      packages.each { |p| @package_hash[ [ p.name, p.db_project_id ] ] = p.id }
      repos.each { |r| @repo_hash[ [ r.name, r.db_project_id ] ] = r.id }
      archs.each { |a| @arch_hash[ a.name ] = a.id }
    end

    def tag_start name, attrs

      case name
      when 'project'
        @@project_name = attrs['name']
        @@project_id = @project_hash[ attrs['name'] ]
      when 'package'
        @@package_name = attrs['name']
        @@package_id = @package_hash[ [ attrs['name'], @@project_id ] ]
      when 'repository'
        @@repo_name = attrs['name']
        @@repo_id = @repo_hash[ [ attrs['name'], @@project_id ] ]
      when 'arch'
        @@arch_name = attrs['name']
        unless @@arch_id = @arch_hash[ attrs['name'] ]
          # create new architecture entry (db and hash)
          arch = Architecture.new( :name => attrs['name'] )
          arch.save
          @arch_hash[ arch.name ] = arch.id
          @@arch_id = @arch_hash[ arch.name ]
        end
      when 'count'
        @@count = {
          :filename => attrs['filename'],
          :filetype => attrs['filetype'],
          :version => attrs['version'],
          :release => attrs['release'],
          :created_at => attrs['created_at'],
          :counted_at => attrs['counted_at']
        }
      end
    end

    def text( text )

      # ACL(text) TODO: potential security hole
      text.strip!
      return if text == ''
      unless @@project_id and @@package_id and @@repo_id and @@arch_id and @@count
        @errors << {
          :project_id => @@project_id, :project_name => @@project_name,
          :package_id => @@package_id, :package_name => @@package_name,
          :repo_id => @@repo_id, :repo_name => @@repo_name,
          :arch_id => @@arch_id, :arch_name => @@arch_name, :count => @@count
        }
        return
      end

      # lower the log level, prevent spamming the logfile
      old_loglevel = DownloadStat.logger.level
      DownloadStat.logger.level = Logger::ERROR

      # try to find existing entry in database
      ds = DownloadStat.find :first, :conditions => [
        'db_project_id=? AND db_package_id=? AND repository_id=? AND ' +
        'architecture_id=? AND filename=? AND filetype=? AND ' +
        'version=? AND download_stats.release=?',
        @@project_id, @@package_id, @@repo_id, @@arch_id,
        @@count[:filename], @@count[:filetype],
        @@count[:version], @@count[:release]
      ]
      if ds
        # entry found, update it if necessary ...
        if ds.count.to_i != text.to_i
          ds.count = text
          ds.counted_at = @@count[:counted_at]
          ds.save
        end
      else
        # create new entry - we do this directly per sql statement, because
        # that's much faster than through ActiveRecord objects
        DownloadStat.connection.insert "\
        INSERT INTO download_stats ( \
          `db_project_id`, `db_package_id`, `repository_id`, `architecture_id`,\
          `filename`, `filetype`, `version`, `release`,\
          `counted_at`, `created_at`, `count`\
        ) VALUES(\
          '#{@@project_id}', '#{@@package_id}', '#{@@repo_id}', '#{@@arch_id}',\
          '#{@@count[:filename]}',   '#{@@count[:filetype]}',\
          '#{@@count[:version]}',    '#{@@count[:release]}',\
          '#{@@count[:counted_at]}', '#{@@count[:created_at]}',\
          '#{text}'\
        )", "Creating DownloadStat entry: "
      end

      # reset the log level
      DownloadStat.logger.level = old_loglevel
    end
  end


  def index
    text =  "This is the statistics controller.<br />"
    text += "See the api documentation for details."
    render :text => text
  end


  def highest_rated
    # set automatic action_cache expiry time limit
    # response.time_to_live = 10.minutes

    ratings = Rating.find :all,
      :select => 'db_object_id, db_object_type, count(score) as count,' +
        'sum(score)/count(score) as score_calculated',
      :group => 'db_object_id, db_object_type',
      :order => 'score_calculated DESC'
    ratings = ratings.delete_if { |r| r.count.to_i < min_votes_for_rating }
    if @limit
      @ratings = ratings[0..@limit-1]
    else
      @ratings = ratings
    end
  end

  def rating
    @project = params[:project]
    @package = params[:package]

    object = DbProject.get_by_name(@project)
    object = DbPackage.get_by_project_and_name(@project, @package, false, false) if @package

    if request.get?

      @rating = object.rating( @http_user.id )
      return

    elsif request.put?

      # try to get previous rating of this user for this object
      previous_rating = Rating.find :first, :conditions => [
        'object_type=? AND object_id=? AND user_id=?',
        object.class.name, object.id, @http_user.id
      ]
      data = ActiveXML::Base.new( request.raw_post )
      if previous_rating
        # update previous rating
        previous_rating.score = data.to_s.to_i
        previous_rating.save
      else
        # create new rating entry
        begin
          rating = Rating.new
          rating.score = data.to_s.to_i
          rating.object_type = object.class.name
          rating.object_id = object.id
          rating.user_id = @http_user.id
          rating.save
        rescue
          render_error :status => 400, :errorcode => "error setting rating",
            :message => "rating not saved"
          return
        end
      end
      render_ok
      return
    end

    render_error :status => 400, :errorcode => "invalid_method",
      :message => "only GET or PUT method allowed for this action"
  end


  def download_counter
    # set automatic action_cache expiry time limit
    #    response.time_to_live = 30.minutes

    # FIXME: download stats are currently not supported and needs a re-implementation

    # initialize @stats
    @stats = []

    # get total count of all downloads
    @all = DownloadStat.sum(:count)
    @all = 0 unless @all

    # get timestamp of first counted entry
    time = DownloadStat.minimum(:created_at)
    time ? @first = time.xmlschema : @first = Time.now.xmlschema

    # get timestamp of last counted entry
    time = DownloadStat.maximum(:counted_at)
    time ? @last = time.xmlschema : @last = Time.now.xmlschema

    if @group_by_mode = params[:group_by]
    # if in group_by_mode, then we concatenate download_stats entries

      # generate parts of the sql statement
      case @group_by_mode
      when 'project'
        from = 'db_projects pro'
        select = 'pro.name as obj_name'
        group_by = 'db_project_id'
        conditions = 'ds.db_project_id=pro.id'
      when 'package'
        from = 'db_packages pac'
        select = 'pac.name as obj_name, prj.name as pro_name'
        group_by = 'db_package_id'
        conditions = 'ds.db_package_id=pac.id AND ds.db_project_id=prj.id'
      when 'repo'
        from = 'repositories repo, db_projects pro'
        select = 'repo.name as obj_name, pro.name as pro_name'
        group_by = 'repository_id'
        conditions = 'ds.repository_id=repo.id AND ds.db_project_id=pro.id'
      when 'arch'
        from = 'architectures arch'
        select = 'arch.name as obj_name'
        group_by = 'architecture_id'
        conditions = 'ds.architecture_id=arch.id'
      else
        @cstats = nil
        return
      end

      # execute the sql query
      @stats = DownloadStat.find :all,
        :from => 'download_stats ds, ' + from,
        :select => 'ds.*, ' + select + ', ' +
          'sum(ds.count) as counter_sum, count(ds.id) as files_count',
        :conditions => conditions,
        :order => 'counter_sum DESC, files_count ASC',
        :group => group_by,
        :limit => @limit

    else
    # we are not in group_by_mode, so we return full download_stats data

      # get objects
      prj = DbProject.find_by_name params[:project]
      pac = DbPackage.find :first, :conditions => [
        'name=? AND db_project_id=?', params[:package], prj.id
      ] if prj
      repo = Repository.find :first, :conditions => [
        'name=? AND db_project_id=?', params[:repo], prj.id
      ] if prj
      arch = Architecture.find_by_name params[:arch]

      # return immediately, if any object is invalid / not found
      return if not prj  and not params[:project].nil?
      return if not pac  and not params[:package].nil?
      return if not repo and not params[:repo].nil?
      return if not arch and not params[:arch].nil?

      # create filter, if parameters given & objects found
      filter = ''
      filter += " AND ds.db_project_id=#{prj.id}" if prj
      filter += " AND ds.db_package_id=#{pac.id}" if pac
      filter += " AND ds.repository_id=#{repo.id}" if repo
      filter += " AND ds.architecture_id=#{arch.id}" if arch
      
      # get download_stats entries
      @stats = DownloadStat.find :all,
        :from => 'download_stats ds, db_projects pro, db_packages pac, ' +
          'architectures arch, repositories repo',
        :select => 'ds.*, pro.name as pro_name, pac.name as pac_name, ' +
          'arch.name as arch_name, repo.name as repo_name',
        :conditions => 'ds.db_project_id=pro.id AND ds.db_package_id=pac.id' +
          ' AND ds.architecture_id=arch.id AND ds.repository_id=repo.id' +
          filter,
        :order => 'ds.count DESC',
        :limit => @limit

      # get sum of counts
      @sum = DownloadStat.find( :first,
        :from => 'download_stats ds',
        :select => 'sum(count) as overall_counter',
        :conditions => '1=1' + filter
      ).overall_counter
    end
  end


  def redirect_stats

    #breakpoint "redirect problem"
    # check permissions

    unless permissions.set_download_counters
      render_error :status => 403, :errorcode => "permission denied",
        :message => "download counters cannot be set, insufficient permissions"
      return
    end

    # get download statistics from redirector as xml
    if request.put?
      data = request.raw_post

      # parse the data
      streamhandler = StreamHandler.new
      logger.debug "download_stats import starts now ..."
      REXML::Document.parse_stream( data, streamhandler )
      logger.debug "download_stats import is finished."

      if streamhandler.errors
        logger.debug "prepare download_stats warning message..."
        err_count = streamhandler.errors.length
        dayofweek = Time.now.strftime('%u')
        logfile = "log/download_statistics_import_warnings-#{dayofweek}.log"
        msg  = "WARNING: #{err_count} redirect_stats were not imported.\n"
        msg += "(for details see logfile #{logfile})"

        f = File.open logfile, 'w'
        streamhandler.errors.each do |e|
          f << "project: #{e[:project_name]}=#{e[:project_id] or '*UNKNOWN*'}  "
          f << "package: #{e[:package_name]}=#{e[:package_id] or '*UNKNOWN*'}  "
          f << "repo: #{e[:repo_name]}=#{e[:repo_id] or '*UNKNOWN*'}  "
          f << "arch: #{e[:arch_name]}=#{e[:arch_id] or '*UNKNOWN*'}\t"
          f << "(#{e[:count][:filename]}:#{e[:count][:version]}:"
          f << "#{e[:count][:release]}:#{e[:count][:filetype]})\n"
        end
        f.close

        logger.warn "\n\n#{msg}\n\n"
        render_ok msg # render_ok with msg text in details
      else
        render_ok
      end

    else
      render_error :status => 400, :errorcode => "only_put_method_allowed",
        :message => "only PUT method allowed for this action"
      logger.debug "Tried to access download_stats via '#{request.method}' - not allowed!"
      return
    end
  end

  def newest_stats
    # FIXME: fixtures lacking
    ds = DownloadStat.find :first, :order => "counted_at DESC", :limit => 1
    @newest_stats = ds.nil? ? Time.at(0).xmlschema : ds.counted_at.xmlschema
  end
 

  def most_active_projects
    # get all packages including activity values
    @packages = DbPackage.find :all,
      :order => 'activity_value DESC',
      :limit => @limit,
      :select => 'db_packages.*, ' +
        "( #{DbPackage.activity_algorithm} ) AS act_tmp," +
        'IF( @activity<0, 0, @activity ) AS activity_value'
    # count packages per project and sum up activity values
    projects = {}
    @packages.each do |package|
      pro = package.db_project.name
      projects[pro] ||= { :count => 0, :sum => 0 }
      projects[pro][:count] += 1
      projects[pro][:sum] += package.activity_value.to_f
    end

    # calculate average activity of packages per project
    projects.each_key do |pro|
      projects[pro][:activity] = projects[pro][:sum] / projects[pro][:count]
    end
    # sort by activity
    @projects = projects.sort do |a,b|
      b[1][:activity] <=> a[1][:activity]
    end

    return @projects
  end

  def most_active_packages
    # get all packages including activity values
    @packages = DbPackage.find :all,
      :order => 'activity_value DESC',
      :limit => @limit,
      :select => 'db_packages.*, ' +
        "( #{DbPackage.activity_algorithm} ) AS act_tmp," +
        'IF( @activity<0, 0, @activity ) AS activity_value'

    return @packages
  end


  def activity
    @project = DbProject.get_by_name(params[:project])
    @package = DbPackage.get_by_project_and_name(params[:project], params[:package], false, false) if params[:package]
  end


  def latest_added

    packages = DbPackage.find :all,
      :order => 'created_at DESC, name', :limit => @limit
    projects = DbProject.find :all,
      :order => 'created_at DESC, name', :limit => @limit

    list = projects 
    list.concat packages
    list.sort! { |a,b| b.created_at <=> a.created_at }


    if @limit
      @list = list[0..@limit-1]
    else
      @list = list
    end
  end


  def added_timestamp

    @project = DbProject.get_by_name(params[:project])
    @package = DbPackage.get_by_project_and_name(params[:project], params[:package], false, true)

    # is it used at all ?
  end


  def latest_updated
    @limit = 10 unless @limit
    # first we catch a list visible to anyone
    # not just needs this to be fast, it also needs to catch errors in case projects or packages
    # disappear after the cache hit. So we do not spend too much logic in access flags, but check
    # the cached values afterwards if they are valid and accessible
    packages = DbPackage.find_by_sql("select id,updated_at from db_packages ORDER by updated_at DESC LIMIT #{@limit * 2}")
    projects = DbProject.find_by_sql("select id,updated_at from db_projects ORDER by updated_at DESC LIMIT #{@limit * 2}")

    list = projects
    list.concat packages
    ret = Array.new
    list.sort { |a,b| b.updated_at <=> a.updated_at }.each do |item|
      if item.instance_of? DbPackage
        ret << [:package, item.id]
      else
        ret << [:project, item.id]
      end
    end
    list = ret

    @list = Array.new
    list.each do |type, id|
      if type == :project
        item = DbProject.find(id)
        next unless DbProject.check_access?(item)
      else
        item = DbPackage.find(id)
        next unless item
        next unless DbPackage.check_access?(item)
      end
      @list << item
      break if @list.size == @limit
    end
  end


  def updated_timestamp

    @project = DbProject.get_by_name(params[:project])
    @package = DbPackage.get_by_project_and_name(params[:project], params[:package], false, true)

  end


  def global_counters

    @users = User.count
    @repos = Repository.count
    @projects = DbProject.count
    @packages = DbPackage.count
  end


  def latest_built
    # set automatic action_cache expiry time limit
    #    response.time_to_live = 10.minutes

    # TODO: implement or decide to abolish this functionality
  end


  def get_limit
    return @limit = nil if not params[:limit].nil? and params[:limit].to_i == 0
    @limit = 10 if (@limit = params[:limit].to_i) == 0
  end

end
