class BsRequestCounter < ApplicationRecord
  # FIXME: This class should be a singleton
  # FIXME: Please stick to Rails Convention Over Configuration paradigm
  # and use plural table names
  self.table_name = "bs_request_counter"
end

# == Schema Information
#
# Table name: bs_request_counter
#
#  id      :integer          not null, primary key
#  counter :integer          default(1)
#
