require_relative 'helper'

describe 'cli' do
  it 'prints a help message' do
    stdout = cli '--help'
    expect(stdout.first).to start_with 'xephyr.context is to stream context of a Xephyr instance to LavinMQ.'
  end
end