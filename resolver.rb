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

  def initialize(gems)
    @gems = gems
    @a = Hash.new { |hash, key| hash[key] = [] }
    @b = Hash.new { |hash, key| hash[key] = [] }

    populate_lists
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

remove = []

B.each do |name, dependees|
  A[name].sort!
  keep, _remove = A[name].partition do |gem|
    dependees.all? do |dependee|
      dep = dependee.runtime_dependencies.detect {|dep| dep.name == name }
      dep && dep.match?(gem.name, gem.version)
    end
  end

  remove.concat(_remove).concat(keep[1..-1])
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
