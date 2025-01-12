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
	var/serial_number // Used to tell which controller is connected to which unique drone
	var/obj/item/device/drone_controller/linked_controller // Controller object linked to the drone. Null if not connected.
	var/obj/structure/machinery/camera/drone/linked_cam

/proc/generate_id()
	return "[pick(GLOB.alphabet_uppercase)][pick(GLOB.alphabet_uppercase)][pick(GLOB.alphabet_uppercase)]-[rand(1, 9)][pick(GLOB.alphabet_uppercase)]"

/proc/get_examine_damage(health, maxhealth)
	var/health_percent = health / maxhealth * 100
	if(health_percent > 70)
		. += SPAN_INFO("It looks to be in good shape.")
	else if(health_percent > 50)
		. += SPAN_INFO("It looks slightly damaged.")
	else if(health_percent > 30)
		. += SPAN_DANGER("It looks pretty damaged.")
	else if(health_percent >= 0)
		. += SPAN_DANGER("It looks like it's barely functioning, and in need of urgent repairs.")

/obj/structure/drone/Initialize(mapload, health = src.health, maxhealth = src.maxhealth, linked_controller = src.linked_controller, serial_number = src.serial_number)
	. = ..()
	src.health = health
	src.maxhealth = maxhealth
	src.linked_controller = linked_controller
	if(!isnull(linked_controller))
		var/obj/item/device/drone_controller/controller = src.linked_controller
		controller.linked_drone = src
	if(isnull(serial_number))
		src.serial_number = generate_id()
	else
		src.serial_number = serial_number
	linked_cam = new(loc, src)
	linked_cam.status = TRUE
	linked_cam.c_tag = serial_number
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(handle_move))

/obj/structure/drone/Destroy()
	qdel(src.linked_cam)
	. = ..()


/obj/structure/drone/get_examine_text(mob/user)
	. = ..()
	. += SPAN_INFO(get_examine_damage(health, maxhealth))
	. += SPAN_INFO("It's serial number is [serial_number].")

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
	if(istype(object, /obj/item/device/drone_controller))
		var/obj/item/device/drone_controller/controller = object
		if(!isnull(src.linked_controller))
			src.linked_controller.unlink_drone()
		src.linked_controller = controller
		controller.linked_drone = src
		user.balloon_alert(user, "linked!")
		return
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
			return (ATTACKBY_HINT_NO_AFTERATTACK|ATTACKBY_HINT_UPDATE_NEXT_MOVE)
		return
	if(object.force > 0 || user.a_intent == INTENT_HARM)
		if(object.force >= MELEE_FORCE_TIER_1)
			playsound(src.loc, 'sound/effects/metalhit.ogg', 25)
		update_health(object.force)
	. = ..()

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
	update_health(severity)
	. = ..()

/obj/structure/drone/proc/handle_move()
	if(!linked_cam || QDELETED(linked_cam))
		linked_cam = new(loc, src)
	else
		linked_cam.status = TRUE
		linked_cam.forceMove(loc)

/obj/structure/drone/proc/grab_drone(mob/living/user)
	if(!ishuman(user))
		return
	if(!skillcheck(user, SKILL_ENGINEER, SKILL_ENGINEER_NOVICE)) // Don't want John Rifleman picking up the drone.
		to_chat(user, SPAN_WARNING("You try picking up \the [src] but it scuttles away from your grasp."))
		//src.Move(newloc) - move away from user
		return
	to_chat(user, SPAN_NOTICE("You being picking up \the [src]."))
	if(do_after(user, 2 SECONDS, INTERRUPT_ALL, BUSY_ICON_FRIENDLY, src))
		to_chat(user, SPAN_NOTICE("You pickup \the [src]!"))
		playsound(src.loc, 'sound/machines/pda_button1.ogg')
		var/obj/item/drone/grabbed_drone = new /obj/item/drone(src.loc, src.health, src.maxhealth, src.linked_controller, src.serial_number)
		grabbed_drone.do_pickup_animation(usr.loc)
		usr.put_in_hands(grabbed_drone)
		qdel(src)

/obj/structure/drone/MouseDrop(over_object, src_location, over_location)
	..()
	if(over_object == usr && Adjacent(usr)) // This may be redundant
		grab_drone(over_object)

/obj/item/drone
	name = "\improper M-2137 Beetle Drone"
	desc = "A small, mobile drone intended for intelligence and recon work. It's turned off."
	icon = 'icons/mob/robots.dmi'
	icon_state = "spiderbot-chassis"
	w_class = SIZE_MEDIUM
	flags_atom = CONDUCT|NOBLUDGEON
	item_icons = list(
		WEAR_L_HAND = 'icons/mob/humans/onmob/inhands/items_by_map/jungle_lefthand.dmi',
		WEAR_R_HAND = 'icons/mob/humans/onmob/inhands/items_by_map/jungle_righthand.dmi'
	)
	health = 60
	var/maxhealth = 60
	var/obj/item/device/drone_controller/linked_controller
	var/serial_number

/obj/item/drone/Initialize(mapload, health = src.health, maxhealth = src.maxhealth, linked_controller = src.linked_controller, serial_number = src.serial_number)
	. = ..()
	src.health = health
	src.maxhealth = maxhealth
	src.linked_controller = linked_controller
	if(!isnull(linked_controller))
		var/obj/item/device/drone_controller/controller = src.linked_controller
		controller.linked_drone = src
	if(isnull(serial_number))
		src.serial_number = generate_id()
	else
		src.serial_number = serial_number

/obj/item/drone/get_examine_text(mob/user)
	. = ..()
	. += SPAN_INFO(get_examine_damage(health, maxhealth))
	. += SPAN_INFO("It's serial number is [serial_number].")

/obj/item/drone/attackby(obj/item/object as obj, mob/living/user as mob)
	if(istype(object, /obj/item/device/drone_controller))
		var/obj/item/device/drone_controller/controller = object
		if(!isnull(src.linked_controller))
			src.linked_controller.unlink_drone()
		src.linked_controller = controller
		controller.linked_drone = src
		user.balloon_alert(user, "linked!")
		return
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
			return (ATTACKBY_HINT_NO_AFTERATTACK|ATTACKBY_HINT_UPDATE_NEXT_MOVE)
		return
	. = ..()

// Copied from mortar
/obj/item/drone/attack_self(mob/user)
	..()
	var/turf/deploy_turf = get_turf(user)
	if(!deploy_turf)
		return
	if(!skillcheck(user, SKILL_ENGINEER, SKILL_ENGINEER_NOVICE))
		to_chat(user, SPAN_WARNING("You don't have the training to deploy \the [src]."))
		return
	to_chat(user, SPAN_NOTICE("You start deploying \the [src]."))
	if(do_after(user, 1 SECONDS, INTERRUPT_ALL, BUSY_ICON_FRIENDLY, src))
		playsound(src.loc, 'sound/machines/pda_button1.ogg')
		var/area/area = get_area(deploy_turf)
		var/obj/structure/drone/drone = new /obj/structure/drone(deploy_turf, src.health, src.maxhealth, src.linked_controller, src.serial_number)
		user.visible_message(SPAN_NOTICE("[user] deploys \the [src]."), SPAN_NOTICE("You deploy \the [src]."))
		drone.name = src.name
		qdel(src)

/obj/item/device/drone_controller
	name = "\improper M-2137 Beetle Drone Controller"
	desc = "A handheld controller for controlling the M-2137 Beetle Drone."
	icon = 'icons/obj/items/devices.dmi'
	icon_state = "Cotablet"
	w_class = SIZE_SMALL
	flags_atom = CONDUCT|NOBLUDGEON
	var/linked_drone // Drone object linked to the controller. Null if not connected.
	var/list/network = list(CAMERA_NET_DRONE)

/obj/item/device/drone_controller/proc/unlink_drone()
	src.linked_drone = null

/obj/item/device/drone_controller/attack_self(mob/user)
	..()
	if(isnull(linked_drone))
		balloon_alert(user, "no linked drone!")
		return
	tgui_interact(user)


/obj/item/device/drone_controller/tgui_interact(mob/user, datum/tgui/ui)
  ui = SStgui.try_update_ui(user, src, ui)
  if(!ui)
    ui = new(user, src, "DroneController")
    ui.open()

/obj/item/device/drone_controller/ui_static_data(mob/user)
	var/list/data = list()
	data["serial_number"] = serial_number
	return data

/obj/item/device/drone_controller/ui_data(mob/user)
	var/list/data = list()
	data["network"] = network
	data["activeCamera"] = null
	// if(current)
	// 	data["activeCamera"] = list(
	// 		name = current.c_tag,
	// 		status = current.status,
	// 	)
	if(istype(src.linked_drone, /obj/item/drone))
		var/obj/item/drone/drone = src.linked_drone
		data["health"] = drone.health
		data["maxhealth"] = drone.maxhealth
		data["serial_number"] = drone.serial_number
		data["linked_controller"] = drone.linked_controller.serial_number
		return data
	if(istype(src.linked_drone, /obj/structure/drone))
		var/obj/structure/drone/drone = src.linked_drone
		data["health"] = drone.health
		data["maxhealth"] = drone.maxhealth
		data["serial_number"] = drone.serial_number
		data["linked_controller"] = drone.linked_controller.serial_number
		return data

