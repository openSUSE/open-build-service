
# The Group class represents a group record in the database and thus a group
# in the ActiveRbac model. Groups are arranged in trees and have a title.
# Groups have an arbitrary number of roles and users assigned to them.
#
class Group < ActiveRecord::Base

  class NotFound < APIException
    setup 404
  end

  has_many :groups_users, :foreign_key => 'group_id'
  has_many :relationships, dependent: :destroy, inverse_of: :group

  validates_format_of  :title,
                       :with => %r{\A[\w\.\-]*\z},
                       :message => 'must not contain invalid characters.'
  validates_length_of  :title,
                       :in => 2..100, :allow_nil => true,
                       :too_long => 'must have less than 100 characters.',
                       :too_short => 'must have more than two characters.',
                       :allow_nil => false
  # We want to validate a group's title pretty thoroughly.
  validates_uniqueness_of :title,
                          :message => 'is the name of an already existing group.'

  # groups have a n:m relation to user
  has_and_belongs_to_many :users, -> { uniq() }
  # groups have a n:m relation to groups
  has_and_belongs_to_many :roles, -> { uniq() }

  def self.find_by_title!(title)
    find_by_title(title) or raise NotFound.new("Couldn't find Group '#{title}'")
  end

  def update_from_xml( xmlhash )
    self.with_lock do
      self.title = xmlhash.value('title')

      if xmlhash.value('email')
        self.email = xmlhash.value('email')
      else
        self.email = nil
      end
    end
    self.save!

    # update user list
    cache = Hash.new
    self.groups_users.each do |gu|
      cache[gu.user.id] = gu
    end

    persons = xmlhash.elements('person').first
    if persons
      persons.elements('person') do |person|
        next unless person['userid']
        user = User.find_by_login!(person['userid'])
        if cache.has_key? user.id
          #user has already a role in this package
          cache[user.id] = :keep
        else
          gu = GroupsUser.create( user: user, group: self)
          gu.save!
          cache[user.id] = :keep
        end
      end
    end

    #delete all users which were not listed
    cache.each do |login_id, gu|
      next if gu == :keep
      GroupsUser.delete_all(['user_id = ? AND group_id = ?', login_id, self.id])
    end
  end

  def add_user(user)
    return if self.users.find_by_id user.id # avoid double creation
    gu = GroupsUser.create( user: user, group: self)
    gu.save!
  end

  def remove_user(user)
    GroupsUser.delete_all(['user_id = ? AND group_id = ?', user.id, self.id])
  end

  def set_email(email)
    self.email = email
    self.save!
  end

  def to_s
    self.title
  end

  def to_param
    to_s
  end

  def involved_projects_ids
    # just for maintainer for now.
    role = Role.rolecache['maintainer']

    ### all projects where user is maintainer
    projects = Relationship.projects.where(group_id: id, role_id: role.id).pluck(:project_id)

    projects.uniq
  end
  protected :involved_projects_ids
  
  def involved_projects
    # now filter the projects that are not visible
    return Project.where(id: involved_projects_ids)
  end

  # lists packages maintained by this user and are not in maintained projects
  def involved_packages
    # just for maintainer for now.
    role = Role.rolecache['maintainer']

    projects = involved_projects_ids
    projects << -1 if projects.empty?

    # all packages where group is maintainer
    packages = Relationship.where(group_id: id, role_id: role.id).joins(:package).where('packages.db_project_id not in (?)', projects).pluck(:package_id)

    return Package.where(id: packages).where('db_project_id not in (?)', projects)
  end

end
