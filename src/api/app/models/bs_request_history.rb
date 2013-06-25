class BsRequestHistory < ActiveRecord::Base
  belongs_to :bs_request 
  validates_inclusion_of :state, :in => VALID_REQUEST_STATES
  validates :commenter, :presence => true

  def state
    read_attribute(:state).to_sym
  end

  def self.new_from_xml_hash(hash)
    h = BsRequestHistory.new
    h.comment = hash.delete("comment")
    h.commenter = hash.delete("who")
    h.state = hash.delete("name").to_sym
    # old stuff
    h.state = :declined if h.state == :rejected
    h.state = :accepted if h.state == :accept
    h.created_at = Time.zone.parse(hash.delete("when"))
    h.superseded_by = hash.delete("superseded_by")

    raise ArgumentError, "too much information #{hash.inspect}" unless hash.blank?
    h
  end

  def render_xml(builder)
    attributes = { :name => self.state.to_s, :who => self.commenter, :when => self.created_at.strftime("%Y-%m-%dT%H:%M:%S") }
    attributes[:superseded_by] = self.superseded_by unless self.superseded_by.blank?
    builder.history(attributes) do
      if self.comment
        builder.comment! self.comment
      end
    end
  end
end
 
