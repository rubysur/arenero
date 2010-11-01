ENV['GEM_HOME'] = File.expand_path('tmp/arenero/gems')
ENV['GEM_PATH'] = ''

require "rubygems"
require "cutest"
require "ruby-debug"

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

puts "Remove: #{remove.inspect}"

test do
  assert_equal "x", remove.first.name
  assert_equal "2", remove.first.version.to_s
end

test do
  assert_equal "1", A["a"].first.version.to_s
  assert_equal "1", A["b"].first.version.to_s
  assert_equal "1", A["x"].first.version.to_s
  assert_equal "2", A["x"].last.version.to_s
end

test do
  assert_equal [],  B["a"]
  assert_equal [],  B["b"]
  assert_equal "a", B["x"].first.name
  assert_equal "1", B["x"].first.version.to_s
  assert_equal "b", B["x"].last.name
  assert_equal "1", B["x"].last.version.to_s
end

test do
#  assert_equal({"a" => "1", "b" => "1", "x" => "1"}, resolved_dependencies)
end

puts
