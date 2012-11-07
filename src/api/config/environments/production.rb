# Settings specified here will take precedence over those in config/environment.rb

OBSApi::Application.configure do

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Use a different logger for distributed setups
  # config.logger        = SyslogLogger.new
  config.log_level = :info

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host                  = "http://assets.example.com"

  # Disable delivery errors if you bad email addresses should just be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Exception notifications via ExceptionNotifier
  # config.middleware.use ExceptionNotifier, 
  # :email_prefix => "[OBS API Error] ", 
  # :sender_address => %{"OBS API" <admin@opensuse.org>}, 
  # :exception_recipients => %w{obs-errors@opensuse.org}

end

# LDAP port defaults to 636 for ldaps and 389 for ldap and ldap with StartTLS
#CONFIG['ldap_port']=
# Authentication with Windows 2003 AD requires
CONFIG['ldap_referrals'] = :off

# Max number of times to attempt to contact the LDAP servers
CONFIG['ldap_max_attempts'] = 10

# OVERRIDE with your company's ldap search base for the users who will use OBS
CONFIG['ldap_search_base'] = "OU=Organizational Unit,DC=Domain Component"
# Sam Account Name is the login name for LDAP 
CONFIG['ldap_search_attr'] = "sAMAccountName"
# The attribute the users name is stored in
CONFIG['ldap_name_attr']="cn"
# The attribute the users email is stored in
CONFIG['ldap_mail_attr']="mail"
# Credentials to use to search ldap for the username
CONFIG['ldap_search_user']=""
CONFIG['ldap_search_auth']=""

# By default any LDAP user can be used to authenticate to the OBS
# In some deployments this may be too broad and certain criteria should
# be met; eg group membership
#
# To allow only users in a specific group uncomment this line:
#CONFIG['ldap_user_filter']="(memberof=CN=group,OU=Groups,DC=Domain Component)"
#
# Note this is joined to the normal selection like so:
# (&(#{LCONFIG['dap_search_attr']}=#{login})#{CONFIG['ldap_user_filter']})
# giving an ldap search of:
#  (&(sAMAccountName=#{login})(memberof=CN=group,OU=Groups,DC=Domain Component))
#
# Also note that openLDAP must be configured to use the memberOf overlay

# How to verify:
#   :ldap = attempt to bind to ldap as user using supplied credentials
#   :local = compare the credentials supplied with those in 
#            LDAP using CONFIG['ldap_auth_attr'] & CONFIG['ldap_auth_mech']
#       CONFIG['ldap_auth_mech'] can be
#       : md5
#       : cleartext
CONFIG['ldap_authenticate']=:ldap
CONFIG['ldap_auth_attr']="userPassword"
CONFIG['ldap_auth_mech']=:md5

# Whether to update the user info to LDAP server, it does not take effect 
# when CONFIG['ldap_mode'] is not set.
# Since adding new entry operation are more depend on your slapd db define, it might not 
# compatiable with all LDAP server settings, you can use other LDAP client tools for your specific usage
CONFIG['ldap_update_support'] = :off
# ObjectClass, used for adding new entry
CONFIG['ldap_object_class'] = ['inetOrgPerson']
# Base dn for the new added entry
CONFIG['ldap_entry_base'] = "ou=OBSUSERS,dc=EXAMPLE,dc=COM"
# Does sn attribute required, it is a necessary attribute for most of people objectclass,
# used for adding new entry
CONFIG['ldap_sn_attr_required'] = :on

# Whether to search group info from ldap, it does not take effect
# when LDAP_GROUP_SUPPOR is not set.
# Please also set below LDAP_GROUP_* configs correctly to ensure the operation works properly
CONFIG['ldap_group_support'] = :off
# OVERRIDE with your company's ldap search base for groups
CONFIG['ldap_group_search_base'] = "ou=OBSGROUPS,dc=EXAMPLE,dc=COM"
# The attribute the group name is stored in
CONFIG['ldap_group_title_attr'] = "cn"
# The value of the group objectclass attribute, leave it as "" if objectclass attr doesn't exist
CONFIG['ldap_group_objectclass_attr'] = "groupOfNames"

#require 'hermes'
#Hermes::Config.setup do |hermesconf|
#  hermesconf.dbhost = 'storage'
#  hermesconf.dbuser = 'hermes'
#  hermesconf.dbpass = ''
#  hermesconf.dbname = 'hermes'
#end

# disabled on production for performance reasons
# CONFIG['response_schema_validation'] = true

#require 'memory_debugger'
# dumps the objects after every request
#config.middleware.insert(0, MemoryDebugger)

#require 'memory_dumper'
# dumps the full heap after next request on SIGURG
#config.middleware.insert(0, MemoryDumper)

