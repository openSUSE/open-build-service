# The Group class represents a group record in the database and thus a
# group model. Groups are arranged in trees and have a title.
# Groups have an arbitrary number of users assigned to them.
#
class Group < ApplicationRecord
  has_one :staging_workflow, class_name: 'Staging::Workflow', foreign_key: :managers_group_id, dependent: :nullify
  has_many :groups_users, inverse_of: :group, dependent: :destroy
  has_many :users, -> { distinct.order(:login) }, through: :groups_users
  has_many :group_maintainers, inverse_of: :group, dependent: :destroy
  has_many :relationships, dependent: :destroy, inverse_of: :group
  has_many :event_subscriptions, dependent: :destroy, inverse_of: :group
  has_many :reviews, dependent: :nullify
  has_many :notifications, -> { order(created_at: :desc) }, as: :subscriber, dependent: :destroy
  has_and_belongs_to_many :created_notifications, class_name: 'Notification'
  has_and_belongs_to_many :shared_workflow_tokens,
                          class_name: 'Token::Workflow',
                          join_table: :workflow_token_groups,
                          association_foreign_key: :token_id,
                          dependent: :destroy,
                          inverse_of: :token_workflow

  validates :title,
            format: { with: /\A[\w.-]*\z/,
                      message: 'must not contain invalid characters' }
  validates :title,
            length: { in: 2..100,
                      too_long: 'must have less than 100 characters',
                      too_short: 'must have more than two characters',
                      allow_nil: false }
  # We want to validate a group's title pretty thoroughly.
  validates :title,
            uniqueness: { case_sensitive: true, message: 'is the name of an already existing group' }

  validates :email,
            format: { with: /\A([\w\-.\#$%&!?*'+=(){}|~]+)@([0-9a-zA-Z\-.\#$%&!?*'=(){}|~]+)+\z/,
                      message: 'must be a valid email address',
                      allow_blank: true }

  alias_attribute :name, :title

  def update_from_xml(xmlhash, user_session_login:)
    with_lock do
      self.email = xmlhash.value('email')
    end
    save!

    # update maintainer list
    cache = group_maintainers.index_by(&:user_id)

    xmlhash.elements('maintainer') do |maintainer|
      next unless maintainer['userid']

      user = User.find_by_login!(maintainer['userid'])
      if cache.key?(user.id)
        # user has already a role in this package
        cache.delete(user.id)
      else
        GroupMaintainer.create(user: user, group: self)
      end
    end

    cache.each do |login_id, _|
      delete_user(GroupMaintainer, login_id, id)
    end

    # update user list
    cache = groups_users.index_by(&:user_id)

    persons = xmlhash.elements('person').first
    if persons
      persons.elements('person') do |person|
        next unless person['userid']

        user = User.find_by_login!(person['userid'])
        if cache.key?(user.id)
          # user has already a role in this package
          cache.delete(user.id)
        else
          GroupsUser.create(user: user, group: self)
        end
      end
    end

    # delete all users which were not listed
    cache.each do |login_id, _|
      delete_user(GroupsUser, login_id, id, user_session_login: user_session_login)
    end
  end

  def add_user(user)
    GroupsUser.find_or_create_by!(user: user, group: self)
  end

  def replace_members(members)
    new_members = members.split(',').map do |m|
      User.find_by_login!(m)
    end
    users.replace(new_members)
  rescue ActiveRecord::RecordInvalid, NotFoundError => e
    errors.add(:base, e.message)
    false
  end

  def remove_user(user, user_session_login:)
    delete_user(GroupsUser, user.id, id, user_session_login: user_session_login)
  end

  def to_s
    title
  end

  def to_param
    to_s
  end

  def involved_projects
    # now filter the projects that are not visible
    Project.where(id: relationships.projects.maintainers.pluck(:project_id))
  end

  # lists packages maintained by this user and are not in maintained projects
  def involved_packages
    Package.where(id: relationships.packages.maintainers.pluck(:package_id))
  end

  # returns the users that actually want email for this group's notifications
  def email_users
    User.where(id: groups_users.where(email: true).select(:user_id), state: 'confirmed')
  end

  # Returns the users which want web notifications for this group
  def web_users
    User.where(id: groups_users.where(web: true).select(:user_id), state: 'confirmed')
  end

  def display_name
    address = Mail::Address.new(email)
    address.display_name = title
    address.format
  end

  def involved_reviews(search = nil)
    BsRequest::FindFor::Query.new(
      group: title,
      roles: [:reviewer],
      review_states: [:new],
      states: [:review],
      search: search
    ).all
  end

  def incoming_requests(search = nil)
    BsRequest::FindFor::Query.new(group: title, states: [:new], roles: [:maintainer], search: search).all
  end

  def bs_requests
    BsRequest.left_outer_joins(:bs_request_actions, :reviews)
             .where(reviews: { group_id: id })
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(reviews: { project_id: involved_projects_ids }))
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(reviews: { package_id: involved_packages_ids }))
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(bs_request_actions: { target_project_id: involved_projects_ids }))
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(bs_request_actions: { target_package_id: involved_packages_ids }))
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(bs_request_actions: { source_project_id: involved_projects_ids }))
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(bs_request_actions: { source_package_id: involved_packages_ids }))
             .distinct
  end

  def requests(search = nil)
    BsRequest::FindFor::Query.new(group: title, search: search).all
  end

  def all_requests_count
    BsRequest::FindFor::Group.new(group: title, relation: BsRequest.all).all_count
  end

  def tasks
    Rails.cache.fetch("requests_for_#{cache_key_with_version}") do
      incoming_requests.count + involved_reviews.count
    end
  end

  def any_confirmed_users?
    users.where(state: 'confirmed').any?
  end

  def away?
    users.seen_since(3.months.ago).empty?
  end

  def maintainer?(user)
    group_maintainers.exists?(user: user)
  end

  private

  def delete_user(klass, login_id, group_id, user_session_login: nil)
    klass.where('user_id = ? AND group_id = ?', login_id, group_id).delete_all if [GroupMaintainer, GroupsUser].include?(klass)
    Event::RemovedUserFromGroup.create(group: Group.find(group_id).title, member: User.find(login_id).login, who: user_session_login) if klass == GroupsUser
  end

  # IDs of the Projects where the group is maintainer
  def involved_projects_ids
    relationships.projects.maintainers.pluck(:project_id)
  end

  # IDs of the Packages where the group is maintainer
  def involved_packages_ids
    relationships.packages.maintainers.pluck(:package_id)
  end
end

# == Schema Information
#
# Table name: groups
#
#  id         :integer          not null, primary key
#  email      :string(255)
#  title      :string(200)      default(""), not null, indexed
#  created_at :datetime
#  updated_at :datetime
#  parent_id  :integer          indexed
#
# Indexes
#
#  groups_parent_id_index  (parent_id)
#  index_groups_on_title   (title)
#
