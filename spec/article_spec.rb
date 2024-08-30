# frozen_string_literal: true

RSpec.describe Article do
  it "has a version number" do
    expect(Article::VERSION).not_to be nil
  end
end
