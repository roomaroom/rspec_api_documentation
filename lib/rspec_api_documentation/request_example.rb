module RspecApiDocumentation
  class RequestExample
    attr_accessor :request_metadata

    def initialize(request_metadata)
      @request_metadata = request_metadata
    end

    def to_s
      raise request_metadata[:method].to_yaml
    end
  end
end