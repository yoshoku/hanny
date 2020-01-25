# Hanny

[![Build Status](https://travis-ci.org/yoshoku/Hanny.svg?branch=master)](https://travis-ci.org/yoshoku/Hanny)
[![Coverage Status](https://coveralls.io/repos/github/yoshoku/Hanny/badge.svg?branch=master)](https://coveralls.io/github/yoshoku/Hanny?branch=master)
[![Gem Version](https://badge.fury.io/rb/hanny.svg)](https://badge.fury.io/rb/hanny)
[![BSD 2-Clause License](https://img.shields.io/badge/License-BSD%202--Clause-orange.svg)](https://github.com/yoshoku/Hanny/blob/master/LICENSE.txt)

Hanny is a Hash-based Approximate Nearest Neighbor (ANN) search library in Ruby.
Hash-based ANN converts vector data into binary codes and builds a hash table by using the binary codes as hash keys.
To build the hash table, Hanny uses Locality Sensitive Hashing (LSH) of approximating cosine similarity.
It is known that if the code length is sufficiently long (ex. greater than 128-bit), LSH can obtain high search performance.
In the experiment, Hanny achieved about twenty times faster search speed than the brute-force search by Euclidean distance.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hanny'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hanny

## Usage

```ruby
require 'hanny'

# Prepare vector data for search targets and queries with Numo::DFloat (shape: [n_samples, n_features]).
targets = Numo::DFloat.new(5000, 512).rand
queries = Numo::DFloat.new(10, 512).rand

# Build a search index with 256-bit binary code.
index = Hanny::LSHIndex.new(code_length: 256)
index.build_index(targets)

# Obtain the Array<Integer> that has the data indices of 10-nearest neighbors for each query.
candidates = index.search_knn(queries, n_neighbors: 10)

# Obtain the Array<Integer> that has the data indices whithin Hamming radius of 4 for each query.
candidates = index.search_radius(queries, radius: 4)

# Calculate pairwise euclidean distances between the query and its neighbors.
query_id = 0
distances = Hanny::Utils.euclidean_distance(queries[query_id, true], targets[candidates[query_id], true])

# Add new data to the search index.
appended_data_ids = index.append_data(new_data)

# Remove the data from the search index.
removed_data_ids = index.remove_data([0, 1, 2])

# Save and load the search index with Marshal.
File.open('index.dat', 'wb') { |f| f.write(Marshal.dump(index)) }
index = Marshal.load(File.binread('index.dat'))
```

## Experiment

I confirmed the search speed of Hanny's LSH with [MNIST](https://www.csie.ntu.edu.tw/~cjlin/libsvmtools/datasets/multiclass.html#mnist) data set.
The experiment is carried out on MacBook Early 2016 (Core m3 1.1 GHz CPU and 8 GB memory).

Code:
```ruby
require 'benchmark'
require 'rumale'
require 'hanny'

# Load MNIST data set.
samples, labels = Rumale::Dataset.load_libsvm_file('mnist')
queries = samples[0..5, true]
targets = samples[6..-1, true]
qlabels = labels[0..5]
tlabels = labels[6..-1]

# Build LSH search index.
index = Hanny::LSHIndex.new(code_length: 128, random_seed: 1)
index.build_index(targets)

# Run a benchmark test for finding 5-nearest neighbors.
n_queries = queries.shape[0]
n_neighbors = 5
Benchmark.bm 50 do |r|
  r.report 'LSH' do
    candidates = index.search_knn(queries, n_neighbors: n_neighbors)
    n_queries.times do |m|
      STDERR.write("\nquery label: %d, neighbors label: " % qlabels[m])
      candidates[m].each { |n| STDERR.write("%d, " % tlabels[n]) }
    end
    STDERR.write("\n")
  end
  r.report 'Brute-force' do
    distance_mat = Hanny::Utils.euclidean_distance(queries, targets)
    candidates = Array.new(n_queries) do |n|
      distance_mat[n, true].to_a.map.with_index.sort_by(&:first).map(&:last)[0...n_neighbors]
    end
    n_queries.times do |m|
      STDERR.write("\nquery label: %d, neighbors label: " % qlabels[m])
      candidates[m].each { |n| STDERR.write("%d, " % tlabels[n]) }
    end
    STDERR.write("\n")
  end
end
```

Result:
```bash
    user     system      total        real
LSH
query label: 5, neighbors label: 5, 5, 5, 5, 5,
query label: 0, neighbors label: 0, 0, 0, 0, 0,
query label: 4, neighbors label: 4, 4, 4, 4, 4,
query label: 1, neighbors label: 1, 1, 1, 1, 1,
query label: 9, neighbors label: 9, 9, 9, 9, 9,
query label: 2, neighbors label: 2, 2, 2, 2, 2,
  0.290000   0.010000   0.300000 (  0.307445)
Brute-force
query label: 5, neighbors label: 5, 5, 5, 3, 5,
query label: 0, neighbors label: 0, 0, 0, 0, 0,
query label: 4, neighbors label: 4, 4, 4, 4, 4,
query label: 1, neighbors label: 1, 1, 1, 1, 1,
query label: 9, neighbors label: 9, 9, 9, 9, 9,
query label: 2, neighbors label: 2, 2, 2, 2, 2,
  6.350000   0.280000   6.630000 (  6.682365)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yoshoku/Hanny. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [BSD 2-clause License](https://opensource.org/licenses/BSD-2-Clause).

## Code of Conduct

Everyone interacting in the Hanny project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/yoshoku/Hanny/blob/master/CODE_OF_CONDUCT.md).
