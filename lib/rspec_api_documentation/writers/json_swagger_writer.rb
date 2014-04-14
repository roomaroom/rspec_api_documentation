require 'rspec_api_documentation/writers/formatter'

module RspecApiDocumentation
  module Writers
    class JsonSwaggerWriter < Writer
      delegate :docs_dir, :to => :configuration

      def write
        FileUtils.rm_rf docs_dir.join('v1')
        FileUtils.mkdir_p(docs_dir.join('v1'))

        File.open(docs_dir.join('v1', "index.json"), "w+") do |f|
          f.write Formatter.to_json(JsonSwaggerIndex.new(index, configuration))
        end
        write_examples
      end

      def write_examples
        json_examples = {}
        a = []
        index.examples.each do |example|
          unless example.mute
            a << example.route
            json_example = JsonSwaggerExample.new(example, configuration)
            dirname = example.route.split('/').reject(&:blank?)
            FileUtils.mkdir_p(docs_dir.join(dirname[0..-2].join('/')))
            #(json_examples[docs_dir.join(dirname.join('/') << '.json')] ||= []) << JsonSwaggerExample.new(example, configuration)
            (json_examples[docs_dir.join('v1', (example.root_path.gsub(/^\//, "") << '.json'))] ||= []) << JsonSwaggerExample.new(example, configuration)
          end
        end

        json_examples.each do |dirname, examples|
          #directory = File.dirname(dirname)

          File.open(docs_dir.join(dirname), "a+") do |f|
            f.write Formatter.to_json(format_examples(examples))
          end
        end
      end

      def format_examples(json_examples)
        json_examples_sorted = {}
        json_examples.each do |example|
          root_path = example.root_path
          root_path = example.modified_root_path if example.try(:modified_root_path)
          (json_examples_sorted[root_path] ||= []) << example
        end

        {
          basePath: @configuration.base_api_path,
          apiVersion: @configuration.api_version,
          apis: json_examples_sorted.map { |path, examples| { path: path, operations: examples } }
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
          method:     http_method,
          type:       resource_name,
          summary:    description,
          nickname:   "#{http_method}#{resource_name}",
          parameters: respond_to?(:parameters) ? formatted_parameters : [],
          responseMessages: []
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

      def formatted_parameters
        parameters
      end
    end
  end
end
