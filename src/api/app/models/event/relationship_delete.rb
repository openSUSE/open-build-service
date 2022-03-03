module Event
  class RelationshipDelete < Relationship
    self.message_bus_routing_key = 'relationship.delete'
    self.description = 'Relationship was deleted'
  end
end
