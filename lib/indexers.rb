require 'indexers/dsl/api'
require 'indexers/dsl/mappings'
require 'indexers/dsl/traitable'
require 'indexers/dsl/search'
require 'indexers/dsl/serialization'
require 'indexers/extensions/active_record/base'
require 'indexers/collection'
require 'indexers/computed_sorts'
require 'indexers/concern'
require 'indexers/configuration'
require 'indexers/definitions'
require 'indexers/indexer'
require 'indexers/pagination'
require 'indexers/proxy'
require 'indexers/railtie'
require 'indexers/version'

module Indexers
  class << self

    def namespace
      "#{Rails.application.class.parent_name} #{Rails.env}".parameterize(separator: '_')
    end

    def client
      @client ||= begin
        require 'elasticsearch'
        config = YAML.load_file("#{Rails.root}/config/elasticsearch.yml")[Rails.env]
        Elasticsearch::Client.new config.deep_symbolize_keys
      end
    end

    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def computed_sorts
      @computed_sorts ||= ComputedSorts.new
    end

    def definitions
      @definitions ||= Definitions.new
    end

    def define(*args, &block)
      Proxy.new *args, &block
    end

    def index
      unless client.indices.exists?(index: namespace)
        client.indices.create(
          index: namespace,
          body: { settings: configuration.analysis }
        )
      end
      definitions.each &:build
    end

    def reindex
      unindex
      index
    end

    def unindex
      if client.indices.exists?(index: namespace)
        client.indices.delete index: namespace
      end
    end

    def suggest(*args)
      response = client.suggest(
        index: namespace,
        body: { suggestions: Dsl::Api.new(args, &configuration.suggestions).to_h }
      )
      response['suggestions'].first['options'].map &:symbolize_keys
    end

  end
end
