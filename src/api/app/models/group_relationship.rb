class GroupRelationship < Relationship
  validates :group, presence: true
end
