require 'mysql'

class Hermes
  class Config
    @fields = [:dbhost, :dbuser, :dbpass, :dbname]
    @values = Hash.new
    class << self
      private :new

      def setup
        yield self
        nil
      end

      def method_missing(sym, *args, &block)
        md = sym.to_s.match(/^([^=]+)(=?)/)
        fname = md[1].to_sym
        assign = (not md[2].empty?)

        if @fields.include? fname
          if assign
            @values[fname] = args[0]
          else
            return @values[fname]
          end
        else
          super
        end
      end
    end
  end

  attr_reader :logger

  def initialize
    host = Config.dbhost
    user = Config.dbuser
    pass = Config.dbpass
    dbname = Config.dbname

    @mysql = Mysql.new(host, user, pass, dbname)

    @msg_type_id_by_name = Hash.new
    @user_id_by_name = Hash.new
    @delivery_id_by_name = Hash.new
    @delay_id_by_name = Hash.new
    @parameter_id_by_name = Hash.new

    if Object.const_defined? :Rails.logger
      @logger = Rails.logger
    else
      require 'logger'
      @logger = Logger.new(STDERR)
    end
  end

  ###########################
  # add_request_subscription
  #
  # creates default subscription for submit requests for specified user
  #
  # returns false on any error that isn't raised
  #
  def add_request_subscription(username)
    subscr_id = add_subscription(username, "OBS_SRCSRV_REQUEST_CREATE", "Mail", "NO_DELAY")
    if subscr_id
      add_filter(subscr_id, 'sourceproject', 'special', '_myrequests')
      logger.info "[hermes] added OBS_SRCSRV_REQUEST_CREATE sub for user #{username}"
    else
      logger.info "[hermes] !! skipped OBS_SRCSRV_REQUEST_CREATE sub for user #{username}"
    end
    
    subscr_id = add_subscription(username, "OBS_SRCSRV_REQUEST_STATECHANGE", "Mail", "NO_DELAY")
    if subscr_id
      add_filter(subscr_id, 'sourceproject', 'special', '_myrequests')
      logger.info "[hermes] added OBS_SRCSRV_REQUEST_STATECHANGE sub for user #{username}"
    else
      logger.info "[hermes] !! skipped OBS_SRCSRV_REQUEST_STATECHANGE sub for user #{username}"
    end

    subscr_id = add_subscription(username, "OBS_SRCSRV_REQUEST_REVIEWER_ADDED", "Mail", "NO_DELAY")
    if subscr_id
      add_filter(subscr_id, 'newreviewer', 'oneof', username)
      logger.info "[hermes] added OBS_SRCSRV_REQUEST_REVIEWER_ADDED sub for user #{username}"
    else
      logger.info "[hermes] !! skipped OBS_SRCSRV_REQUEST_REVIEWER_ADDED sub for user #{username}"
    end
    
    return true
  end

  ###########################
  # add_subscription
  #
  # returns subscription id of newly created subscription or nil 
  #   when none was created
  #
  def add_subscription(username, msgtype, delivery, delay)
    user_id = get_user_id_by_name(username)
    msg_type_id = get_msg_type_id_by_name(msgtype)
    delivery_id = get_delivery_id_by_name(delivery)
    delay_id = get_delay_id_by_name(delay)

    begin
      st = @mysql.prepare("insert into subscriptions (person_id, msg_type_id, delivery_id, delay_id) values (?,?,?,?)")
      st.execute(user_id, msg_type_id, delivery_id, delay_id)

      st.prepare("select id from subscriptions where person_id = ? and msg_type_id = ? and delivery_id = ? and delay_id = ?")
      st.execute(user_id, msg_type_id, delivery_id, delay_id)
    rescue Mysql::Error => e
      if e.message =~ /^Duplicate entry/
        return nil
      else
        raise e
      end
    end
    return st.fetch[0]
  end

  #############################
  # add_filter
  #
  # 
  def add_filter(subscr_id, parameter, operator, filterstring)
    parameter_id = get_parameter_id_by_name(parameter)

    st = @mysql.prepare("insert into subscription_filters (subscription_id, parameter_id, operator, filterstring) values (?,?,?,?)")
    st.execute(subscr_id, parameter_id, operator, filterstring)
  end

  def add_user(name, email)
    st = @mysql.prepare("select id from persons where stringid = ?")
    st.execute(name.to_s)
    if st.fetch
      return false
    end

    st = @mysql.prepare("insert into persons (stringid, email) values (?,?)")
    st.execute(name.to_s, email.to_s)
    return true
  end

  def get_user_id_by_name(user)
    unless @user_id_by_name.has_key? user.to_sym
      st = @mysql.prepare("select id from persons where stringid = ?")
      st.execute(user.to_s)
      if res = st.fetch
        @user_id_by_name[user.to_sym] = res[0]
      else
        return nil
      end
    end

    return @user_id_by_name[user.to_sym]
  end

  def get_msg_type_id_by_name(msgtype)
    unless @msg_type_id_by_name.has_key? msgtype.to_sym
      st = @mysql.prepare("select id from msg_types where msgtype = ?")
      st.execute(msgtype.to_s)
      if res = st.fetch
        @msg_type_id_by_name[msgtype.to_sym] = res[0]
      else
        return nil
      end
    end

    return @msg_type_id_by_name[msgtype.to_sym]
  end

  def get_delivery_id_by_name(delivery)
    unless @delivery_id_by_name.has_key? delivery.to_sym
      st = @mysql.prepare("select id from deliveries where name = ?")
      st.execute(delivery.to_s)
      if res = st.fetch
        @delivery_id_by_name[delivery.to_sym] = res[0]
      else
        return nil
      end
    end

    return @delivery_id_by_name[delivery.to_sym]
  end

  def get_delay_id_by_name(delay)
    unless @delay_id_by_name.has_key? delay.to_sym
      st = @mysql.prepare("select id from delays where name = ?")
      st.execute(delay.to_s)
      if res = st.fetch
        @delay_id_by_name[delay.to_sym] = res[0]
      else
        return nil
      end
    end

    return @delay_id_by_name[delay.to_sym]
  end

  def get_parameter_id_by_name(parameter)
    unless @parameter_id_by_name.has_key? parameter.to_sym
      st = @mysql.prepare("select id from parameters where name = ?")
      st.execute(parameter.to_s)
      if res = st.fetch
        @parameter_id_by_name[parameter.to_sym] = res[0]
      else
        return nil
      end
    end

    return @parameter_id_by_name[parameter.to_sym]
  end
end
