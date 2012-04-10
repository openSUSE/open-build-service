
# The Group class represents a group record in the database and thus a group
# in the ActiveRbac model. Groups are arranged in trees and have a title.
# Groups have an arbitrary number of roles and users assigned to them.
#
class Group < ActiveRecord::Base
  has_many :groups_users, :foreign_key => 'group_id'
  has_many :project_group_role_relationships, :foreign_key => 'bs_group_id'
  has_many :package_group_role_relationships, :foreign_key => 'bs_group_id'

  validates_format_of  :title,
                       :with => %r{^[\w\-]*$},
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
  has_and_belongs_to_many :users, :uniq => true
  # groups have a n:m relation to groups
  has_and_belongs_to_many :roles, :uniq => true

  attr_accessible :title
  
  class << self
    def render_group_list(user=nil)

       if user
         user = User.find_by_login(user)
         return nil if user.nil?
         if User.ldapgroup_enabled?
           begin
             list = User.render_grouplist_ldap(Group.all, user.login)
           rescue Exception
             logger.debug "Error occurred in rendering grouplist in ldap."
           end
         else
           list = user.groups
         end
       else
         if User.ldapgroup_enabled?
           begin
             list = User.render_grouplist_ldap(Group.all)
           rescue Exception
             logger.debug "Error occurred in rendering grouplist in ldap."
           end
         else
           list = Group.all
         end
       end

      builder = Nokogiri::XML::Builder.new
      builder.directory( :count => list.length ) do |dir|
        list.each do |g|
          dir.entry( :name => g.title )
        end
      end
      
      return builder.doc.to_xml :indent => 2, :encoding => 'UTF-8',
                                :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                 Nokogiri::XML::Node::SaveOptions::FORMAT
    end

    def get_by_title(title)
      g = where("title = BINARY ?", title).first
      raise GroupNotFoundError.new( "Error: Group '#{title}' not found." ) unless g
      return g
    end
  end

end
