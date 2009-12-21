require 'test/unit'
require 'maslow'

class TC_location < Test::Unit::TestCase
  def setup
    @env = MaslowEnvironment.new :test_env
    @pt = @env.persontype :testperson
    @rt = @env.resourcetype :meat, :supply => true, :fulfills => []
    @loc = @env.location :test_location
  end

  def test_copy
    @loc.person "Bob", :testperson
    @loc.add_resource(:meat, 20)
    loc2 = @loc.dup
    assert(loc2.get_resource(:meat) == 20, "Resource copy failed!")
    assert(loc2.person_by_name("Bob"), "Person copy failed!")
    loc2.add_resource(:meat, 5)
    assert(loc2.get_resource(:meat) == 25, "Resource add failed after copy!")
    assert(@loc.get_resource(:meat) == 20, "Resource copy didn't work!")
    loc2.person "Sam", :testperson
    assert(loc2.person_by_name("Sam"), "Person-add after copy failed!")
    assert((!@loc.person_by_name("Sam")), "Person copy didn't work!")
  end
end

class TC_persontype < Test::Unit::TestCase
  def setup
    @env = MaslowEnvironment.new :test_env
    @pt = @env.persontype :test_person
  end

  def test_basic
    @ptest = @env.persontype :test

    assert(@ptest.is_child_of?(:person), "All types not children of :person!")
    assert(@ptest.is_a == [:person], "Automatic parenting not working!");
    assert(@ptest.environment == @env, "Auto environment-assigning not working!")
    assert(@ptest.name == :test, "Name field not working!")
    assert(@ptest.needs == [], "Needs array not assigned to [] for nil!")

    @ptchild = @env.persontype :tchild, :is_a => :test, :needs => [:hunger]
    assert(@ptchild.is_child_of?(:test), "Is_child_of? not working!")
    assert(@ptchild.is_child_of?(:person), "Is_child_of? not finding :person!")
    assert(@ptchild.needs == [[:hunger, 1.0]],
		"Persontype not getting needs array!")
  end

end

class TC_person < Test::Unit::TestCase
  def setup
    @env = MaslowEnvironment.new :test_env
    @loc = @env.location :test_location
    @env.need :hunger, MaslowNeed::FoodImportant, :anticipate => true,
		:regular => true
    @env.need :air, MaslowNeed::AirImportant, :anticipate => true,
		:regular => true
    @env.need :presents, MaslowNeed::ActualizationImportant,
		:anticipate => true, :regular => false
    @env.need :security, MaslowNeed::SecurityImportant,
		:anticipate => true
    @env.persontype :test_person, :needs => [:hunger]
    @env.persontype :test_person2, :needs => [[:air, 1.5], :presents,
						[:hunger, 2.0], :security]
    @person = @loc.person :first_person, :test_person
    @person2 = @loc.person :second_person, :test_person2
  end

  def test_current_happiness
    assert (@person.current_happiness == 0), "Basic happiness isn't 0!"

    @person.advance_time(1.0)
    assert(@person.current_happiness < 0,
		"Happiness doesn't decrease with time and needs")
    assert_in_delta(@person.current_happiness, -MaslowNeed::FoodImportant, 0.0001,
		"Happiness doesn't decrease by unit amount")

    @person2.advance_time 2.0
    assert_in_delta(@person2.needs_due[:presents], 0.0, 0.0001,
		"Non-regular needs shouldn't advance!")
    assert_in_delta(@person2.needs_due[:security], 0.0, 0.0001,
		"Needs should default to non-regular!")
    assert_in_delta(@person2.needs_due[:air], 3.0, 0.0001,
		"Needs should advance by specified amount!")
    assert_in_delta(@person2.current_happiness,
		-3.0 * MaslowNeed::AirImportant - 4.0 * MaslowNeed::FoodImportant,
		0.001, "Needs should add up correctly!")
  end
end

class TC_person_action < Test::Unit::TestCase
  def setup
    @env = MaslowEnvironment.new :test_env
    @loc = @env.location :test_location
    @hunger = @env.need :hunger, MaslowNeed::FoodImportant, :anticipate => true,
		:regular => true
    @env.need :air, MaslowNeed::AirImportant, :anticipate => true,
		:regular => true
    @env.need :presents, MaslowNeed::ActualizationImportant,
		:anticipate => true, :regular => false
    @env.need :security, MaslowNeed::SecurityImportant,
		:anticipate => true
    @env.need :entertainment, MaslowNeed::EsteemImportant,
		:anticipate => true, :regular => true
    @env.persontype :test_person, :needs => [:hunger]
    @env.persontype :test_person2, :needs => [[:air, 1.5], :presents,
						[:hunger, 2.0], :security,
						:entertainment]
    @env.resourcetype :o2_tank, :supply => true, :portable => true,
		:fulfills => [[:air, 10.0]]
    @env.resourcetype :soul_food, :supply => true, :portable => true,
		:fulfills => [[:hunger, 3.0], [:security, 2.0],
				[:presents, 0.5]]
    @consume = @env.action :consume, :resources => [ :any_supply ],
			:participants => [:person],
			:consequences => { :p0 => [ :apply, :obj1 ] }
    @wolf = @env.action :wolf, :resources => [ :any_supply ],
			:participants => [:person],
			:consequences => { :p0 => [[ :apply, :obj1 ],
						[ :entertainment, 1.0 ]] }

    @person = @loc.person :first_person, :test_person
  end

  #def teardown
  #end

  def test_consequences
    @person2 = @loc.person :second_person, :test_person2
    @person2.add_resource :o2_tank, 2.0
    @consume.apply @person2, [], [:o2_tank]
    assert_in_delta(@person2.needs_due[:air], -10.0, 0.001)
  end

  def test_consequences_array
    @person2 = @loc.person :second_person, :test_person2
    @person2.add_resource :o2_tank, 2.0
    @wolf.apply @person2, [], [:o2_tank]
    assert_in_delta(@person2.needs_due[:air], -10.0, 0.001)
    assert_in_delta(@person2.needs_due[:entertainment], -1.0, 0.001)
  end

  def test_fulfills_array
    @person2 = @loc.person :second_person, :test_person2
    @loc.add_resource :soul_food, 1.0
    @consume.apply @person2, [], [:soul_food]
    assert_in_delta(@person2.needs_due[:hunger], -3.0, 0.001)
    assert_in_delta(@person2.needs_due[:security], -2.0, 0.001)
    assert_in_delta(@person2.needs_due[:presents], -0.5, 0.001)
  end

end

class TC_resourcetype < Test::Unit::TestCase
  def setup
    @env = MaslowEnvironment.new :test_env
  end

  def test_matching
    @rt = @env.resourcetype :test_supply, :supply => true, :fulfills => []
    @rtp = @env.resourcetype :test_portable, :portable => true,
			:fulfills => []

    assert @rt.supply?, "Is supply test failed!"
    assert (not @rt.portable?), "Is portable test failed!"
    assert @rt.match(:any), "Match on :any failed!"
    assert @rtp.match(:any), "Match on :any failed!"
    assert @rt.match(:any_supply), "Match on :any_supply failed!"
    assert @rtp.match(:any_portable), "Match on :any_portable failed!"
    assert (not @rtp.match(:any_supply)), "Match on :any_supply should fail!"
    assert (not @rt.match(:any_portable)), "Match on :any_portable should fail!"
    assert @rt.match(:test_supply), "Match on own type failed!"
    assert (not @rt.match(:test_portable)), "Match on other type should fail!"
  end

  def test_fulfill
    @env.need :hunger, MaslowNeed::FoodImportant
    @env.need :entertainment, MaslowNeed::FoodImportant
    @rt = @env.resourcetype :test_supply, :supply => true,
		:fulfills => [:entertainment, [:hunger, 10]]
    @loc = @env.location :test_loc
    @pt = @env.persontype :test_person, :needs => [:hunger]
    @person = @loc.person "Joe", :test_person

    assert(@person.get_need(:hunger) == 0, "Needs not initialized!")
    @person.fulfill_need :hunger, -20
    assert(@person.get_need(:hunger) == 20, "Need not added correctly!")
    @rt.apply_to @person
    assert(@person.get_need(:hunger) == 10, "Resource doesn't fulfill correctly!")
    ent = @person.get_need(:entertainment)
    assert(ent.nil? || ent == 0,
		"Resource doesn't fulfill correctly!")
  end

end
