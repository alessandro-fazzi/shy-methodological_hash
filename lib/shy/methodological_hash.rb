# frozen_string_literal: true

require_relative "methodological_hash/version"
require "json"

module Shy
  class MethodologicalHash # rubocop:disable Style/Documentation
    class Error < StandardError; end

    def initialize(hash, path = [])
      @document = JSON.parse(JSON.dump(hash), symbolize_names: true)
      @path = path
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
      document.transform_values { _1.is_a?(Shy::MethodologicalHash) ? _1.to_h : _1 }
    end

    def unwrap = to_h

    private

    attr_reader :document
    attr_accessor :path

    def generate_methods! # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      document.each do |key, value|
        nested_path = path + Array(key)

        document[key] = generate_nested(value, nested_path) if value.is_a?(Hash)

        unless respond_to?(key)
          define_singleton_method key do
            document[key]
          end
        end

        define_singleton_method :"#{key}=" do |new_value|
          new_value = generate_nested(new_value, nested_path) if new_value.is_a?(Hash)
          document[key] = new_value
        end
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
