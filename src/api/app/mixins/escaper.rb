module Escaper
  # parameters escape
  def esc(str)
    CGI.escape str.to_s
  end

  # path escape
  def pesc(str)
    URI.escape str.to_s
  end

end
