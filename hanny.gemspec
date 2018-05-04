
lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hanny/version'

Gem::Specification.new do |spec|
  spec.name          = 'hanny'
  spec.version       = Hanny::VERSION
  spec.authors       = ['yoshoku']
  spec.email         = ['yoshoku@outlook.com']

  spec.summary       = 'Hanny is a Hash-based Approximate Nearest Neighbor search library in Ruby.'
  spec.description   = <<MSG
Hanny is a Hash-based Approximate Nearest Neighbor (ANN) search library in Ruby.
Hash-based ANN converts vector data into binary codes and builds a hash table by using the binary codes as hash keys.
To build the hash table, Hanny uses Locality Sensitive Hashing (LSH) of approximating cosine similarity.
It is known that if the code length is sufficiently long (ex. greater than 128-bit), LSH can obtain high search performance.
In the experiment, Hanny achieved about twenty times faster search speed than the brute-force search by Euclidean distance.
MSG
  spec.homepage      = 'https://github.com/yoshoku/hanny'
  spec.license       = 'BSD-2-Clause'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.1'

  spec.add_runtime_dependency 'numo-narray', '>= 0.9.0'

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'coveralls', '~> 0.8'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
