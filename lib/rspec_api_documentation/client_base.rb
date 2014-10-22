module RspecApiDocumentation
  class ClientBase < Struct.new(:context, :options)
    include Headers

    delegate :example, :app, :to => :context
    delegate :metadata, :to => :example

    def get(*args)
      process :get, *args
    end

    def post(*args)
      process :post, *args
    end

    def put(*args)
      process :put, *args
    end

    def delete(*args)
      process :delete, *args
    end

    def head(*args)
      process :head, *args
    end

    def patch(*args)
      process :patch, *args
    end

    def response_status
      status
    end

    private

    def process(method, path, params = {}, headers ={})
      do_request(method, path, params, headers)
      document_example(method.to_s.upcase, path)
    end

    def document_example(method, path)
      return unless metadata[:document]

      input = last_request.env["rack.input"]
      input.rewind
      request_body = input.read

      request_metadata = {}

      if request_content_type =~ /multipart\/form-data/ && respond_to?(:handle_multipart_body, true)
        request_body = handle_multipart_body(request_headers, request_body)
      end

      request_metadata[:request_method] = method
      request_metadata[:request_path] = path
      request_metadata[:request_body] = request_body.empty? ? nil : request_body
      request_metadata[:request_headers] = request_headers
      request_metadata[:request_query_parameters] = query_hash
      request_metadata[:request_content_type] = request_content_type
      request_metadata[:response_status] = status
      request_metadata[:response_status_text] = Rack::Utils::HTTP_STATUS_CODES[status]
      request_metadata[:response_body] = response_body.empty? ? nil : response_body
      request_metadata[:response_headers] = response_headers
      request_metadata[:response_content_type] = response_content_type
      request_metadata[:curl] = Curl.new(method, path, request_body, request_headers)

      metadata[:requests] ||= []
      metadata[:requests] << request_metadata
      metadata[:example_response] = request_metadata[:response_body]
      if method == 'GET'
        request_url, request_params = path.split('?')
        path = request_url
        request_body = request_params
      end
      metadata[:example_request] = Curl.new(method, path, request_body, {'Content-Type' => 'application/json'}).output("#{ENV['RAD_CULR_HOST']}/")
      #metadata[:example_request] = RspecApiDocumentation::RequestEample.new(request_metadata).to_s

      example.metadata[:response_messages] ||= []
      example.metadata[:response_messages] << { code: request_metadata[:response_status], message: request_metadata[:response_status_text] }
    end

    def query_hash
      strings = query_string.split("&")
      arrays = strings.map do |segment|
        k,v = segment.split("=")
        [k, v && CGI.unescape(v)]
      end
      Hash[arrays]
    end

    def headers(method, path, params, request_headers)
      request_headers || {}
    end
  end
end
