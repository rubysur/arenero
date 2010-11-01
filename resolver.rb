ENV['GEM_HOME'] = File.expand_path('tmp/arenero/gems')
ENV['GEM_PATH'] = ''

require "rubygems"
require "cutest"
require "ruby-debug"

def gemspec(name, version, dependencies = {})
  Gem::Specification.new do |spec|
    spec.name = name
    spec.version = version
    spec.summary = name
    dependencies.each do |dep|
      spec.add_dependency(*dep)
    end
  end
end

test do
  assert_equal "1", gemspec("x", 1).version.to_s
  assert_equal ">= 1", gemspec("a", 1, "x" => ">= 1").runtime_dependencies.first.requirement.to_s
  assert_equal "= 1", gemspec("a", 1, "x" => "1").runtime_dependencies.first.requirement.to_s
end

class Resolver
  attr :a
  attr :b
  attr :gems_to_remove

  def initialize(gems)
    @gems = gems
    @a = Hash.new { |hash, key| hash[key] = [] }
    @b = Hash.new { |hash, key| hash[key] = [] }

    @gems_to_remove = []

    populate_lists
  end

  def resolve!
    remove = []

    b.each do |name, dependees|
      a[name].sort!
      keep, _remove = a[name].partition do |gem|
        dependees.all? do |dependee|
          dep = dependee.runtime_dependencies.detect {|dep| dep.name == name }
          dep && dep.match?(gem.name, gem.version)
        end
      end

      remove.concat(_remove) unless _remove.empty?
      remove.concat(keep[1..-1]) if keep[1..-1]
    end

    @gems_to_remove = remove
  end

private

  def populate_lists
    @gems.each do |gem|
      @a[gem.name] << gem

      gem.runtime_dependencies.each do |dep|
        @b[dep.name] << gem
      end
    end
  end
end

A = Hash.new { |hash, key| hash[key] = [] }
B = Hash.new { |hash, key| hash[key] = [] }

Gem.source_index.gems.each do |_, gem|
  A[gem.name] << gem

  gem.runtime_dependencies.each do |dep|
    B[dep.name] << gem
  end
end

setup do
  [].tap do |gems|
    gems << gemspec("a", 1, "x" => ">= 1")
    gems << gemspec("b", 1, "x" => "1")
    gems << gemspec("x", 1)
    gems << gemspec("x", 2)
  end
end

test do |gems|
  resolver = Resolver.new(gems)
  assert_equal "1", resolver.a["a"].first.version.to_s
  assert_equal "1", resolver.a["b"].first.version.to_s
  assert_equal "1", resolver.a["x"].first.version.to_s
  assert_equal "2", resolver.a["x"].last.version.to_s
end

test do |gems|
  resolver = Resolver.new(gems)
  assert_equal [],  resolver.b["a"]
  assert_equal [],  resolver.b["b"]
  assert_equal "a", resolver.b["x"].first.name
  assert_equal "1", resolver.b["x"].first.version.to_s
  assert_equal "b", resolver.b["x"].last.name
  assert_equal "1", resolver.b["x"].last.version.to_s
end

test do |gems|
  resolver = Resolver.new(gems)

  resolver.resolve!

  assert_equal [gemspec("x", "2")], resolver.gems_to_remove
end

setup do
  gems = []

  foo = gemspec("foo", "1.0.0", "bar" => ">= 0")
  bar = gemspec("bar", "1.0.0", "baz" => "~> 1.0.0")

  gems << foo
  gems << bar

  gems << gemspec("baz", "1.0.0")
  gems << gemspec("baz", "1.1.0")
  gems << gemspec("baz", "1.2.0")

  [gems, foo, bar]
end

test do |gems, foo, bar|
  resolver = Resolver.new(gems)
  resolver.resolve!

  assert resolver.gems_to_remove.include?(gemspec("baz", "1.1.0"))
  assert resolver.gems_to_remove.include?(gemspec("baz", "1.2.0"))
  assert !resolver.gems_to_remove.include?(gemspec("baz", "1.0.0"))
  assert !resolver.gems_to_remove.include?(foo)
  assert !resolver.gems_to_remove.include?(bar)
end

setup do
  gems = []

  a = gemspec("a", "1", "x" => "< 3")   # 02/02/2010
  b = gemspec("b", "1", "x" => ">= 2")  # 04/04/2010

  gems << a
  gems << b

  gems << gemspec("x", "1") # 01/01/2010
  gems << gemspec("x", "3") # 03/03/2010

  [gems, a, b]
end

test "missing gems" do |gems, foo, bar|
  resolver = Resolver.new(gems)
  resolver.resolve!

  assert resolver.gems_to_remove.include?(gemspec("x", "1"))
  assert resolver.gems_to_remove.include?(gemspec("x", "3"))
  assert resolver.gems_missing.include?("x")
end
