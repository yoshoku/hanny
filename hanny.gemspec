# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hanny/version'

Gem::Specification.new do |spec|
  spec.name          = 'hanny'
  spec.version       = Hanny::VERSION
  spec.authors       = ['yoshoku']
  spec.email         = ['yoshoku@outlook.com']

  spec.summary       = 'Hanny is a Hash-based Approximate Nearest Neighbor search library in Ruby.'
  spec.description   = <<~MSG
    Hanny is a Hash-based Approximate Nearest Neighbor (ANN) search library in Ruby.
    Hash-based ANN converts vector data into binary codes and builds a hash table by using the binary codes as hash keys.
    To build the hash table, Hanny uses Locality Sensitive Hashing (LSH) of approximating cosine similarity.
    It is known that if the code length is sufficiently long (ex. greater than 128-bit), LSH can obtain high search performance.
    In the experiment, Hanny achieved about twenty times faster search speed than the brute-force search by Euclidean distance.
  MSG
  spec.homepage      = 'https://github.com/yoshoku/hanny'
  spec.license       = 'BSD-2-Clause'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = 'https://github.com/yoshoku/hanny/blob/main/CHANGELOG.md'
  spec.metadata['documentation_uri'] = 'https://yoshoku.github.io/hanny/doc/'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features|sig-deps)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'numo-narray', '>= 0.9.1'
end
