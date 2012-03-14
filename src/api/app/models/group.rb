require 'active_rbac_mixins/group_mixins'

# The Group class represents a group record in the database and thus a group
# in the ActiveRbac model. Groups are arranged in trees and have a title.
# Groups have an arbitrary number of roles and users assigned to them.
#
# The Group ActiveRecord class mixes in the "ActiveRbacMixins::GroupMixins::*" modules.
# These modules contain the actual implementation. It is kept there so
# you can easily provide your own model files without having to all lines
# from the engine's directory
#
class Group < ActiveRecord::Base
  include ActiveRbacMixins::GroupMixins::Validation
  include ActiveRbacMixins::GroupMixins::Core

  has_many :groups_users, :foreign_key => 'group_id'
  has_many :project_group_role_relationships, :foreign_key => 'bs_group_id'
  has_many :package_group_role_relationships, :foreign_key => 'bs_group_id'

  class << self
    def render_group_list(user=nil)

       if user
         user = User.find_by_login(user)
         return nil if user.nil?
         if User.ldapgroup_enabled?
           begin
             list = User.render_grouplist_ldap(Group.find(:all), user.login)
           rescue Exception
             logger.debug "Error occurred in rendering grouplist in ldap."
           end
         else
           list = user.groups
         end
       else
         if User.ldapgroup_enabled?
           begin
             list = User.render_grouplist_ldap(Group.find(:all))
           rescue Exception
             logger.debug "Error occurred in rendering grouplist in ldap."
           end
         else
           list = Group.find(:all)
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
      g = find :first, :conditions => ["title = BINARY ?", title]
      raise GroupNotFoundError.new( "Error: Group '#{title}' not found." ) unless g
      return g
    end
  end

  def render_axml
    # FIXME: where is this used? it was commited to git without test case or use
    logger.debug "----------------- rendering group #{self.title} ------------------------"
    "<group><title>#{self.title.fast_xs}</title></group>"
  end

end
