# frozen_string_literal: true

RSpec.describe Hanny do
  let(:n_targets) { 90 }
  let(:n_queries) { 10 }
  let(:n_features) { 512 }
  let(:code_length) { 256 }
  let(:n_neighbors) { 5 }
  let(:rng) { Random.new(1) }
  let(:targets) do
    a = Hanny::Utils.rand_normal([n_targets / 2, n_features], rng, -10)
    b = Hanny::Utils.rand_normal([n_targets / 2, n_features], rng,  10)
    a.concatenate(b)
  end
  let(:queries) do
    a = Hanny::Utils.rand_normal([n_queries / 2, n_features], rng, -10)
    b = Hanny::Utils.rand_normal([n_queries / 2, n_features], rng,  10)
    a.concatenate(b)
  end
  let(:t_labels) do
    a = Numo::Int32.zeros(n_targets / 2) + 1
    b = Numo::Int32.zeros(n_targets / 2) + 2
    a.concatenate(b)
  end
  let(:q_labels) do
    a = Numo::Int32.zeros(n_queries / 2) + 1
    b = Numo::Int32.zeros(n_queries / 2) + 2
    a.concatenate(b)
  end
  let(:index) { Hanny::LSHIndex.new(code_length: code_length, random_seed: 1) }

  it 'searches k-nearest neighbors for each query.' do
    index.build_index(targets)

    expect(index.code_length).to eq(code_length)
    expect(index.n_samples).to eq(n_targets)
    expect(index.n_features).to eq(n_features)

    appended_ids = index.append_data(queries)
    expect(index.n_samples).to eq(n_targets + n_queries)
    candidates = index.search_knn(queries, n_neighbors: n_neighbors)
    expect(candidates.class).to eq(Array)
    expect(candidates.size).to eq(n_queries)
    expect(candidates.map(&:size)).to eq([n_neighbors] * n_queries)
    expect(candidates.map(&:first)).to eq(appended_ids)

    index.remove_data(appended_ids)
    expect(index.n_samples).to eq(n_targets)
    candidates = index.search_knn(queries, n_neighbors: n_neighbors)
    expect(candidates.class).to eq(Array)
    expect(candidates.map(&:first)).not_to eq(appended_ids)
    expect(t_labels[candidates.map(&:first)]).to eq(q_labels)
  end

  it 'searches nearest neighbors within specified hamming radius for each query.' do
    index.build_index(targets)

    candidates = index.search_radius(queries, radius: 0)
    expect(candidates.class).to eq(Array)
    expect(candidates.size).to eq(n_queries)
    expect(candidates.map(&:size)).to eq([0] * n_queries)

    appended_ids = index.append_data(queries)
    candidates = index.search_radius(queries, radius: 1)
    expect(candidates.class).to eq(Array)
    expect(candidates.size).to eq(n_queries)
    expect(candidates.map(&:size)).to eq([1] * n_queries)
    expect(candidates.map(&:first)).to eq(appended_ids)

    index.remove_data(appended_ids)
    candidates = index.search_radius(queries, radius: 8)
    expect(candidates.class).to eq(Array)
    expect(candidates.map(&:first)).not_to eq(appended_ids)
    expect(t_labels[candidates.map(&:first)]).to eq(q_labels)
  end

  it 'calculates the euclidean distance matrix.' do
    bf_dist_mat = Numo::DFloat.zeros(n_queries, n_targets)
    n_queries.times do |m|
      n_targets.times do |n|
        bf_dist_mat[m, n] = Math.sqrt(((queries[m, true] - targets[n, true])**2).sum)
      end
    end
    dist_mat = Hanny::Utils.euclidean_distance(queries, targets)
    expect(dist_mat.class).to eq(Numo::DFloat)
    expect(dist_mat.shape[0]).to eq(n_queries)
    expect(dist_mat.shape[1]).to eq(n_targets)
    expect(dist_mat).to be_within(1.0e-8).of(bf_dist_mat)
  end

  it 'dumps and restores search index using Marshal.' do
    index.build_index(targets)
    cp = Marshal.load(Marshal.dump(index))
    expect(index.class).to eq(cp.class)
    expect(index.code_length).to eq(cp.code_length)
    expect(index.n_samples).to eq(cp.n_samples)
    expect(index.n_features).to eq(cp.n_features)
    expect(index.n_keys).to eq(cp.n_keys)
    expect(index.hash_table).to eq(cp.hash_table)
    expect(index.random_seed).to eq(cp.random_seed)
    expect(index.rng).to eq(cp.rng)
    expect(index.search_knn(queries, n_neighbors: 5)).to eq(cp.search_knn(queries, n_neighbors: 5))
  end
end
