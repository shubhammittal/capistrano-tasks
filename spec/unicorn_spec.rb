require "test_helper"

describe CapistranoTasks::Unicorn do
  before do
    setup_configuration
  end

  def setup_configuration(params = {})
    @configuration = Capistrano::Configuration.new
    @configuration.set :current_path, "/home/arnold/builds/capistrano-tasks/tmp"
    CapistranoTasks::Unicorn.load_into(@configuration, "test_c", params)
  end

  # random test for the sake of seeing how tests work
  it "should have a bootup timeout" do
    @configuration.fetch(:bootup_timeout).must_equal 30
  end

  it "should define a few tasks" do
    @configuration.find_task("test_c:start").wont_be_nil
    @configuration.find_task("test_c:dfdfdfd").must_be_nil
  end

  it "should be able to read param variables" do
    setup_configuration(:bootup_timeout => 60)
    @configuration.fetch(:bootup_timeout).must_equal 60
  end
end
