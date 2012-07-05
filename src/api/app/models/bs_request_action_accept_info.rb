class BsRequestActionAcceptInfo < ActiveRecord::Base
  attr_accessible :bs_request_action_id, :osrcmd5, :rev, :srcmd5, :xsrcmd5, :oxsrcmd5

  belongs_to :bs_request_action

  def render_xml(builder)
    attributes = { :rev => self.rev, :srcmd5 => self.srcmd5 }
    attributes[:osrcmd5] = self.osrcmd5 unless self.osrcmd5.blank?
    attributes[:xsrcmd5] = self.xsrcmd5 unless self.xsrcmd5.blank?
    attributes[:oxsrcmd5] = self.oxsrcmd5 unless self.oxsrcmd5.blank?
    builder.acceptinfo attributes
  end

end
