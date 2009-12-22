#!/usr/bin/env ruby
# Seas of Night, approximated with versioned hash objects

require "versioned"
require "maslow"

include Maslow

root = Versioned::Root.new

env = environment root, :name => :seas_of_night,
  :critters => {},
  :needs => {
    :food => need(:importance => Importance::Food,
                  :anticipate => true, :regular => true),
    :water => need(:importance => Importance::Water,
                   :anticipate => true, :regular => true),
    :lifeforce => need(:importance => Importance::Water,
                       :anticipate => true, :regular => true),
    :vigor => need(:importance => Importance::Security),
    :security => need(:importance => Importance::Security,
                      :anticipate => true),
    :acclaim => need(:importance => Importance::Esteem,
                     :anticipate => true),
    :entertainment => need(:importance => Importance::Actualization,
                           :anticipate => true, :regular => true),
  },
  :critter_types => {
    :person => critter_type,
    :pirate => critter_type,
    :prisoner => critter_type(:is_a => [ :person ],
      :needs => { :food => true, :water => true, :entertainment => 0.5}),
    :crew => critter_type(:is_a => [ :pirate ],
      :needs => { :lifeforce => true, :acclaim => true,
                  :entertainment => true }),
    :captain => critter_type(:is_a => [ :pirate ],
      :needs => { :lifeforce => true, :acclaim => 2.0, :entertainment => true }),
  },
  :actions => {
    :none => action(:resources => {},
                    :participants => { :actor => :any_person },
                    :consequences => {}),
    :eat_jerky => action(:resources => { :jerky => true },
                         :participants => { :actor => :any_person },
                         :consequences => { :actor => [ "apply", :obj1 ] }),
    :eat_fruit => action(:resources => { :fruit => true },
                         :participants => { :actor => :any_person },
                         :consequences => { :actor => [ "apply", :obj1 ] }),
    :drink_canteen => action(:resources => { :canteen => true },
                             :participants => { :actor => :any_person },
                           :consequences => { :actor => [ "apply", :obj1 ] }),
    :torture => action(:resources => {},
                       :participants => { :actor => :pirate, :victim => :prisoner },
                       :consequences => { :actor => [ "entertainment", 0.5 ],
                                          :victim => [ "vigor", -0.1 ] }),
  },
  :locations => {
    :ships_hold => location(:resources => { :jerky => 20, :fruit => 3,
                                            :canteen => 50, :games => 5 }),
  },
  :resource_types => {
    :jerky => resource_type(:fulfills => { :food => 0.5 }),
    :fruit => resource_type(:fulfills => { :food => 0.2, :water => 0.1}),
    :canteen => resource_type(:fulfills => { :water => 0.8 }),
    :games => resource_type(:fulfills => { :entertainment => 0.5 }),
  }

hold = env[:locations][:ships_hold]

(1..2).each { |i|
  env[:critters]["prisoner#{i}".to_sym] = critter(:location => :ships_hold,
    :critter_type => :prisoner, :resources => {}, :needs_due => {})
}
(1..1).each { |i|
  env[:critters]["prisoner#{i}".to_sym] = critter(:location => :ships_hold,
    :critter_type => :crew, :resources => {}, :needs_due => {})
}
print "Population loaded...\n"
