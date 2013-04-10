class BsRequestActionGroup < BsRequestAction

  has_and_belongs_to_many :bs_requests, join_table: :group_request_requests

  def self.sti_name
    return :group
  end

  def store_from_xml(hash)
    super(hash)
    hash.elements("grouped") do |g|
      self.bs_requests << BsRequest.find(Integer(g["id"]))
    end
    hash.delete("grouped")
  end

  def check_permissions!
    # TODO a group means we change request states to review and back.
    # so we need an involvement in all requests
  end

  def render_xml_attributes(node)
    self.bs_requests.each do |r|
      node.grouped id: r.id
    end
  end

  def execute_changestate(opts)
    # TODO
  end

  def create_post_permissions_hook(opts)
    # does nothing by default
  end
end
