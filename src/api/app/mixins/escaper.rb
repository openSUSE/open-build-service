module Escaper
  # path escape
  def pesc(str)
    URI.escape str.to_s
  end
end
