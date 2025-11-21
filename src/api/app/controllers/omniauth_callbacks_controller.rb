# frozen_string_literal: true

# OmniAuth Callbacks Controller
#
# This controller handles callbacks from OmniAuth authentication providers.
# It sets the necessary HTTP headers for OBS's proxy_auth_mode to automatically
# create/update users.
#
# Flow:
# 1. User clicks "Login with LDAP"
# 2. Redirects to /auth/ldap (OmniAuth entry point)
# 3. OmniAuth-LDAP authenticates against LDAP server
# 4. Callback comes to this controller
# 5. We set HTTP_X_USERNAME and other headers
# 6. Forward request back to OBS
# 7. OBS proxy_auth_mode creates/updates user automatically

class OmniAuthCallbacksController < ApplicationController
  skip_before_action :extract_user, only: [:ldap, :failure]
  skip_before_action :check_anonymous_access, only: [:ldap, :failure]
  skip_before_action :verify_authenticity_token, only: [:ldap, :failure]

  # LDAP authentication callback
  def ldap
    auth_hash = request.env['omniauth.auth']

    unless auth_hash
      redirect_to root_path, error: 'Authentication failed: No authentication data received'
      return
    end

    # Extract user information from LDAP
    username = extract_username(auth_hash)
    email = extract_email(auth_hash)
    realname = extract_realname(auth_hash)
    groups = extract_groups(auth_hash)

    Rails.logger.info "OmniAuth-LDAP: Authenticated user '#{username}' with groups: #{groups.join(', ')}"

    # Set proxy auth headers that OBS expects
    request.env['HTTP_X_USERNAME'] = username
    request.env['HTTP_X_EMAIL'] = email if email.present?
    request.env['HTTP_X_FULLNAME'] = realname if realname.present?

    # Set LDAP groups for group synchronization
    if groups.any?
      request.env['HTTP_X_LDAP_GROUPS'] = groups.join(',')
    end

    # Now let OBS's proxy_auth_mode handle user creation/update
    # by extracting the user via the Authenticator concern
    extract_user

    # Check if user was successfully created/found
    if User.session
      Rails.logger.info "OmniAuth-LDAP: User '#{username}' logged in successfully"

      # Sync LDAP groups to OBS groups if configured
      sync_groups(User.session, groups) if groups.any?

      # Redirect to user's profile or where they came from
      redirect_back_or_to(user_path(User.session), notice: 'Successfully authenticated via LDAP')
    else
      Rails.logger.error "OmniAuth-LDAP: Failed to create/find user '#{username}'"
      redirect_to root_path, error: 'Authentication failed: Could not create user account'
    end
  end

  # Handle authentication failures
  def failure
    error_message = params[:message] || 'Unknown authentication error'
    strategy = params[:strategy] || 'unknown'

    Rails.logger.warn "OmniAuth failure for strategy '#{strategy}': #{error_message}"

    redirect_to root_path, error: "Authentication failed: #{error_message}"
  end

  private

  # Extract username from auth hash
  def extract_username(auth_hash)
    # Try uid first (most common), then fallback to info.nickname or info.name
    username = auth_hash.uid ||
               auth_hash.dig(:info, :nickname) ||
               auth_hash.dig(:info, :name)

    # Strip any domain suffix (@example.com)
    username&.gsub(/@.*$/, '')&.downcase
  end

  # Extract email from auth hash
  def extract_email(auth_hash)
    auth_hash.dig(:info, :email)
  end

  # Extract real name from auth hash
  def extract_realname(auth_hash)
    # Try to build full name from first + last, or use name field
    first_name = auth_hash.dig(:info, :first_name)
    last_name = auth_hash.dig(:info, :last_name)

    if first_name && last_name
      "#{first_name} #{last_name}"
    else
      auth_hash.dig(:info, :name)
    end
  end

  # Extract LDAP groups from auth hash
  def extract_groups(auth_hash)
    groups = []

    # Groups can be in different places depending on LDAP schema
    # Try memberof attribute first (most common)
    memberof = auth_hash.dig(:extra, :raw_info, :memberof)

    if memberof
      # memberof is typically an array of DNs like:
      # ["cn=obsadmins,ou=services,ou=groups,dc=example,dc=com", ...]
      groups = Array(memberof).map do |dn|
        # Extract CN (common name) from DN
        match = dn.match(/cn=([^,]+)/i)
        match&.captures&.first&.downcase
      end.compact
    end

    groups
  end

  # Synchronize LDAP groups to OBS groups
  def sync_groups(user, ldap_groups)
    return unless CONFIG['ldap']&.dig('group_sync', 'enabled')

    group_mappings = CONFIG['ldap']&.dig('group_sync', 'mappings') || {}

    Rails.logger.info "OmniAuth-LDAP: Syncing groups for user '#{user.login}': #{ldap_groups.join(', ')}"

    # Find OBS groups that should be assigned based on LDAP groups
    groups_to_add = []
    ldap_groups.each do |ldap_group|
      obs_group_name = group_mappings[ldap_group]
      if obs_group_name
        obs_group = Group.find_by(title: obs_group_name)
        groups_to_add << obs_group if obs_group
      end
    end

    # Get OBS groups that should be removed (user no longer in LDAP group)
    current_managed_groups = user.groups.where(title: group_mappings.values)
    groups_to_remove = current_managed_groups - groups_to_add

    # Add new groups
    groups_to_add.each do |group|
      unless user.groups.include?(group)
        user.groups << group
        Rails.logger.info "OmniAuth-LDAP: Added user '#{user.login}' to group '#{group.title}'"
      end
    end

    # Remove old groups
    groups_to_remove.each do |group|
      user.groups.delete(group)
      Rails.logger.info "OmniAuth-LDAP: Removed user '#{user.login}' from group '#{group.title}'"
    end

    Rails.logger.info "OmniAuth-LDAP: Group sync complete for user '#{user.login}'"
  rescue StandardError => e
    Rails.logger.error "OmniAuth-LDAP: Group sync failed for user '#{user.login}': #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
