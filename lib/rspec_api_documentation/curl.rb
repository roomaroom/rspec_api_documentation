require 'active_support/core_ext/object/to_query'
require 'base64'

module RspecApiDocumentation
  class Curl < Struct.new(:method, :path, :data, :headers)
    attr_accessor :host

    def output(config_host, config_headers_to_filer = nil)
      self.host = config_host
      @config_headers_to_filer = Array(config_headers_to_filer)
      send(method.downcase)
    end

    def post
      "curl \"#{url}\" #{post_data} -X POST #{headers}"
    end

    def get
      "curl \"#{url}#{get_data[:uri]}\" #{get_data[:json]} -X GET #{headers}"
    end

    def head
      "curl \"#{url}#{get_data[:uri]}\" #{get_data[:json]} -X GET #{headers}"
    end

    def put
      "curl \"#{url}\" #{post_data} -X PUT #{headers}"
    end

    def delete
      "curl \"#{url}\" #{post_data} -X DELETE #{headers}"
    end

    def patch
      "curl \"#{url}\" #{post_data} -X PATCH #{headers}"
    end

    def url
      "#{host}#{path}"
    end

    def headers
      filter_headers(super).map do |k, v|
        if k =~ /authorization/i && v =~ /^Basic/
          " -u #{format_auth_header(v)}"
        else
          " -H \"#{format_full_header(k, v)}\""
        end
      end.join(" ")
    end

    def get_data
      unless data.blank?
        formatted_data = Rack::Utils.parse_nested_query(data).with_indifferent_access
        auth_token = formatted_data.delete('auth_token')
        {
          uri: "?auth_token=#{auth_token}",
          json: "-d '#{formatted_data.to_json}'"
        }
      else
        {}
      end
    end

    def post_data
      formatted_data = Rack::Utils.parse_nested_query(data).to_json
      "-d '#{formatted_data}'"
    end

    private

    def format_auth_header(value)
      ::Base64.decode64(value.split(' ', 2).last || '')
    end

    def format_header(header)
      header.gsub(/^HTTP_/, '').titleize.split.join("-")
    end

    def format_full_header(header, value)
      formatted_value = value ? value.gsub(/"/, "\\\"") : ''
      "#{format_header(header)}: #{formatted_value}"
    end

    def filter_headers(headers)
      if !@config_headers_to_filer.empty?
        headers.reject do |header|
          @config_headers_to_filer.include?(format_header(header))
        end
      else
        headers
      end
    end
  end
end
