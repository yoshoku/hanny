# frozen_string_literal: true

module Hanny
  # LSHIndex is a class that builds a search index with Locality Sensitive Hashing (LSH) [1].
  # It is known that if the code length is sufficiently long (ex. greater than 128-bit),
  # LSH can obtain higher search performance than many popular hashing methods [2].
  # In search process, LSHIndex obtains search results by sorting the data stored in hash table with Hamming distances
  # between query binary code and binary hash keys.
  #
  # @example
  #   # Prepare vector data for search targets and queries with Numo::DFloat (shape: [n_samples, n_features]).
  #   targets = Numo::DFloat.new(5000, 512).rand
  #   queries = Numo::DFloat.new(10, 512).rand
  #
  #   # Build a search index with 256-bit binary code via LSH.
  #   # Although LSHIndex works without setting random_seed, it recommends setting random_seed for reproducibility.
  #   index = Hanny::LSHIndex.new(code_length: 256, random_seed: 1)
  #   index.build_index(targets)
  #
  #   # Obtain the Array<Integer> that has the data indices of 10-neighbors for each query.
  #   candidates = index.search_knn(queries, n_neighbors: 10)
  #
  #   # Save and load the search index with Marshal.
  #   File.open('index.dat', 'wb') { |f| f.write(Marshal.dump(index)) }
  #   index = Marshal.load(File.binread('index.dat'))
  #
  # *References:*
  # 1. Moses S. Charikar, "Similarity Estimation Techniques from Rounding Algorithms," Proc. of the 34-th Annual ACM Symposium on Theory of Computing, pp. 380--388, (2002).
  # 1. Deng Cai, "A Revisit of Hashing Algorithms for Approximate Nearest Neighbor Search," CoRR abs/1612.07545 (2016).
  class LSHIndex
    # Return the code length of hash key.
    # @return [Integer]
    attr_reader :code_length

    # Return the number of samples of indexed data.
    # @return [Integer]
    attr_reader :n_samples

    # Return the number of features of indexed data.
    # @return [Integer]
    attr_reader :n_features

    # Return the number of hash keys.
    # @return [Integer]
    attr_reader :n_keys

    # Return the hash table.
    # @return [Hash]
    attr_reader :hash_table

    # Return the binary hash codes.
    # @return [Numo::Bit]
    attr_reader :hash_codes

    # Return the seed to initialize random number generator.
    # @return [Integer]
    attr_reader :random_seed

    # Return the random generator to generate random matrix.
    # @return [Random]
    attr_reader :rng

    # Create a new nearest neighbor index.
    # @param code_length [Integer] The length of binary code for hash key.
    # @param random_seed [Integer/NilClass] The seed value using to initialize the random generator.
    def initialize(code_length: 256, random_seed: nil)
      @code_length = code_length
      @n_samples = nil
      @n_features = nil
      @n_keys = nil
      @last_id = nil
      @weight_mat = nil
      @hash_table = nil
      @hash_codes = nil
      @random_seed = random_seed
      @random_seed ||= srand
      @rng = Random.new(@random_seed)
    end

    # Convert data into binary codes.
    # @param x [Numo::DFloat] (shape: [n_samples, n_features]) The data to be converted to binary codes.
    # @return [Numo::Bit] The binary codes converted from given data.
    def hash_function(x)
      x.dot(@weight_mat).ge(0.0)
    end

    # Build a search index.
    # @param x [Numo::DFloat] (shape: [n_samples, n_features]) The dataset for building search index.
    # @return [LSHIndex] The search index itself that has constructed the hash table.
    def build_index(x)
      # Initialize some variables.
      @n_samples, @n_features = x.shape
      @hash_table = {}
      @hash_codes = []
      @weight_mat = Utils.rand_normal([@n_features, @code_length], @rng)
      # Convert samples to binary codes.
      bin_x = hash_function(x)
      # Store samples to binary hash table.
      @n_samples.times do |m|
        bin_code = bin_x[m, true]
        hash_key = symbolized_hash_key(bin_code)
        unless @hash_table.key?(hash_key)
          @hash_codes.push(bin_code.to_a)
          @hash_table[hash_key] = []
        end
        @hash_table[hash_key].push(m)
      end
      @hash_codes = Numo::Bit.cast(@hash_codes)
      # Update some variables.
      @n_keys = @hash_codes.shape[0]
      @last_id = @n_samples
      self
    end

    # Append new data to the search index.
    # @param x [Numo::DFloat] (shape: [n_samples, n_features]) The dataset to append to search index.
    # @return [Array<Integer>] The indices of appended data in search index
    def append_data(x)
      # Initialize some variables.
      n_new_samples, = x.shape
      bin_x = hash_function(x)
      added_data_ids = []
      # Store samples to binary hash table.
      new_codes = []
      n_new_samples.times do |m|
        bin_code = bin_x[m, true]
        hash_key = symbolized_hash_key(bin_code)
        unless @hash_table.key?(hash_key)
          new_codes.push(bin_code.to_a)
          @hash_table[hash_key] = []
        end
        new_data_id = @last_id + m
        @hash_table[hash_key].push(new_data_id)
        added_data_ids.push(new_data_id)
      end
      # Update hash codes.
      unless new_codes.empty?
        new_codes = Numo::Bit.cast(new_codes)
        @hash_codes = @hash_codes.concatenate(new_codes)
        @n_keys = @hash_codes.shape[0]
      end
      @last_id += n_new_samples
      @n_samples += n_new_samples
      added_data_ids
    end

    # Remove data from the search index.
    # The indices of removed data will never be assigned unless the search index is rebuilt.
    # @param data_ids [Array<Integer>] The data indices to be removed.
    # @return [Array<Integer>] The indices of removed data in search index
    def remove_data(data_ids)
      removed_data_ids = []
      data_ids.each do |query_id|
        # Remove data id from hash table.
        hash_key = @hash_table.keys.select { |k| @hash_table[k].include?(query_id) }.first
        next if hash_key.nil?
        @hash_table[hash_key].delete(query_id)
        removed_data_ids.push(query_id)
        # Remove the hash key if there is no data.
        next unless @hash_table[hash_key].empty?
        target_id = distances_to_hash_codes(decoded_hash_key(hash_key)).index(0)
        @hash_codes = @hash_codes.delete(target_id, 0)
      end
      @n_samples -= removed_data_ids.size
      removed_data_ids
    end

    # Perform k-nearest neighbor search.
    # @param q [Numo::DFloat] (shape: [n_queries, n_features]) The data for search queries.
    # @param n_neighbors [Integer] The number of neighbors.
    # @return [Array<Integer>] The data indices of search result.
    def search_knn(q, n_neighbors: 10)
      # Initialize some variables.
      n_queries, = q.shape
      candidates = Array.new(n_queries) { [] }
      # Binarize queries.
      bin_q = hash_function(q)
      # Find k-nearest neighbors for each query.
      n_queries.times do |m|
        sort_with_index(distances_to_hash_codes(bin_q[m, true])).each do |_, n|
          candidates[m] = candidates[m] | @hash_table[symbolized_hash_key(@hash_codes[n, true])]
          break if candidates[m].size >= n_neighbors
        end
        candidates[m] = candidates[m].shift(n_neighbors)
      end
      candidates
    end

    # Perform hamming radius nearest neighbor search.
    # @param q [Numo::DFloat] (shape: [n_queries, n_features]) The data for search queries.
    # @param radius [Float] The hamming radius for search range.
    # @return [Array<Integer>] The data indices of search result.
    def search_radius(q, radius: 1.0)
      # Initialize some variables.
      n_queries, = q.shape
      candidates = Array.new(n_queries) { [] }
      # Binarize queries.
      bin_q = hash_function(q)
      # Find k-nearest neighbors for each query.
      n_queries.times do |m|
        sort_with_index(distances_to_hash_codes(bin_q[m, true])).each do |d, n|
          break if d > radius
          candidates[m] = candidates[m] | @hash_table[symbolized_hash_key(@hash_codes[n, true])]
        end
      end
      candidates
    end

    # Dump marshal data.
    # @return [Hash] The marshal data for search index.
    def marshal_dump
      { code_length: @code_length,
        n_samples: @n_samples,
        n_features: @n_features,
        n_keys: @n_keys,
        last_id: @last_id,
        weight_mat: @weight_mat,
        bias_vec: @bias_vec,
        hash_table: @hash_table,
        hash_codes: @hash_codes,
        random_seed: @random_seed,
        rng: @rng }
    end

    # Load marshal data.
    # @return [nil]
    def marshal_load(obj)
      @code_length = obj[:code_length]
      @n_samples = obj[:n_samples]
      @n_features = obj[:n_features]
      @n_keys = obj[:n_keys]
      @last_id = obj[:last_id]
      @weight_mat = obj[:weight_mat]
      @bias_vec = obj[:bias_vec]
      @hash_table = obj[:hash_table]
      @hash_codes = obj[:hash_codes]
      @random_seed = obj[:random_seed]
      @rng = obj[:rng]
      nil
    end

    private

    # Convert binary code to symbol as hash key.
    # @param bin_code [Numo::Bit]
    # @return [Symbol]
    def symbolized_hash_key(bin_code)
      Zlib::Deflate.deflate(bin_code.to_a.join, Zlib::BEST_SPEED).to_sym
    end

    # Calculate hamming distances between binary code and binary hash keys.
    # @param bin_code [Numo::Bit]
    # @return [Array<Float>]
    def distances_to_hash_codes(bin_code)
      (bin_code ^ @hash_codes).count(1).to_a
    end

    # Sort array elements with indices.
    # @param arr [Array<Float>]
    # @return [Array<Float, Integer>]
    def sort_with_index(arr)
      arr.map.with_index.sort_by(&:first)
    end

    # Convert hash key symbol to binary code.
    # @param hash_key [Symbol]
    # @return [Numo::Bit]
    def decoded_hash_key(hash_key)
      bin_code = Zlib::Inflate.inflate(hash_key.to_s).split('').map(&:to_i)
      Numo::Bit[*bin_code]
    end
  end
end
