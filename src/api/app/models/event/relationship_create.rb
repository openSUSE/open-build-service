module Event
  class RelationshipCreate < Relationship
    self.message_bus_routing_key = 'relationship.create'
    self.description = 'Relationship was created'
  end
end
