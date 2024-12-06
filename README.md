> [!WARNING]
> This is a POC, born unmaintained by its own nature.

# Shy::MethodologicalHash

No-ceremony *embedded document* pattern for hashes.

## Installation

> [!NOTE]
> This gem is not and will not be published on rubygems since it's just a POC

Install the gem and add to the application's Gemfile by executing:

    $ bundle add shy-methodological_hash --github "alessandro-fazzi/shy-methodological_hash"

## Usage

Given an hash

```ruby
user_hash = {
  id: 1,
  name: "Alessandro",
  preferences: {
    languages: ["italian", "ruby", "english"],
    color: "green"
  }
}
```

you maybe want to *embed* it into an object before propagating it throughout
your entire system. `Shy::MethodologicalHash` is a device to cut-out all the
ceremony, still letting the resulting object open to extension.

By default you'll get accessors methods on hash's keys.

```ruby
class User < Shy::MethodologicalHash; end

user = User.new(user_hash)

user.id # 1
user.preferences.color # "green"
```

and nested hashes will be converted to `Shy::MethodologicalHash` instances

```ruby
user
# =>
# #<User:0x000000011c8bf6b0
#  @document=
#   {:id=>1,
#    :name=>"Alessandro",
#    :preferences=>
#     #<Shy::MethodologicalHash:0x000000011c8bf0e8
#      @document={:languages=>["italian", "ruby", "english"], :color=>"green"},
#      @path=[:preferences]>},
#  @path=[]>
```

You can obtain the embedded document as an hash with `#unwrap` or `#to_h` methods

```ruby
user.unwrap
# => {:id=>1, :name=>"Alessandro", :preferences=>{:languages=>["italian", "ruby", "english"], :color=>"green"}}
```

It's possible to set values on keys, but, by design, it's not possible to
add or remove keys to the embedded document (the hash).

```ruby
user.id = 3
```

You can extend the object like any other PORO. The instance has access to
generated accessor methods.

```ruby
class User < Shy::MethodologicalHash
  def aka
    name + " aka Fuzzy"
  end

  def languages
    preferences.languages
  end
end

user = User.new(user_hash)
user.aka # "Alessandro aka Fuzzy"
user.languages # ["italian", "ruby", "english"]
```

You can override a getter/setter by the help of the `document` method like this:

```ruby
class User < Shy::MethodologicalHash
  def preferences
    puts "overridden preferences"
    document[:preferences]
  end
end

user = User.new(user_hash)
user.preferences
# overridden preferences
# #<Shy::MethodologicalHash:0x000000011cbdafe8
#  @document={:languages=>["italian", "ruby", "english"], :color=>"green"},
#  @path=[:preferences]>
```

### Nested hashes

As noticed in the previous snippet, any nested hash will be vivified into a
nested `Shy::MethodologicalHash` object.

It's possible to decorate each nested object using the `decorate_path` class
method; it has two different signatures:

1. `.decorate_path(path, &block)`
1. `.decorate_path(path, SomeClass)`

`path` is an array of symbols where each one is a key in the hash. E.g., for
this hash

```ruby
{a: {b: {c: 1}}}
```

`[:a, :b]` is the path for the inner hash `{c: 1}`.

Keep in mind that's only possible to decorate **nested hashes**: if you give a
path to something else then the decoration will be ignored. An example:

```ruby
class User < Shy::MethodologicalHash
  decorate_path [:preferences] do
    def light_color
      "light #{color}"
    end
  end
end

user = User.new(user_hash)
user.preferences.light_color
# "light green"
```

You can decorate hashes at any nesting level, but you must always
specify the "absolute" path starting from the root. This should make sense
because an hash could have multiple keys with the same name inside different
nested hashes, thus the gem needs a full path in order to have a uniq identifier.

Here's an example

```ruby
my_hash = {
  a: {
    b: {
      c: { foo: 1}
    },
    d: {
      c: { foo: 2}
    }
  }
}

class MyHash < Shy::MethodologicalHash
  decorate_path [:a] do
    decorate_path [:a, :b] do
      decorate_path [:a, :b, :c] do
        def double_foo
          foo * 2
        end
      end
    end

    decorate_path [:a, :d] do
      def hello
        "hello #{document}"
      end

      decorate_path [:a, :d, :c] do
        def triple_foo
          foo * 3
        end
      end
    end
  end
end

methodological = MyHash.new(my_hash)
methodological.a.b.c.double_foo
# 2
methodological.a.d.c.triple_foo
# 6
methodological.a.d.hello
# "hello {:c=>#<MyHash([:a, :d, :c]):0x000000011ef31690 @document={:foo=>2}, @path=[:a, :d, :c]>}"
```

> [!NOTE]
> when decorating this way, nested objects have a decorated class name such as
> `MyHash([:a, :d])` representing the path they're actually decorating. The goal
> is to make sense of complex objects at a glance.

With the same approach you can decorate nested hashes your types. Those classes
can but are not expected to inherit from `Shy::MethodologicalHash`. Custom
classes are just required to have a constructor with to positional arguments:

1. `hash` is the nested hash we're going to decorate
1. `path` is the path illustrated above; probably you'll just want to discard it

```ruby
my_hash = {a: {foo: 1}, b: {foo: 2}}
class A < Shy::MethodologicalHash
  def a_foo
    "A #{foo}"
  end
end

class B
  def initialize(hash, _path)
    @hash = hash
  end

  def b_foo
    "B #{@hash.fetch(:foo)}"
  end
end

class MyHash < Shy::MethodologicalHash
  decorate_path [:a], A
  decorate_path [:b], B
end

methodological = MyHash.new(my_hash)
methodological
methodological
# =>
# #<MyHash:0x000000011e3ec320
#  @document=
#   {:a=>#<A:0x000000011e3ec0a0 @document={:foo=>1}, @path=[:a]>, :b=>#<B:0x000000011e3eb8f8 @hash={:foo=>2}>},
#  @path=[]>
methodological.a.a_foo
# "A 1"
methodological.b.b_foo
# "B 2"
methodological.a.foo
# 1
methodological.b.foo
# undefined method `foo' for an instance of B (NoMethodError)
```

Decorations can be placed "ahead of existence"; if you start with a hash not
having an optional key, but you foresee that key could be added with a nested
hash as value, then you can do something like

```ruby
my_hash = {a: {}}
class MyHash < Shy::MethodologicalHash
  decorate_path [:a] do
    decorate_path [:a, :b] do
      def double_bar
        bar * 2
      end
    end
  end
end

methodological = MyHash.new(my_hash)
methodological
# #<MyHash:0x000000011ffb0138
#  @document={:a=>#<MyHash([:a]):0x000000011ff3fe38 @document={}, @path=[:a]>},
#  @path=[]>
methodological.a = {b: {bar: 1}}
# {:b=>{:bar=>1}}
methodological.a.b.double_bar
# 2
```

## Why?

When you have a peripheral object or an external service producing a hash
(or json), propagating the hash itself through various levels of your stack
may be risky: all the consumers along the way will depend on hash's structure.

Depending on a data structure is generally a maintenance pain and a rigid
constraint.

On the other hand manually creating objects to menage nested hashes can be
tedious or overkill in some scenarios.

This gem bridges you from the uncontrolled data structure to the 100% hand
written nested objects solution, sitting in the middle, requiring no or very
few code and being hot-replaceable by custom solution would you need it.

## How much slower it is?

Actually it's slightly faster then a Hash in reading operations, but 10 times
slower in writing operations.

Just to add some confusion I've
added Hashie::Mash to the comparison. Mash does a LOT more than this gem, but
this demonstrate that Mash could be overkill if you just need talk through
messages to an hash.

> [!TIP]
> See bin/bench for the code

```
ruby 3.3.5 (2024-09-03 revision ef084cc8f4) +YJIT [arm64-darwin24]
Warming up --------------------------------------
           hash read   707.670k i/100ms
 methodological read   724.319k i/100ms
    hashie mash read    90.458k i/100ms
Calculating -------------------------------------
           hash read      7.468M (± 0.5%) i/s  (133.91 ns/i) -     37.507M in   5.022652s
 methodological read      8.146M (± 0.3%) i/s  (122.76 ns/i) -     41.286M in   5.068251s
    hashie mash read    914.278k (± 0.5%) i/s    (1.09 μs/i) -      4.613M in   5.046037s

Comparison:
 methodological read:  8146107.3 i/s
           hash read:  7467670.2 i/s - 1.09x  slower
    hashie mash read:   914277.8 i/s - 8.91x  slower

ruby 3.3.5 (2024-09-03 revision ef084cc8f4) +YJIT [arm64-darwin24]
Warming up --------------------------------------
          hash write     1.529M i/100ms
methodological write   151.902k i/100ms
   hashie mash write    46.589k i/100ms
Calculating -------------------------------------
          hash write     16.872M (± 0.1%) i/s   (59.27 ns/i) -     85.650M in   5.076585s
methodological write      1.542M (± 0.5%) i/s  (648.36 ns/i) -      7.747M in   5.023005s
   hashie mash write    469.129k (± 0.3%) i/s    (2.13 μs/i) -      2.376M in   5.064827s

Comparison:
          hash write: 16871691.0 i/s
methodological write:  1542344.4 i/s - 10.94x  slower
   hashie mash write:   469128.9 i/s - 35.96x  slower
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/alessandro-fazzi/shy-methodological_hash. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/alessandro-fazzi/shy-methodological_hash/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Shy::MethodologicalHash project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/alessandro-fazzi/shy-methodological_hash/blob/main/CODE_OF_CONDUCT.md).
