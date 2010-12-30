require "rubygems"
require "cutest"

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
  attr :versions
  attr :runtime_dependees
  attr :gems_to_remove
  attr :gems_missing

  def initialize(gems_list)
    @versions = Hash.new { |hash, key| hash[key] = [] }
    @runtime_dependees = Hash.new { |hash, key| hash[key] = [] }

    @gems_to_remove = []
    @gems_missing = []

    populate_lists(gems_list)
  end

  def resolve!
    remove = []

    runtime_dependees.each do |name, dependees|
      keep, _remove = versions[name].sort.partition do |gem|
        dependees.all? do |dependee|
          dep = dependee.runtime_dependencies.detect do |dep|
            dep.name == name
          end

          dep && dep.match?(gem.name, gem.version)
        end
      end

      remove.concat(_remove) unless _remove.empty?
      remove.concat(keep[1..-1]) if keep[1..-1]


      if keep.empty?
        deps = dependees.map do |dependee|
          dependee.runtime_dependencies.detect do |dep|
            dep.name == name
          end.requirement.to_s
        end

        @gems_missing << [name, deps]
      end
    end


    @gems_to_remove = remove
  end

private

  def populate_lists(gems_list)
    gems_list.each do |gem|
      @versions[gem.name] << gem

      gem.runtime_dependencies.each do |dep|
        @runtime_dependees[dep.name] << gem
      end
    end
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
  assert_equal "1", resolver.versions["a"].first.version.to_s
  assert_equal "1", resolver.versions["b"].first.version.to_s
  assert_equal "1", resolver.versions["x"].first.version.to_s
  assert_equal "2", resolver.versions["x"].last.version.to_s
end

test do |gems|
  resolver = Resolver.new(gems)
  assert_equal [],  resolver.runtime_dependees["a"]
  assert_equal [],  resolver.runtime_dependees["b"]
  assert_equal "a", resolver.runtime_dependees["x"].first.name
  assert_equal "1", resolver.runtime_dependees["x"].first.version.to_s
  assert_equal "b", resolver.runtime_dependees["x"].last.name
  assert_equal "1", resolver.runtime_dependees["x"].last.version.to_s
end

test do |gems|
  resolver = Resolver.new(gems)

  resolver.resolve!

  assert_equal [gemspec("x", "2")], resolver.gems_to_remove
end

setup do
  [].tap do |gems|
    gems << gemspec("a", "1.0.0", "b" => ">= 0")
    gems << gemspec("b", "1.0.0", "x" => "~> 1.0.0")
    gems << gemspec("x", "1.0.0")
    gems << gemspec("x", "1.1.0")
    gems << gemspec("x", "1.2.0")
  end
end

test do |gems|
  resolver = Resolver.new(gems)
  resolver.resolve!

  assert resolver.gems_to_remove.include?(gemspec("x", "1.1.0"))
  assert resolver.gems_to_remove.include?(gemspec("x", "1.2.0"))
  assert !resolver.gems_to_remove.include?(gemspec("x", "1.0.0"))
  assert !resolver.gems_to_remove.include?(gemspec("a", "1.0.0", "b" => ">= 0"))
  assert !resolver.gems_to_remove.include?(gemspec("b", "1.0.0", "x" => "~> 1.0.0"))
end

setup do
  [].tap do |gems|
    gems << gemspec("a", "1", "x" => "< 3")   # 02/02/2010
    gems << gemspec("b", "1", "x" => ">= 2")  # 04/04/2010
    gems << gemspec("x", "1")                 # 01/01/2010
    gems << gemspec("x", "3")                 # 03/03/2010
  end
end

test "missing gems" do |gems|
  resolver = Resolver.new(gems)
  resolver.resolve!

  assert resolver.gems_to_remove.include?(gemspec("x", "1"))
  assert resolver.gems_to_remove.include?(gemspec("x", "3"))
  assert resolver.gems_missing.include?(["x", ["< 3", ">= 2"]])
end
