# frozen_string_literal: true

module Hanny
  # This module consists of utility methods.
  module Utils
    class << self
      # Calculate pairwise euclidean distances between x and y.
      # @param x [Numo::DFloat] (shape: [n_samples_x, n_features])
      # @param y [Numo::DFloat] (shape: [n_samples_y, n_features])
      # @return [Numo::DFloat] (shape: [n_samples_x, n_samples_x] or [n_samples_x, n_samples_y] if y is given)
      def euclidean_distance(x, y = nil)
        y = x if y.nil?
        x = Numo::DFloat[x] if x.shape[1].nil?
        y = Numo::DFloat[y] if y.shape[1].nil?
        sum_x_vec = (x**2).sum(1)
        sum_y_vec = (y**2).sum(1)
        dot_xy_mat = x.dot(y.transpose)
        distance_matrix = dot_xy_mat * -2.0 +
                          sum_x_vec.tile(y.shape[0], 1).transpose +
                          sum_y_vec.tile(x.shape[0], 1)
        Numo::NMath.sqrt(distance_matrix.abs)
      end

      # Generate a uniform random matrix with random number generator.
      # @param shape [Array<Integer>] The size of random matrix.
      # @param rng [Random] The random number generator
      # @return [Numo::DFloat] The generated uniform random matrix.
      def rand_uniform(shape, rng)
        rnd_vals = Array.new(shape.inject(:*)) { rng.rand }
        Numo::DFloat.asarray(rnd_vals).reshape(shape[0], shape[1])
      end

      # Generate a normal random matrix with random number generator.
      # @param shape [Array<Integer>] The size of random matrix.
      # @param rng [Random] The random number generator
      # @return [Numo::DFloat] The generated normal random matrix.
      def rand_normal(shape, rng, mu = 0.0, sigma = 1.0)
        a = rand_uniform(shape, rng)
        b = rand_uniform(shape, rng)
        (Numo::NMath.sqrt(Numo::NMath.log(a) * -2.0) * Numo::NMath.sin(b * 2.0 * Math::PI)) * sigma + mu
      end
    end
  end
end
