# frozen_string_literal: true

require_relative "methodological_hash/version"
require "json"

module Shy
  class MethodologicalHash # rubocop:disable Style/Documentation
    class Error < StandardError; end

    def initialize(hash, path = [])
      @__document = JSON.parse(JSON.dump(hash), symbolize_names: true)
      @__path = path
      generate_methods!
    end

    class << self
      def decorate_path(path, klass = nil, &block) # rubocop:disable Metrics/MethodLength
        raise Error, "give a class as second positional argument OR a block" if klass && block_given?

        if klass
          types[path.freeze] = klass
          return
        end

        raise Error, "pass a class as second positional argument OR a block" unless block_given?

        dn = demodulized_name

        types[path.freeze] = Class.new(Shy::MethodologicalHash) do
          set_temporary_name "#{dn}(#{path})"
          class_eval(&block)
        end
      end

      def types
        @types ||= {}
      end

      def demodulized_name
        if (i = name.rindex("::"))
          name[(i + 2), name.length]
        else
          name
        end.gsub(/\(.*\)/, "")
      end
    end

    def to_h
      __document.transform_values do |value|
        case value
        in Shy::MethodologicalHash
          value.to_h
        in Array if value.all? { _1.is_a?(Shy::MethodologicalHash) }
          value.map(&:to_h)
        else
          value
        end
      end
    end

    def unwrap = to_h

    private

    attr_reader :__document
    attr_accessor :__path

    def generate_methods!
      __document.each do |key, value|
        nested_path = __path + Array(key)

        set(key:, value:, nested_path:)

        self.class.attr_reader(key) unless respond_to?(key)

        define_singleton_method :"#{key}=" do |new_value|
          set(key:, value: new_value, nested_path:)
        end
      end
    end

    def set(key:, value:, nested_path:)
      __document[key] = instance_variable_set("@#{key}", handle_value(value:, nested_path:))
    end

    def handle_value(value:, nested_path:)
      case value
      in Hash
        generate_nested(value, nested_path)
      in Array if value.all? { _1.is_a?(Hash) }
        value.map do
          generate_nested(_1, nested_path)
        end
      else
        value
      end
    end

    def generate_nested(hash, nested_path)
      klass = special_hash_for(nested_path) || Shy::MethodologicalHash
      klass.new(hash, nested_path)
    end

    def special_hash_for(path)
      self.class.types[path]
    end
  end
end
