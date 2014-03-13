require 'rspec_api_documentation/writers/formatter'

module RspecApiDocumentation
  module Writers
    class JsonSwaggerWriter < Writer
      delegate :docs_dir, :to => :configuration

      def write
        File.open(docs_dir.join("index.json"), "w+") do |f|
          f.write Formatter.to_json(JsonSwaggerIndex.new(index, configuration))
        end
        write_examples
      end

      def write_examples
        json_examples = {}
        index.examples.each do |example|
          json_example = JsonSwaggerExample.new(example, configuration)
          (json_examples[json_example.dirname] ||= []) << JsonSwaggerExample.new(example, configuration)
        end

        json_examples.each do |dirname, examples|
          File.open(docs_dir.join(dirname + ".json"), "a+") do |f|
            f.write Formatter.to_json(format_examples(examples))
          end
        end
      end

      def format_examples(json_examples)
        {
          basePath: @configuration.base_api_path,
          apiVersion: @configuration.api_version,
          apis: []
        }
      end
    end

    class JsonSwaggerIndex
      def initialize(index, configuration)
        @index = index
        @configuration = configuration
      end

      def sections
        IndexHelper.sections(examples, @configuration)
      end

      def examples
        @index.examples.map { |example| JsonSwaggerExample.new(example, @configuration) }
      end

      def as_json(opts = nil)
        {
          basePath: @configuration.base_api_path,
          apiVersion: @configuration.api_version,
          apis: section_hash
        }
      end

      def section_hash
        sections.map do |section|
          {
            path: section[:examples].first.metadata[:root_path],
            description: section[:resource_name]
          }
        end
      end
    end

    class JsonSwaggerExample
      def initialize(example, configuration)
        @example = example
        @host = configuration.curl_host
        @filter_headers = configuration.curl_headers_to_filter
      end

      def method_missing(method, *args, &block)
        @example.send(method, *args, &block)
      end

      def respond_to?(method, include_private = false)
        super || @example.respond_to?(method, include_private)
      end

      def dirname
        resource_name.downcase.gsub(/\s+/, '_')
      end

      def filename
        basename = description.downcase.gsub(/\s+/, '_').gsub(/[^a-z_]/, '')
        "#{basename}.json"
      end

      def as_json(opts = nil)
        {
          method: method,
          operations: [],
          resource: resource_name,
          :http_method => http_method,
          :description => description,
          :explanation => explanation,
          :parameters => respond_to?(:parameters) ? parameters : [],
        }
      end

      def requests
        super.map do |hash|
          if @host
            if hash[:curl].is_a? RspecApiDocumentation::Curl
              hash[:curl] = hash[:curl].output(@host, @filter_headers)
            end
          else
            hash[:curl] = nil
          end
          hash
        end
      end
    end
  end
end
