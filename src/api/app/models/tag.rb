class Tag < ApplicationRecord
  has_many :taggings, :dependent => :destroy
  has_many :projects, -> { where("taggings.taggable_type = 'Project'") }, through: :taggings
  has_many :packages, -> { where("taggings.taggable_type = 'Package'") }, through: :taggings

  has_many :users, :through => :taggings

  attr_accessor :cached_count

  def count(opt = {})
    if @cached_count
      # logger.debug "[TAG:] tag usage count is already calculated. count: #{@cached_count}"
      return @cached_count
    end

    if opt[:scope] == "by_given_tags"
      tags = opt[:tags]
      @cached_count = 0
      tags.each do |tag|
        @cached_count = @cached_count + 1 if tag.name == name
      end
    elsif opt[:scope] == "user"
      user = opt[:user]
      # logger.debug "[TAG:] calculating user-dependent tag usage count"
      @cached_count ||= Tagging.where( "tag_id = ? AND user_id = ?", id, user.id ).count
    else
      # logger.debug "[TAG:] calculating user-independent tag usage count"
      @cached_count ||= Tagging.where( "tag_id = ?", id ).count
    end
    # logger.debug "[TAG:] count: #{@cached_count}"
    @cached_count
  end

  validates :name, :format => { :with => /\A[^:?]*\z/, :message => "no ? and : allowed!" }
  validate :not_blacklisted

  protected

  def not_blacklisted
    blacklist = BlacklistTag.where("name = ?", name).first
    errors.add(:name, "The tag is blacklisted!") if blacklist
  end
end
