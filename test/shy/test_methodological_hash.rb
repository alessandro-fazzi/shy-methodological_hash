# frozen_string_literal: true

require "test_helper"

module Shy
  class TestMethodologicalHash < Minitest::Test
    def setup # rubocop:disable Metrics/MethodLength
      @hash = {
        foo: 1,
        bar: {
          foo: 2,
          bar: {
            foo: 3
          },
          baz: {
            foo: "Foo"
          }
        },
        baz: [
          { foo: 1 },
          { foo: 2 }
        ]
      }
    end

    class PlainHash < self
      class MyHash < ::Shy::MethodologicalHash
        def bar_bar_foo
          bar.bar.foo
        end
      end

      def setup
        super
        @subject = MyHash.new(@hash)
      end

      def test_it_is_navigable_by_method_chains
        assert_equal 1, @subject.foo
        assert_equal 2, @subject.bar.foo
        assert_equal 3, @subject.bar.bar.foo
        assert_equal "Foo", @subject.bar.baz.foo
      end

      def test_it_can_me_dumped_as_hash
        assert_equal @hash, @subject.to_h
      end

      def test_aliases_to_h_as_unwrap
        assert_respond_to @subject, :unwrap
        assert_equal @subject.to_h, @subject.unwrap
      end

      def test_values_has_setter
        assert_equal "Foo", @subject.bar.baz.foo

        @subject.bar.baz.foo = "Bar"

        assert_equal "Bar", @subject.bar.baz.foo
      end

      def test_each_nested_hash_is_methodological
        assert_kind_of Shy::MethodologicalHash, @subject
        assert_kind_of Shy::MethodologicalHash, @subject.bar
        assert_kind_of Shy::MethodologicalHash, @subject.bar.bar
        assert_kind_of Shy::MethodologicalHash, @subject.bar.baz
        @subject.baz.each do |member|
          assert_kind_of Shy::MethodologicalHash, member
        end
      end

      def test_methods_on_root_class_have_access_to_dynamically_generated_ones
        assert_equal 3, @subject.bar_bar_foo
      end

      def test_arrays_are_correctly_handled
        assert_equal 1, @subject.baz[0].foo
        assert_equal 2, @subject.baz[1].foo
      end
    end

    class Decorated < self
      module Common
        def test_decoration_works
          assert_equal "nested one level", @subject.bar.spam
          assert_equal "nested two levels", @subject.bar.bar.spam
        end

        def test_methods_added_by_decorator_have_access_to_original_methods
          assert_equal "FooFoo", @subject.bar.baz.double_foo
        end

        def test_an_hash_lately_added_through_setters_is_correctly_decorated_on_the_fly
          @subject.bar = { sausage: { foo: 42 } }

          assert_equal "for sure", @subject.bar.sausage.it_works
        end

        def test_methods_on_root_class_have_access_to_dynamically_generated_ones
          assert_equal true, @subject.new_method
          assert_equal({ foo: 3 }, @subject.delegator)
        end

        def test_decoration_works_on_array_of_hashes
          assert_equal 2, @subject.baz[0].double_foo
          assert_equal 4, @subject.baz[1].double_foo
        end
      end

      class WithDSL < self
        include Common

        class MyHash < ::Shy::MethodologicalHash
          def new_method
            true
          end

          def delegator
            bar.bar.to_h
          end

          decorate_path [:bar] do
            def spam = "nested one level"

            decorate_path [:bar, :bar] do
              def spam = "nested two levels"
            end

            decorate_path [:bar, :baz] do
              def double_foo = foo * 2
            end

            decorate_path [:bar, :sausage] do
              def it_works = "for sure"
            end
          end

          decorate_path [:baz] do
            def double_foo
              foo * 2
            end
          end
        end

        def setup
          super
          @subject = MyHash.new(@hash)
        end

        def test_nested_hashes_have_custom_class_names
          assert_equal "MyHash([:bar])", @subject.bar.class.to_s
          assert_equal "MyHash([:bar, :bar])", @subject.bar.bar.class.to_s
          assert_equal "MyHash([:bar, :baz])", @subject.bar.baz.class.to_s
        end

        def test_each_nested_hash_is_methodological
          assert_kind_of Shy::MethodologicalHash, @subject
          assert_kind_of Shy::MethodologicalHash, @subject.bar
          assert_kind_of Shy::MethodologicalHash, @subject.bar.bar
          assert_kind_of Shy::MethodologicalHash, @subject.bar.baz
        end
      end

      class WithCustomClasses < self
        include Common

        class Bar < ::Shy::MethodologicalHash
          def spam = "nested one level"

          class Bar < ::Shy::MethodologicalHash
            def spam = "nested two levels"
          end

          class Baz < ::Shy::MethodologicalHash
            def double_foo = foo * 2
          end

          class Sausage < ::Shy::MethodologicalHash
            def it_works = "for sure"
          end

          decorate_path %i[bar bar], Bar

          decorate_path %i[bar baz], Baz

          decorate_path %i[bar sausage], Sausage
        end

        class Baz < ::Shy::MethodologicalHash
          def double_foo
            foo * 2
          end
        end

        class MyHash < ::Shy::MethodologicalHash
          def new_method
            true
          end

          def delegator
            bar.bar.to_h
          end

          decorate_path [:bar], Bar
          decorate_path [:baz], Baz
        end

        def setup
          super
          @subject = MyHash.new(@hash)
        end

        def test_nested_hashes_have_assigned_classes
          assert_equal Bar, @subject.bar.class
          assert_equal Bar::Bar, @subject.bar.bar.class
          assert_equal Bar::Baz, @subject.bar.baz.class
        end
      end
    end
  end
end
