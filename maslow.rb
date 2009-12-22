module Maslow
  module Importance
    # Basic Maslow's Hierarchy taken from the Wikipedia entry for
    # "Maslow's Hierarchy of Needs".

    # Physiological needs
    Physiological = 100.0
    Air = 100.0
    Homeostasis = 90.0    # Lack of injury, basically
    Water = 80.0
    Food = 70.0
    Sleep = 65.0
    Sex = 60.0

    # Safety needs
    Security = 50.0
    Safety = 50.0
    Family = 40.0
    Property = 40.0

    # Love/belonging
    # Family, friendship, sexual intimacy
    Belonging = 35.0

    # Self-esteem
    # Self-esteem, confidence, achievement, respect of others,
    # respect by others
    Esteem = 20.0

    # Self-Actualization
    # Morality, creativity, spontaneity, problem solving, lack of prejudice,
    # acceptance of facts
    Actualization = 10.0
  end

  protected

  def verify_options(allowed_options, options)
    final_options = {}
    allowed_options.each do |key, value|
      if options.include?(key)
        raise "Option #{key} is of class #{options[key].class.to_s}, not " +
          "class #{value.to_s}!" unless options[key].is_a?(value)
        final_options[key] = options[key]
      end
    end
    final_options
  end

  public

  def environment(root, options = nil)
    if root.is_a?(Hash)
      raise "No root object passed to environment()!" unless options[:root]

      options = root
      root = options[:root]
    end

    legal_options = {
      :name => Symbol,
      :needs => Hash,
      :critter_types => Hash,
      :actions => Hash,
      :locations => Hash,
      :resource_types => Hash,
    }
    Versioned::Hash.new root, verify_options(legal_options, options)
  end

  def need(options)
    legal_options = {
      :importance => Fixnum,
      :anticipate => Boolean,
      :regular => Boolean,
    }
    verify_options(legal_options, options)
  end

  def critter_type(options)
    legal_options = {
      :needs => Hash,
      :is_a => Array,
    }
    verify_options(legal_options, options)
  end

  def critter(options)
    legal_options = {
      :location => Symbol,
      :critter_type => Symbol,
      :resources => Hash,
      :needs_due => Hash,
    }
    verify_options(legal_options, options)
  end

  def action(options)
    legal_options = {
      :resources => Hash,
      :participants => Hash,
      :consequences => Hash,
    }
    verify_options(legal_options, options)
  end

  def location(options)
    legal_options = {
      :resources => Hash,
      :locations => Hash, # sub-locations
    }
    verify_options(legal_options, options)
  end

  def resource_type(options)
    legal_options = {
      :fulfills => Hash,
      :locations => Boolean,
    }
    verify_options(legal_options, options)
  end

end



=begin
  def fulfill_need(need_name, amt)
    need = need_name if need_name.is_a? MaslowNeed
    need = @location.environment.need_by_name(need_name) if
		need_name.respond_to? :to_str
    need = @location.environment.need_by_name(need_name) if
		need_name.respond_to? :to_sym
    raise "Unrecognized need #{need_name} for person #{@name}!" unless
		need.is_a? MaslowNeed

    namesym = need.name.to_sym
    return unless @needs_due[namesym]
    @needs_due[namesym] -= amt
  end

  def get_need(need)
    need = @location.environment.need_by_name(need) if need.respond_to? :to_str
    need = @location.environment.need_by_name(need) if need.respond_to? :to_sym

    namesym = need.name.to_sym
    return @needs_due[namesym] if @needs_due[namesym]
    0
  end

  def all_applicable_actions
    actions = @location.environment.actions.inject [] do |result, action|
      result + action.applications_to(self)
    end
    subactions = MaslowAction.list_sub_actions(actions)
    [actions, subactions]
  end

  def advance_time(duration = 0.1)
    needs_amounts = @persontype.needs
    needs_amounts.each do |need, multiplier|
      need_obj = @location.environment.need_by_name(need)
      if need_obj.regular
        @needs_due[need] += duration * multiplier
      end
    end
  end

  def tick(duration = 0.1)
    advance_time(duration)
    print "Tick: person #{@name} has happiness #{current_happiness}\n"

    actions, subactions = all_applicable_actions

    print "  * Person #{@name} is considering #{actions.length} possible " +
          "actions and #{subactions.length} subactions.\n"
    #print MaslowAction.list_pp actions
    print "-----\n"
    subactions.each do |subaction|
      print "  " + MaslowAction.list_pp(subaction) + "\n"
    end
    print "-----\n"
    subactions = subactions.map do |action, people, resources|
      newenv = @location.environment.dup

      #execute action
      newloc = newenv.location_by_name(@location.name)
      newguy = self.map_to_env(newenv)
      newact = newenv.action_by_name(action.name)
      newpeople = people.map {|person| person.map_to_env(newenv)}
      newact.apply(newguy, newpeople, resources)

      happiness = -500000.0

      # Find ourselves in the "what-if" environment, and evaluate our new
      # happiness there
      if newguy
        happiness = newguy.current_happiness
      end

      [action, people, resources, happiness]
    end
    subactions.each do |subaction|
      print "  " + MaslowAction.list_pp(subaction) + "\n"
    end
    print "*****\n"
  end


  def current_happiness()
    env = @location.environment

    happiness = 0.0

    discontent = @needs_due.clone
    @resources.each_pair do |rscname, amount|
      rsc = @location.resourcetype_by_name(rscname)
      rsc.fulfills.each do |which_need, amount|
        print "Resource #{rscname} would fulfill #{amount} of #{which_need}\n"
        discontent[which_need] -= amount
      end
    end

    discontent.each_pair do |needname, amount|
      need = env.need_by_name(needname)
      happiness -= amount * need.importance
    end

    happiness
  end


  def apply_consequences(consequences, objects)
    raise "Invalid consequence array: nil!" if consequences.nil?
    return if consequences.is_a? Array and consequences.empty?

    if consequences.is_a? Array and consequences[0].is_a? Array
      consequences.each do |repercussion|
        apply_consequences(repercussion, objects)
      end
      return
    end

    if consequences[0].to_sym == :apply
      raise "Invalid 'apply' consequence!" unless consequences.length == 2
      raise "Invalid 'apply' consequence!" unless
		consequences[1].respond_to? :to_s

      objname = consequences[1].to_s
      raise "Bad objname #{objname} in consequence!" unless objname =~ /^obj([0-9]+)$/
      raise "Too few objects supplied!" unless objects.length >= $1.to_i

      objindex = ($1.to_i) - 1
      objtype = objects[objindex]
      objtype = @location.environment.resourcetype_by_name(objtype) unless
		objtype.is_a? MaslowResourcetype

      # TODO: allow taking some of the resource from inventory and some
      # from environment, and/or allowing fractional consumption
      if !@resources[objtype.name].nil? && @resources[objtype.name] >= 1.0
        @resources[objtype.name] -= 1.0
        objtype.apply_to self
        return
      end

      if !@location.resources[objtype].nil? && @location.resources[objtype] >= 1.0
        @location.add_resource(objtype, -1.0)
        objtype.apply_to self
        return
      end

      # Eventually, this can become a no-op, just don't do the action
      raise "Couldn't find enough of object '#{objtype.name}' to apply!"
    end

    need = @location.environment.need_by_name(consequences[0])
    unless need.nil?
      raise "Invalid need consequence!" unless consequences.length == 2
      raise "Invalid need consequence!" unless consequences[1].is_a? Numeric
      self.fulfill_need(need, consequences[1])
      return
    end

    raise "Illegal consequence rule (#{MaslowAction.list_pp consequences})!"
  end

end # class MaslowPerson



  def match(spec)
    if(spec.is_a? Symbol)
      return true if spec == :any
      return true if spec == :any_supply and supply?
      return true if spec == :any_portable and portable?

      return name == spec
    end

    raise "Unknown resourcetype spec!"
  end


  def apply_to(person)
    @fulfills.each do |need, amt|
      person.fulfill_need(need, amt)
    end
  end


  def validate_fulfills_array(f_arr)
    return [[f_arr, 1.0]] if(f_arr.is_a? Symbol)

    raise "'Fulfills' must be a symbol or an array!" unless f_arr.is_a? Array

    f_arr.map do |elt|
      if elt.is_a? Symbol
        [elt, 1.0]
      elsif elt.is_a? Array and elt.size == 2
        elt
      else
        raise "Every elt of 'fulfills' should be a symbol or length-2 array!"
      end
    end
  end

end # class MaslowResourcetype


class MaslowAction
  attr_reader :environment, :name, :resourcetypes, :participants, :consequences


  # This takes a list of lists of possibilities for a verb, and spells it all
  # out into specific possibilities for that verb.  The initial list is as
  # follows:
  #
  # [ action [[vic1a vic1b vic1c] [vic2a vic2b] [vic3a vic3b...]]
  #          [[obj1a obj1b obj1c] [obj2a obj2b] [obj3a obj3b...]]
  #
  # VicNM is possibility M for victim N of the verb.  So a verb that takes
  # two people other than the actor would have a Vic1 list and a Vic2 list,
  # but no more than that.  Similarly, an action which requires, say, a type
  # of food, an instrument with which to eat it and a serving platter or
  # plate or whatnot might take three direct objects, and thus have an obj1,
  # obj2 and obj3 list for specific items which might fulfill each of these
  # three roles.  This means very large, complex verbs could quickly cause
  # enormous return values from this function, since the total number of
  # sub-actions expands combinatorially in the number of possibilities for
  # each role.  So don't do that.
  #
  def self.list_sub_actions(list)
    final_ret = []
    list.each do |action_list|
      action = action_list[0]
      person_role_list = action_list[1]
      resource_role_list = action_list[2]
      inner_ret = []

      #print "Person role list: #{MaslowAction.list_pp person_role_list}\n"

      if person_role_list.empty?
        act_plus_vict = [ [action, [] ] ]
      else
        vict_combos = powerset(*person_role_list)
        #print "Person combos: #{MaslowAction.list_pp vict_combos}\n"
        act_plus_vict = vict_combos.map {|victs| [action, victs]}
      end
      #print "Act plus vict: #{MaslowAction.list_pp vict_combos}\n"

      #print "Resource role list: #{MaslowAction.list_pp resource_role_list}\n"

      if resource_role_list.empty?
        sub_actions = act_plus_vict.map {|apv| apv + [[]]}
      else
        rsc_combos = powerset(*resource_role_list)
        sub_actions = []
        rsc_combos.each do |rscs|
          sub_actions += act_plus_vict.map {|apv| apv + [rscs]}
        end
      end

      #print "Sub-actions: #{MaslowAction.list_pp sub_actions}\n"

      final_ret += sub_actions
    end
    final_ret
  end # def self.list_sub_actions

  # This function executes this action with the given actor.
  # 'People' must be an array of people (possibly empty) that matches
  # the person spec for this action.  'Resources' must be the same for
  # resources.
  #
  def apply(actor, people, resources)
    return if consequences.empty?  # no consequences?  Kick out.
    actor.apply_consequences @consequences[:p0], resources
    victim_num = 1
    people.each do |person|
      person.apply_consequences @consequences["p#{victim_num}".to_sym], resources
    end
  end

  # This returns a list of 'bindings' for the action.  That is, if the
  # action is eating an item, the bindings might be 'eat bread' and 'eat ham',
  # while the action 'give item to person' might bind to 'give box to prisoner',
  # 'give letter to guard', 'give knife to Bob' and a number of other things.
  # Impossible bindings shouldn't be returned, but undesirable ones should be.
  # They'll be evaluated for quality elsewhere.
  #
  def applications_to(person)
    pb = bind_participants(@participants, person, person.location.persons)
    return [] if pb.nil?
    raise "Invalid return value!" unless pb.is_a? Array

    rb = bind_resources(@resourcetypes, person.location.resources)
    return [] if rb.nil?
    raise "Invalid return value!" unless rb.is_a? Array
    [ [self, pb, rb] ]
  end

  private


  def match_participant(spec, person)
    if(spec.is_a? Symbol)
      return true if spec == :person
      return true if spec == :any_person
      return person.is_person_type?(spec)
    end

    false
  end

  def bind_participants(participants, person, people_list)
    return nil unless match_participant(@participants[0], person)
    return [] if @participants.length == 1

    @participants[1..-1].map do |victim_spec|
      possible = people_list.select {|person| match_participant(victim_spec, person)}
      return nil if possible.empty?
      possible
    end
  end

  # Bind_resources assumes that the actions and actor are already known, and does
  # not bother to return them.  Returning nil means no applicable action, while
  # returning the empty list means that there is one action, which takes no
  # resources.
  def bind_resources(spec, resources)
    raise "Invalid specification!" unless spec.is_a? Array
    return [] if spec.empty?

    match_list = spec.map do |rspec|
      rscs = resources.keys.select { |rsc| resources[rsc] > 0 && rsc.match(rspec) }
      return nil if rscs.empty?
      rscs
    end

    return match_list if(match_list.length == 1)
    match_list[1..-1].inject(match_list[0]) do |result, elt|
      res = []
      result.each do |entry|
        elt.each do |sub_elt|
          res << entry + [sub_elt]
        end
      end
    end
  end

end # class MaslowAction

=end
