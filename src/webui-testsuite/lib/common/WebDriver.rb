# ==============================================================================
# WebDriver is based on Selenium's driver. It passes most of the action directly
# to it's superclass and adds some enhancements where needed.
#
class WebDriver < Selenium::WebDriver::Driver


  # ============================================================================
  # Gets the current url of the browser. Removes the '/' if the url ends with it
  # @return [String] the current url
  #
  def current_url
    url = super
    url.chop! if url.end_with? "/"
    url
  end
  
  # ============================================================================
  # Get the first element matching the given selector. If given a String or 
  # Symbol, it will be used as the id of the element.
  # Adds waiting time to Selenium::WebDriver::Driver#find_element in order
  # to give chance the pages to load before raising exceptions.
  # @param arg [String, Symbol, Hash]
  # @return [Selenium::WebDriver::Element]
  #
  # @example 
  #   driver['someElementId']    #=> #<WebDriver::Element:0x1011c3b88>
  #   driver[:tag_name => 'div'] #=> #<WebDriver::Element:0x1011c3b88>
  #
  def [] arg
    Selenium::WebDriver::Wait.new :timeout => $data[:actions_timeout] do
      find_element arg
    end
    find_element arg
  end


  # ============================================================================
  # Returns true/false if the current page contains
  # element(s) that match the given pattern by arg
  #
  def include? arg
    elements = find_elements arg
    not elements.empty?
  end
  
  
end
