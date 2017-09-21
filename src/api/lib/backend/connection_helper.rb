# API for connecting to the backend
module Backend
  module ConnectionHelper
    # Performs a get action
    def get(endpoint, options = {})
      Backend::Connection.get(calculate_url(endpoint, options), options[:headers] || {}).body.force_encoding("UTF-8")
    end

    # Performs a post action
    def post(endpoint, options = {})
      Backend::Connection.post(calculate_url(endpoint, options), options[:data], options[:headers] || {}).body.force_encoding("UTF-8")
    end

    # Performs a put action
    def put(endpoint, options = {})
      Backend::Connection.put(calculate_url(endpoint, options), options[:data], options[:headers] || {}).body.force_encoding("UTF-8")
    end

    # Performs a delete action
    def delete(endpoint, options = {})
      Backend::Connection.delete(calculate_url(endpoint, options), options[:headers] || {}).body.force_encoding("UTF-8")
    end

    private

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
