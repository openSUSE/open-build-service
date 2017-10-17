module Backend
  # Module that holds the wrapping methods for http requests, are mainly used for simplify the calculation of urls.
  #
  # == Common parameters
  # All the methods need a valid +endpoint+ to connect to, and it can be provided in two different ways:
  # * As a single string. No processing is performed.
  # * As an array. In this case the first element needs to be a string with placeholders that will be replaced in the order provided
  #   starting with the second element of the array.
  #   The placeholders have the same style as ruby symbols.
  #     get(["/build/:project/:package/_result", "Apache", "apache2"])
  #     # => HTTP GET "/build/Apache/apache2/_result"
  #
  # The +options+ hash is used for providing the params and other options available.
  # +:params+:: Hash with the parameters to be sent as part of the query in the url.
  #      get("/source/Apache/_meta", params: { revision: 42 })
  #      # => HTTP GET "/source/Apache/_meta?revision=42"
  #
  # +:defaults+:: Hash with the default parameters values that will be merged with <tt>options[:params]</tt>.
  #     get("/source/Apache", defaults: { cmd: :copy, revision: 1 }, params: { revision: 42, target: Nginx })
  #     # => HTTP GET "/source/Apache?cmd=copy&revision=42&target=Nginx"
  #
  # +:rename+:: Hash with the pairs of params keys to rename before converting the url.
  #     get("/source/Apache/_meta", params: { revision: 42 }, rename: { revision: :rev})
  #     # => HTTP GET "/source/Apache/_meta?rev=42"
  #
  # +:accepted+:: Array with the whitelist of keys for the params.
  #     get("/source/Apache/_meta", params: { revision: 42, fake: 2 }, accepted: [:revision, :comment])
  #     # => HTTP GET "/source/Apache/_meta?revision=42"
  #
  # +:expand+:: Array of keys to expand using the same name (no [] are used).
  #     get("/source/Apache/_meta", params: { revision: 42, package: ['pack1', 'pack2'] }, expand: [:package])
  #     # => HTTP GET "/source/Apache/_meta?revision=42&package=pack1&package=pack2"
  #
  # +:data+:: In the case of +put+ or +post+ requests is the data that will be sent.
  #
  #
  # +:headers+:: Hash with the headers that will be added to the request.
  #

  module ConnectionHelper
    private

    # Performs a http get request to the configured OBS Backend server.
    # @param endpoint [String, Array] Endpoit to connect to.
    # @option options [Hash] :params The parameters to be sent as part of the query in the url.
    # @option options [Hash] :defaults The default parameters values that will be merged with <tt>options[:params]</tt>.
    # @option options [Hash] :rename The parameters to be sent as part of the query in the url.
    # @option options [Array] :accepted Whitelist of keys for the params.
    # @option options [Array] :expand Keys to expand using the same name (no [] are used).
    # @option options [Hash] :headers The http headers that will be added to the request.
    # @return [String] The body of the request response encoded in UTF-8.
    def get(endpoint, options = {})
      Backend::Connection.get(calculate_url(endpoint, options), options[:headers] || {}).body.force_encoding("UTF-8")
    end

    # Performs a http post request to the configured OBS Backend server.
    # @param endpoint [String, Array] Endpoit to connect to.
    # @option options [Hash] :params The parameters to be sent as part of the query in the url.
    # @option options [Hash] :defaults The default parameters values that will be merged with <tt>options[:params]</tt>.
    # @option options [Hash] :rename The parameters to be sent as part of the query in the url.
    # @option options [Array] :accepted Whitelist of keys for the params.
    # @option options [Array] :expand Keys to expand using the same name (no [] are used).
    # @option options [String] :data The data that will be sent in the request.
    # @option options [Hash] :headers The http headers that will be added to the request.
    # @return [String] The body of the request response encoded in UTF-8.
    def post(endpoint, options = {})
      Backend::Connection.post(calculate_url(endpoint, options), options[:data], options[:headers] || {}).body.force_encoding("UTF-8")
    end

    # Performs a http put request to the configured OBS Backend server.
    # @param endpoint [String, Array] Endpoit to connect to.
    # @option options [Hash] :params The parameters to be sent as part of the query in the url.
    # @option options [Hash] :defaults The default parameters values that will be merged with <tt>options[:params]</tt>.
    # @option options [Hash] :rename The parameters to be sent as part of the query in the url.
    # @option options [Array] :accepted Whitelist of keys for the params.
    # @option options [Array] :expand Keys to expand using the same name (no [] are used).
    # @option options [String] :data The data that will be sent in the request.
    # @option options [Hash] :headers The http headers that will be added to the request.
    # @return [String] The body of the request response encoded in UTF-8.
    def put(endpoint, options = {})
      Backend::Connection.put(calculate_url(endpoint, options), options[:data], options[:headers] || {}).body.force_encoding("UTF-8")
    end

    # Performs a http delete request to the configured OBS Backend server.
    # @param endpoint [String, Array] Endpoit to connect to.
    # @option options [Hash] :params The parameters to be sent as part of the query in the url.
    # @option options [Hash] :defaults The default parameters values that will be merged with <tt>options[:params]</tt>.
    # @option options [Hash] :rename The parameters to be sent as part of the query in the url.
    # @option options [Array] :accepted Whitelist of keys for the params.
    # @option options [Array] :expand Keys to expand using the same name (no [] are used).
    # @option options [Hash] :headers The http headers that will be added to the request.
    # @return [String] The body of the request response encoded in UTF-8.
    def delete(endpoint, options = {})
      Backend::Connection.delete(calculate_url(endpoint, options), options[:headers] || {}).body.force_encoding("UTF-8")
    end

    def calculate_url(endpoint, options)
      endpoint = calculate_endpoint(endpoint)
      params = calculate_params(options)
      [endpoint, params].compact.join('?')
    end

    def calculate_params(options)
      return nil if options.blank?
      params = rename_params(options[:params] || {}, options[:rename] || {})
      params = accept_params(params, options[:accepted] || [])
      params = merge_defaults(params, options[:defaults] || {})
      params = expand_params(params, options[:expand] || [])
      return nil if params.blank?
      params.join('&')
    end

    def merge_defaults(params, defaults)
      defaults.merge(params)
    end

    def accept_params(params, accepted)
      params.slice!(*accepted) unless accepted.empty?
      params
    end

    def rename_params(params, renames)
      renames.each do |old_name, new_name|
        params[new_name] = params.delete(old_name) if params.key?(old_name)
      end
      params
    end

    def expand_params(params, expand)
      expanded_params = []
      expand.each do |key|
        expanded_params += params.delete(key).map { |value| value.to_query(key) } if params.key?(key)
      end
      expanded_params += [params.to_query] unless params.empty?
      expanded_params
    end

    def calculate_endpoint(endpoint)
      return endpoint if endpoint.is_a?(String)
      template = endpoint.shift
      values = endpoint.map { |x| CGI.escape(x.to_s) }
      placeholders = template.scan(/(:\w+)/).flatten
      raise "Endpoit not valid: different number of placeholders and values" if values.size != placeholders.size
      placeholders.each_with_index do |placeholder, index|
        template.gsub!(placeholder, values[index])
      end
      template
    end
  end
end
