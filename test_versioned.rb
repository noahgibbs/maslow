require "test/unit"

require "versioned"

class TestVersionedRoot < Test::Unit::TestCase
  def test_create_versions
    root_version = Versioned::Version.new nil
    assert root_version
    child_version = Versioned::Version.new root_version
    assert child_version
  end

  def test_create_root
    root = Versioned::Root.new
    assert root.version
  end
end

class TestVersionedHash < Test::Unit::TestCase
  def setup
    @root = Versioned::Root.new
  end

  def test_create_hash
    hash = Versioned::Hash.new @root
    assert hash
    hash["bob"] = "sam"
    assert_equal hash["bob"], "sam"
  end

  def test_push_version
    hash = Versioned::Hash.new @root
    hash["bob"] = "sam"
    assert_equal hash["bob"], "sam"
    hash["bob"] = "murray"
    assert_equal hash["bob"], "murray"

    @root.new_version
    assert_equal hash["bob"], "murray"

    hash["bob"] = "domo"
    assert_equal hash["bob"], "domo"

    @root.rollback
    assert_equal hash["bob"], "murray"
  end

  def test_rollback_unref
    oldver = @root.version
    @root.new_version
    newver = @root.version
    assert oldver != newver
    assert oldver.children.include? newver
    @root.rollback
    assert_equal oldver, @root.version
    assert !oldver.children.include?(newver)
  end
end

class TestAssignHash < Test::Unit::TestCase
  def setup
    @root = Versioned::Root.new
    @hash = Versioned::Hash.new @root
  end

  def test_assign_one_hash
    @hash["bob"] = { "1" => "one", "2" => "two" }
    assert @hash["bob"].is_a? Versioned::Hash
  end

  def test_assign_nested_hash
    @hash["bob"] = { "jim" => { "bob" => { "1" => "one", "2" => "two" } } }
    assert @hash["bob"]["jim"]["bob"].is_a?(Versioned::Hash),
      "Nested data structure not converted correctly"
    @hash["bob"] = { "jim" => [ 1, { "1" => "one", "2" => "two" } ] }
    assert @hash["bob"]["jim"][1].is_a?(Versioned::Hash),
      "Nested data structure not converted correctly"
  end

end
