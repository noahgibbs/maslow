#!/usr/bin/env ruby
# Seas of Night

require "maslow"

env = MaslowEnvironment.new(:seas)
hold = env.location(:ships_hold)

env.need(:food, MaslowNeed::FoodImportant, :anticipate => true, :regular => true)
env.need(:water, MaslowNeed::WaterImportant, :anticipate => true, :regular => true)
env.need(:lifeforce, MaslowNeed::WaterImportant, :anticipate => true, :regular => true)
env.need(:vigor, MaslowNeed::SecurityImportant)
env.need(:security, MaslowNeed::SecurityImportant, :anticipate => true)
env.need(:acclaim, MaslowNeed::EsteemImportant, :anticipate => true)
env.need(:entertainment, MaslowNeed::ActualizationImportant,
		:anticipate => true, :regular => true)

env.persontype(:person, :is_a => [])
env.persontype(:pirate)
env.persontype(:prisoner, :needs => [:food, :water, [:entertainment, 0.5]],
                          :is_a => :person)
env.persontype(:crew, :needs => [:lifeforce, :acclaim, :entertainment], :is_a => :pirate)
env.persontype(:captain, :needs => [:lifeforce,	[:acclaim, 2.0], :entertainment],
                          :is_a => :pirate)

env.resourcetype(:jerky, :supply => true, :fulfills => [[:food, 0.5]])
env.resourcetype(:fruit, :supply => true, :fulfills => [[:food, 0.2], [:water, 0.1]])
env.resourcetype(:canteen, :supply => true, :fulfills => [[:water, 0.8]])
env.resourcetype(:games, :fulfills => [[:entertainment, 0.5]])
hold.add_resource(:jerky, 20)
hold.add_resource(:fruit, 3)
hold.add_resource(:canteen, 50)
hold.add_resource(:games, 5)

env.action(:none, :resources => [], :participants => [ :any_person ],
           :consequences => {})
env.action(:consume, :resources => [ :any_supply ], :participants => [ :any_person ],
		:consequences => { :p0 => [ "apply", :obj1 ] })
env.action(:torture, :resources => [], :participants => [:pirate, :prisoner],
                :consequences => { :p0 => [ "entertainment", 0.5],
                                   :p1 => [ "vigor", -0.1] })
#env.action(:play, :resources => [ [:any_supply, :fulfills => [:entertainment]]],
#           :participants => [:any_person, :any_person],
#           :consequences => { :p0 => [ "apply", :obj1 ], :p1 => [ "apply", :obj1 ]})

population = []
(1..2).each {|i| population << hold.person("prisoner#{i}", :prisoner) }
(1..1).each {|i| population << hold.person("crew#{i}", :crew) }
population << hold.person("captain", :captain)

print "Population loaded...\n"

(1..2).each do |i|
  print "*** Iteration #{i} ***\n"
  population.each do |person|
    print "Person #{person.name}:\n"
    person.tick
  end
end
