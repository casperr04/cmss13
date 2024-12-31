// IO Drone
// Very cool
/obj/structure/drone
	name = "\improper M-2137 Beetle Drone"
	desc = "A small, mobile drone intended for intelligence and recon work."
	icon = 'icons/mob/robots.dmi'
	icon_state = "spiderbot-chassis"
	anchored = FALSE
	wrenchable = FALSE
	density = FALSE
	layer = XENO_HIDING_LAYER
	flags_atom = RELAY_CLICK
	can_block_movement = FALSE
	projectile_coverage = PROJECTILE_COVERAGE_NONE
	health = 60
	var/maxhealth = 60
	var/obj/structure/machinery/computer/cameras/drone/internal_camera

/obj/structure/drone/attack_alien(mob/living/carbon/xenomorph/xeno)
	xeno.animation_attack_on(src)
	xeno.flick_attack_overlay(src, "slash")
	playsound(src.loc, 'sound/effects/metalhit.ogg', 25)
	update_health(rand(xeno.melee_damage_lower, xeno.melee_damage_upper))
	if(health <= 0)
		xeno.visible_message(SPAN_DANGER("[xeno] smashes \the [src] to pieces!"), SPAN_XENODANGER("We smash \the [src] to pieces!"))
	else
		xeno.visible_message(SPAN_DANGER("[xeno] slashes \the [src]!"), SPAN_XENODANGER("We slash \the [src]!"))
	return XENO_ATTACK_ACTION


/obj/structure/drone/update_health(damage)
	health -= damage
	health = clamp(health, 0, maxhealth)
	if(health <= 0)
		playsound(src.loc, 'sound/effects/screech.ogg', 25)
		playsound(src.loc, 'sound/effects/sparks4.ogg')
		new /obj/effect/decal/cleanable/blood/gibs/robot(src.loc)
		new /obj/effect/spawner/gibspawner/robot(src.loc)
		src.visible_message(SPAN_WARNING("\The [src] falls apart!"))
		qdel(src)
	if(health <= maxhealth / 2)
		if(prob(20))
			playsound(src.loc, 'sound/effects/sparks4.ogg')
			new /obj/effect/particle_effect/sparks(src.loc)

/obj/structure/drone/attackby(obj/item/object as obj, mob/living/user as mob)
	if(HAS_TRAIT(object, TRAIT_TOOL_BLOWTORCH))
		var/obj/item/tool/weldingtool/welder = object
		if(!welder.isOn())
			to_chat(user, SPAN_WARNING("\The [welder] needs to be on!"))
			return
		if(health >= maxhealth)
			to_chat(user, SPAN_NOTICE("\The [src] does need any more repairs."))
			return
		to_chat(user, SPAN_NOTICE("You begin repairing the damage to \the [src]."))
		playsound(src.loc, 'sound/items/Welder2.ogg', 25, TRUE)
		if(do_after(user, 6 SECONDS * user.get_skill_duration_multiplier(SKILL_ENGINEER), INTERRUPT_ALL, BUSY_ICON_FRIENDLY, src))
			update_health(-20)
			playsound(src.loc, 'sound/items/Welder2.ogg', 25, TRUE)
			to_chat(user, SPAN_NOTICE("You repair some damage to \the [src]"))
			welder.remove_fuel(0, user)
			return
		return
	if(object.force > 0 || user.a_intent == INTENT_HARM)
		user.visible_message(SPAN_DANGER("[user] hits \the [src] with \the [object]!"))
		user.animation_attack_on(src)
		user.flick_attack_overlay(src, "punch")
		if(object.force >= MELEE_FORCE_TIER_1)
			playsound(src.loc, 'sound/effects/metalhit.ogg', 25)
		update_health(object.force)
		return

/obj/structure/drone/bullet_act(obj/projectile/proj)
	bullet_ping(proj)
	var/ammo_flags = proj.ammo.flags_ammo_behavior | proj.projectile_override_flags
	if(ammo_flags & AMMO_ACIDIC)
		update_health(floor(proj.damage/2)) // Acid Spit
	else
		update_health(floor(proj.damage/3)) // We don't want to accidentally destroy the drone too easily in crossfire
	return TRUE

/obj/structure/drone/attack_hand(mob/living/user as mob)
	if(user.a_intent == INTENT_HARM)
		if(isyautja(user) || issynth(user)) // Predators and synthetics are strong so they can just destroy the drone with a stomp.
			user.visible_message(SPAN_DANGER("[user] hovers their foot over \the [src]!"), SPAN_DANGER("You hover your foot over \the [src]..."))
			if(do_after(user, 2 SECONDS, INTERRUPT_ALL, BUSY_ICON_HOSTILE, src))
				user.visible_message(SPAN_DANGER("[user] stomps on \the [src], breaking it!"), SPAN_DANGER("You stomp on \the [src], breaking it!")) // change to doafter?
				user.animation_attack_on(src)
				user.flick_attack_overlay(src, "punch")
				playsound(src.loc, 'sound/effects/metalhit.ogg', 25)
				update_health(maxhealth)
				return
			return
		to_chat(user, SPAN_WARNING("You try stomping on \the [src] but it doesn't seem like you can damage it this way."))
		return
	else
		grab_drone(user)

/obj/structure/drone/ex_act(severity, direction)
	new /obj/effect/spawner/gibspawner/robot(src.loc)
	. = ..()

/obj/structure/drone/proc/grab_drone(mob/living/user)
	if(!ishuman(user))
		return
	if(!skillcheck(user, SKILL_ENGINEER, SKILL_ENGINEER_NOVICE)) // Don't want John Rifleman picking up the drone.
		to_chat(user, SPAN_WARNING("You try picking up \the [src] but it scuttles away from your grasp."))
		//src.Move(newloc) - move away from user
		return
	var/obj/item/drone/grabbed_drone = new /obj/item/drone(src.loc)
	grabbed_drone.do_pickup_animation(usr.loc)
	usr.put_in_hands(grabbed_drone)
	qdel(src)

/obj/structure/drone/MouseDrop(over_object, src_location, over_location)
	..()
	if(over_object == usr && Adjacent(usr))
		grab_drone(over_object)

/obj/item/drone
	name = "\improper M-2137 Beetle Drone"
	desc = "A small, mobile drone intended for intelligence and recon work. It's turned off."
	icon = 'icons/mob/robots.dmi'
	icon_state = "spiderbot-chassis"
	w_class = SIZE_MEDIUM
	flags_atom = FPRINT|CONDUCT
	item_icons = list(
		WEAR_L_HAND = 'icons/mob/humans/onmob/inhands/items_by_map/jungle_lefthand.dmi',
		WEAR_R_HAND = 'icons/mob/humans/onmob/inhands/items_by_map/jungle_righthand.dmi'
	)

// Copied from mortar
/obj/item/drone/attack_self(mob/user)
	..()
	var/turf/deploy_turf = get_turf(user)
	if(!deploy_turf)
		return
	if(!skillcheck(user, SKILL_ENGINEER, SKILL_ENGINEER_NOVICE))
		to_chat(user, SPAN_WARNING("You don't have the training to deploy \the [src]."))
		return
	var/area/area = get_area(deploy_turf)
	var/obj/structure/drone/drone = new /obj/structure/drone(deploy_turf)
	user.visible_message(SPAN_NOTICE("[user] deploys \the [src]."), SPAN_NOTICE("You deploy \the [src]."))
	drone.name = src.name
	qdel(src)
